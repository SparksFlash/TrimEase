import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import '../../payment/checkout.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({Key? key}) : super(key: key);

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final _fire = FirebaseFirestore.instance;
  final _uid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
  final Map<String, bool> _loading = {};

  Future<void> _confirmAndPayFromMirror(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final shopId = (data['shopId'] ?? '').toString();
    final barberId = (data['barberId'] ?? '').toString();
    final serviceTitle = (data['serviceTitle'] ?? 'Service').toString();
    final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();
    final amount = (data['price'] is num)
        ? (data['price'] as num).toDouble()
        : double.tryParse((data['price'] ?? '').toString()) ?? 0.0;

    if (shopId.isEmpty || barberId.isEmpty || scheduledAt == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking data incomplete')),
        );
      return;
    }

    final desc =
        '$serviceTitle on ${scheduledAt.toLocal().toString().split(' ')[0]} at ${scheduledAt.toLocal().toString().split(' ')[1].substring(0, 5)}';

    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentCheckout(
          serviceName: serviceTitle,
          date: scheduledAt,
          time: scheduledAt.toLocal().toString().split(' ')[1].substring(0, 5),
          amount: amount > 0 ? amount : 500.0,
          description: desc,
        ),
      ),
    );

    if (paid != true) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment cancelled or failed')),
        );
      return;
    }

    // Show loading for this booking
    setState(() => _loading[doc.id] = true);

    final centralRef = _fire
        .collection('shop')
        .doc(shopId)
        .collection('bookings')
        .doc(doc.id);
    final barberRef = _fire
        .collection('shop')
        .doc(shopId)
        .collection('barber')
        .doc(barberId)
        .collection('bookings')
        .doc(doc.id);

    final lower = Timestamp.fromDate(
      scheduledAt.subtract(const Duration(minutes: 59)),
    );
    final upper = Timestamp.fromDate(
      scheduledAt.add(const Duration(minutes: 60)),
    );

    try {
      await _fire.runTransaction((tx) async {
        final snap = await tx.get(centralRef);
        if (!snap.exists) throw Exception('Central booking not found');

        // conflict check with index fallback
        bool conflictFound = false;
        try {
          final conflicts = await _fire
              .collection('shop')
              .doc(shopId)
              .collection('bookings')
              .where('barberId', isEqualTo: barberId)
              .where('status', isEqualTo: 'confirmed')
              .where('scheduledAt', isGreaterThanOrEqualTo: lower)
              .where('scheduledAt', isLessThan: upper)
              .get();
          if (conflicts.docs.isNotEmpty) conflictFound = true;
        } catch (e) {
          debugPrint('Range query failed in confirm (fallback): $e');
          final alt = await _fire
              .collection('shop')
              .doc(shopId)
              .collection('bookings')
              .where('barberId', isEqualTo: barberId)
              .where('status', isEqualTo: 'confirmed')
              .get();
          for (final d in alt.docs) {
            final ts = d.data()['scheduledAt'];
            if (ts is Timestamp) {
              final dt = ts.toDate();
              if (!dt.isBefore(lower.toDate()) && dt.isBefore(upper.toDate())) {
                conflictFound = true;
                break;
              }
            }
          }
        }

        if (conflictFound) {
          tx.delete(centralRef);
          throw Exception('Conflict while confirming booking');
        }

        tx.update(centralRef, {
          'status': 'confirmed',
          'booking_confirmed': true,
          'confirmedAt': FieldValue.serverTimestamp(),
        });

        tx.set(barberRef, {
          ...(snap.data() as Map<String, dynamic>),
          'status': 'confirmed',
          'booking_confirmed': true,
        });

        final userRef = _fire
            .collection('users')
            .doc(_uid)
            .collection('bookings')
            .doc(doc.id);
        tx.set(userRef, {
          ...(snap.data() as Map<String, dynamic>),
          'status': 'confirmed',
          'booking_confirmed': true,
        });

        final payRef = _fire
            .collection('shop')
            .doc(shopId)
            .collection('payments')
            .doc();
        tx.set(payRef, {
          'bookingId': doc.id,
          'userId': _uid,
          'barberId': barberId,
          'amount': amount > 0 ? amount : 500.0,
          'serviceTitle': serviceTitle,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed and payment recorded'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm booking: $e')),
        );
    } finally {
      if (mounted) setState(() => _loading.remove(doc.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My booking')),
        body: const Center(child: Text('Not signed in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My booking')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fire
            .collection('users')
            .doc(_uid)
            .collection('bookings')
            .orderBy('scheduledAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No bookings yet'));

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 4,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final d = docs[index];
                final data = d.data() as Map<String, dynamic>? ?? {};
                final service = (data['serviceTitle'] ?? 'Service').toString();
                final scheduled = (data['scheduledAt'] as Timestamp?)?.toDate();
                final status = (data['status'] ?? '').toString();
                final barber = (data['barberName'] ?? '').toString();
                final price = (data['price'] is num)
                    ? (data['price'] as num).toDouble()
                    : double.tryParse((data['price'] ?? '').toString()) ?? 0.0;

                final isPending =
                    status == 'provisional' ||
                    (data['booking_confirmed'] == false);

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(barber.isNotEmpty ? barber : 'Barber'),
                        const SizedBox(height: 8),
                        Text(
                          scheduled != null
                              ? scheduled.toLocal().toString()
                              : 'No date',
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('৳${price.toStringAsFixed(2)}'),
                            isPending
                                ? (_loading[d.id] == true
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : ElevatedButton(
                                          onPressed: () =>
                                              _confirmAndPayFromMirror(d),
                                          child: const Text('Confirm & Pay'),
                                        ))
                                : Chip(
                                    label: Text(
                                      status.isNotEmpty ? status : 'unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: status == 'confirmed'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
