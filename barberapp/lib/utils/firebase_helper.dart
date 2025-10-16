import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Small helper utilities to safely check Firebase availability and get current
/// user id without throwing when Firebase is not initialized (web).
class FirebaseHelper {
  static bool get available {
    try {
      return firebase_core.Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String currentUid() {
    try {
      if (!available) return '';
      return fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> userBookingsStream(
    String uid,
  ) {
    if (!available || uid.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookings')
        .orderBy('scheduledAt', descending: true)
        .snapshots();
  }
}
