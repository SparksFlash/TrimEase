import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePricingQueries {
  static Future<(int confirmed, int cancelled, int activeBarbers)>
  bookingStats({
    required String shopId,
    required String serviceTitle,
    required DateTime scheduledAt,
    Duration lookback = const Duration(days: 28),
  }) async {
    final fire = FirebaseFirestore.instance;
    final fromTs = Timestamp.fromDate(DateTime.now().subtract(lookback));
    int confirmed = 0;
    int cancelled = 0;

    try {
      final q =
          await fire
              .collection('shop')
              .doc(shopId)
              .collection('bookings')
              .where('serviceTitle', isEqualTo: serviceTitle)
              .where('scheduledAt', isGreaterThanOrEqualTo: fromTs)
              .get();
      for (final d in q.docs) {
        final m = d.data();
        final status = (m['status'] ?? '').toString();
        if (status == 'confirmed') {
          confirmed++;
        } else if (status == 'cancelled') {
          cancelled++;
        }
      }
    } catch (_) {}

    int activeBarbers = 0;
    try {
      final barbersSnap =
          await fire.collection('shop').doc(shopId).collection('barber').get();
      activeBarbers =
          barbersSnap.docs.length; // simplistic; add availability flag later
    } catch (_) {}

    return (confirmed, cancelled, activeBarbers);
  }
}
