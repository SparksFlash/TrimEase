import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  // This provider can operate in a degraded mode when Firebase is not
  // initialized (for example during web development when `firebase_options.dart`
  // is not present). Pass `firebaseAvailable=false` to avoid using Firebase.

  final bool firebaseAvailable;

  AuthProvider({this.firebaseAvailable = true});

  bool _loading = false;
  bool get loading => _loading;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  /// Sign out if a user is currently signed in.
  Future<void> signOutIfAny() async {
    try {
      if (firebase_core.Firebase.apps.isEmpty) return;
      final auth = fb.FirebaseAuth.instance;
      if (auth.currentUser != null) await auth.signOut();
    } catch (_) {}
  }

  /// Sign up: create FirebaseAuth user, then create Firestore doc at `shop/<uid>`
  Future<String?> signUp({
    required String email,
    required String password,
    required String category,
    String? shopName,
    String? selectedShopId,
  }) async {
    try {
      _setLoading(true);
      if (firebase_core.Firebase.apps.isEmpty) {
        return 'Firebase not initialized';
      }
      final auth = fb.FirebaseAuth.instance;
      final fire = FirebaseFirestore.instance;

      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) return 'Failed to create user';
      // send verification email
      try {
        await cred.user?.sendEmailVerification();
      } catch (_) {}
      if (category == 'owner') {
        final doc = fire.collection('shop').doc(uid);
        await doc.set({
          'email': email,
          'category': category,
          'shopName': shopName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          // mark as not yet email-verified; owner should verify via email
          'emailVerified': false,
        });
      } else if (category == 'customer') {
        // store customer profile under users/<uid>
        final doc = fire.collection('users').doc(uid);
        await doc.set({
          'email': email,
          'category': category,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': false,
        });
      } else if (category == 'barber') {
        // barber must be associated with an existing shop
        if (selectedShopId == null) {
          return 'Please select a shop for barber signup';
        }
        final shopDoc = await fire.collection('shop').doc(selectedShopId).get();
        final shopN =
            shopDoc.exists
                ? (shopDoc.data()?['shopName'] ?? '').toString()
                : '';
        final barberDoc = fire
            .collection('shop')
            .doc(selectedShopId)
            .collection('barber')
            .doc(email);
        await barberDoc.set({
          'uid': uid,
          'email': email,
          'shopId': selectedShopId,
          'shopName': shopN,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': false,
        });
      } else {
        // default fallback: write to users
        final doc = fire.collection('users').doc(uid);
        await doc.set({
          'email': email,
          'category': category,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': false,
        });
      }

      // Sign out the newly created user so they must verify email before login.
      try {
        await auth.signOut();
      } catch (_) {}

      return 'verification_sent';
    } on fb.FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Send a password reset email to the provided email address.
  Future<String?> sendPasswordReset({required String email}) async {
    try {
      if (firebase_core.Firebase.apps.isEmpty)
        return 'Firebase not initialized';
      final auth = fb.FirebaseAuth.instance;
      await auth.sendPasswordResetEmail(email: email);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  /// Login: sign in and verify Firestore `shop/<uid>` category matches provided category
  Future<String?> login({
    required String email,
    required String password,
    required String category,
    String? selectedShopId,
  }) async {
    try {
      _setLoading(true);
      if (firebase_core.Firebase.apps.isEmpty)
        return 'Firebase not initialized';
      final auth = fb.FirebaseAuth.instance;
      final fire = FirebaseFirestore.instance;

      final cred = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) return 'Unable to sign in';
      // Require email verification before allowing login
      final user = auth.currentUser;
      if (user != null && !user.emailVerified) {
        await auth.signOut();
        return 'Please verify your email before logging in. A verification link was sent to your email.';
      }
      if (category == 'owner') {
        final doc = await fire.collection('shop').doc(uid).get();
        if (!doc.exists) {
          await auth.signOut();
          return 'Account data not found (shop document missing)';
        }
        final data = doc.data()!;
        final storedCategory = (data['category'] ?? '').toString();
        if (storedCategory != category) {
          await auth.signOut();
          return 'Category mismatch. Please select the correct category.';
        }
      } else if (category == 'customer') {
        final doc = await fire.collection('users').doc(uid).get();
        if (!doc.exists) {
          await auth.signOut();
          return 'Account data not found (user profile missing)';
        }
        final data = doc.data()!;
        final storedCategory = (data['category'] ?? '').toString();
        if (storedCategory != category) {
          await auth.signOut();
          return 'Category mismatch. Please select the correct category.';
        }
      } else if (category == 'barber') {
        // For barber login, ensure selectedShopId is provided and barber exists under that shop
        if (selectedShopId == null) {
          await auth.signOut();
          return 'Please select the shop to login as barber';
        }
        final barberDoc =
            await fire
                .collection('shop')
                .doc(selectedShopId)
                .collection('barber')
                .doc(email)
                .get();
        if (!barberDoc.exists) {
          await auth.signOut();
          return 'Barber not registered under selected shop';
        }
        // Success if exists (credentials already validated by FirebaseAuth)
      } else {
        // unknown category: disallow
        await auth.signOut();
        return 'Unknown category';
      }

      return null; // success
    } on fb.FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    } finally {
      _setLoading(false);
    }
  }
}
