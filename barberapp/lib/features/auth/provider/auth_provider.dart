import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  bool _loading = false;
  bool get loading => _loading;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  /// Sign out if a user is currently signed in.
  Future<void> signOutIfAny() async {
    try {
      if (_auth.currentUser != null) await _auth.signOut();
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
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) return 'Failed to create user';

      if (category == 'owner') {
        final doc = _fire.collection('shop').doc(uid);
        await doc.set({
          'email': email,
          'category': category,
          'shopName': shopName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (category == 'customer') {
        // store customer profile under users/<uid>
        final doc = _fire.collection('users').doc(uid);
        await doc.set({
          'email': email,
          'category': category,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (category == 'barber') {
        // barber must be associated with an existing shop
        if (selectedShopId == null) {
          return 'Please select a shop for barber signup';
        }
        final shopDoc = await _fire
            .collection('shop')
            .doc(selectedShopId)
            .get();
        final shopName = shopDoc.exists
            ? (shopDoc.data()?['shopName'] ?? '').toString()
            : '';
        final barberDoc = _fire
            .collection('shop')
            .doc(selectedShopId)
            .collection('barber')
            .doc(email);
        await barberDoc.set({
          'uid': uid,
          'email': email,
          'shopId': selectedShopId,
          'shopName': shopName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // default fallback: write to users
        final doc = _fire.collection('users').doc(uid);
        await doc.set({
          'email': email,
          'category': category,
          'createdAt': FieldValue.serverTimestamp(),
        });
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

  /// Login: sign in and verify Firestore `shop/<uid>` category matches provided category
  Future<String?> login({
    required String email,
    required String password,
    required String category,
    String? selectedShopId,
  }) async {
    try {
      _setLoading(true);
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) return 'Unable to sign in';
      if (category == 'owner') {
        final doc = await _fire.collection('shop').doc(uid).get();
        if (!doc.exists) {
          await _auth.signOut();
          return 'Account data not found (shop document missing)';
        }
        final data = doc.data()!;
        final storedCategory = (data['category'] ?? '').toString();
        if (storedCategory != category) {
          await _auth.signOut();
          return 'Category mismatch. Please select the correct category.';
        }
      } else if (category == 'customer') {
        final doc = await _fire.collection('users').doc(uid).get();
        if (!doc.exists) {
          await _auth.signOut();
          return 'Account data not found (user profile missing)';
        }
        final data = doc.data()!;
        final storedCategory = (data['category'] ?? '').toString();
        if (storedCategory != category) {
          await _auth.signOut();
          return 'Category mismatch. Please select the correct category.';
        }
      } else if (category == 'barber') {
        // For barber login, ensure selectedShopId is provided and barber exists under that shop
        if (selectedShopId == null) {
          await _auth.signOut();
          return 'Please select the shop to login as barber';
        }
        final barberDoc = await _fire
            .collection('shop')
            .doc(selectedShopId)
            .collection('barber')
            .doc(email)
            .get();
        if (!barberDoc.exists) {
          await _auth.signOut();
          return 'Barber not registered under selected shop';
        }
        // Success if exists (credentials already validated by FirebaseAuth)
      } else {
        // unknown category: disallow
        await _auth.signOut();
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
