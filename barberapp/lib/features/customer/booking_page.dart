import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import '../../payment/checkout.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({Key? key}) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _fire = FirebaseFirestore.instance;
  final _user = fb_auth.FirebaseAuth.instance.currentUser;

  String? _selectedShopId;
  Map<String, String>? _selectedBarber; // {id, name}
  Map<String, dynamic>? _selectedService; // doc data
  DateTime? _selectedDateTime;

  List<Map<String, String>> _shops = [];
  List<Map<String, String>> _barbers = [];
  List<Map<String, dynamic>> _services = [];
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    final snap = await _fire.collection('shop').get();
    final list = snap.docs
        .map(
          (d) => {
            'id': d.id,
            'name': (d.data()['shopName'] ?? d.id).toString(),
          },
        )
        .toList();
    setState(() => _shops = List<Map<String, String>>.from(list));
  }

  Future<void> _loadBarbers(String shopId) async {
    final snap = await _fire
        .collection('shop')
        .doc(shopId)
        .collection('barber')
        .get();
    final list = snap.docs
        .map((d) => {'id': d.id, 'name': (d.data()['name'] ?? d.id).toString()})
        .toList();
    setState(() => _barbers = List<Map<String, String>>.from(list));
  }

  Future<void> _loadServices(String shopId) async {
    final snap = await _fire
        .collection('shop')
        .doc(shopId)
        .collection('services')
        .get();
    final list = snap.docs.map((d) {
      final m = d.data();
      m['id'] = d.id;
      return m;
    }).toList();
    setState(() => _services = List<Map<String, dynamic>>.from(list));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(
      () => _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _makeBooking() async {
    if (_processing) return;
    setState(() => _processing = true);

    if (_selectedShopId == null ||
        _selectedBarber == null ||
        _selectedService == null ||
        _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select shop, barber, service and time'),
        ),
      );
      if (mounted) setState(() => _processing = false);
      return;
    }

    final uid = _user?.uid ?? '';
    final email = _user?.email ?? '';
    final barberId = _selectedBarber!['id']!;
    final barberName = (_selectedBarber!['name'] ?? 'Barber').toString();
    final serviceId = _selectedService!['id'];
    final serviceTitle = (_selectedService!['title'] ?? 'Service').toString();
    final price = (_selectedService!['price'] is num)
        ? (_selectedService!['price'] as num).toDouble()
        : double.tryParse((_selectedService!['price'] ?? '').toString()) ?? 0.0;

    final chosen = _selectedDateTime!;

    final lower = Timestamp.fromDate(
      chosen.subtract(const Duration(minutes: 59)),
    );
    final upper = Timestamp.fromDate(chosen.add(const Duration(minutes: 60)));

    // create provisional booking ref+data
    final provRef = _fire
        .collection('shop')
        .doc(_selectedShopId)
        .collection('bookings')
        .doc();
    final provData = {
      'customerId': uid,
      'customerEmail': email,
      'shopId': _selectedShopId,
      'barberId': barberId,
      'barberName': barberName,
      'serviceId': serviceId,
      'serviceTitle': serviceTitle,
      'price': price,
      'scheduledAt': Timestamp.fromDate(chosen),
      'status': 'provisional',
      'booking_confirmed': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Start provisional write in background so navigation is immediate
    final writeFuture = provRef.set(provData).catchError((e) {
      debugPrint('Provisional write failed early: $e');
      throw e;
    });

    // hide spinner so checkout appears immediately
    if (mounted) setState(() => _processing = false);

    final desc =
        '$serviceTitle on ${chosen.toLocal().toString().split(' ')[0]} at ${chosen.toLocal().toString().split(' ')[1].substring(0, 5)}';

    bool? paid;
    try {
      paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentCheckout(
            serviceName: serviceTitle,
            date: chosen,
            time: chosen.toLocal().toString().split(' ')[1].substring(0, 5),
            amount: price > 0 ? price : 500.0,
            description: desc,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Navigation to checkout failed: $e');
      paid = false;
    }

    if (paid == true) {
      if (mounted) setState(() => _processing = true);

      // ensure provisional write completed successfully before attempting transaction
      try {
        await writeFuture;
      } catch (e) {
        debugPrint('Provisional write failed before finalization: $e');
        if (mounted) setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create provisional booking: $e')),
        );
        return;
      }

      // finalize booking in transaction
      final centralRef = _fire
          .collection('shop')
          .doc(_selectedShopId)
          .collection('bookings')
          .doc(provRef.id);
      final barberRef = _fire
          .collection('shop')
          .doc(_selectedShopId)
          .collection('barber')
          .doc(barberId)
          .collection('bookings')
          .doc(provRef.id);

      try {
        await _fire.runTransaction((tx) async {
          final snap = await tx.get(centralRef);
          if (!snap.exists) throw Exception('Provisional booking missing');

          // Re-check conflicts inside the transaction
          // Some composite queries require an index; try the range query first
          // and fall back to an equality-only query + client-side filter if
          // Firestore complains about a missing index.
          bool conflictFound = false;
          try {
            final conflicts = await _fire
                .collection('shop')
                .doc(_selectedShopId)
                .collection('bookings')
                .where('barberId', isEqualTo: barberId)
                .where('status', isEqualTo: 'confirmed')
                .where('scheduledAt', isGreaterThanOrEqualTo: lower)
                .where('scheduledAt', isLessThan: upper)
                .get();

            if (conflicts.docs.isNotEmpty) conflictFound = true;
          } catch (e) {
            // If Firestore requires a composite index the SDK may throw a
            // failed-precondition / permission error; fall back to fetching
            // confirmed bookings for this barber and filter locally.
            debugPrint(
              'Range query failed, falling back to client-side filter: $e',
            );
            try {
              final alt = await _fire
                  .collection('shop')
                  .doc(_selectedShopId)
                  .collection('bookings')
                  .where('barberId', isEqualTo: barberId)
                  .where('status', isEqualTo: 'confirmed')
                  .get();

              for (final d in alt.docs) {
                final ts = d.data()['scheduledAt'];
                if (ts is Timestamp) {
                  final dt = ts.toDate();
                  if (!dt.isBefore(lower.toDate()) &&
                      dt.isBefore(upper.toDate())) {
                    conflictFound = true;
                    break;
                  }
                }
              }
            } catch (e2) {
              // If fallback also fails, propagate to abort the transaction
              debugPrint('Fallback conflict check failed: $e2');
              rethrow;
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
              .doc(uid)
              .collection('bookings')
              .doc(provRef.id);
          tx.set(userRef, {
            ...(snap.data() as Map<String, dynamic>),
            'status': 'confirmed',
            'booking_confirmed': true,
          });

          final payRef = _fire
              .collection('shop')
              .doc(_selectedShopId)
              .collection('payments')
              .doc();
          tx.set(payRef, {
            'bookingId': provRef.id,
            'userId': uid,
            'barberId': barberId,
            'amount': price > 0 ? price : 500.0,
            'serviceTitle': serviceTitle,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        if (mounted) setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed and payment recorded'),
          ),
        );
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        try {
          await provRef.delete();
        } catch (_) {}
        if (mounted) setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm booking: $e')),
        );
        return;
      }
    } else {
      // payment not completed, attempt to delete provisional booking if it was created
      try {
        await writeFuture;
        await provRef.delete();
      } catch (e) {
        debugPrint(
          'Could not remove provisional booking after cancelled payment: $e',
        );
      }
      if (mounted) setState(() => _processing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment cancelled')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make a Booking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select shop'),
              items: _shops
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'],
                      child: Text(s['name']!),
                    ),
                  )
                  .toList(),
              value: _selectedShopId,
              onChanged: (v) async {
                setState(() {
                  _selectedShopId = v;
                  _selectedBarber = null;
                  _selectedService = null;
                });
                if (v != null) {
                  await _loadBarbers(v);
                  await _loadServices(v);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Choose barber'),
              items: _barbers
                  .map(
                    (b) => DropdownMenuItem(
                      value: b['id'],
                      child: Text(b['name']!),
                    ),
                  )
                  .toList(),
              value: _selectedBarber?['id'],
              onChanged: (v) {
                setState(() {
                  _selectedBarber = _barbers.firstWhere((b) => b['id'] == v);
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Choose service'),
              items: _services
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['id'].toString(),
                      child: Text('${s['title']} - ৳${s['price']}'),
                    ),
                  )
                  .toList(),
              value: _selectedService?['id']?.toString(),
              onChanged: (v) {
                if (v == null) return;
                setState(
                  () => _selectedService = _services.firstWhere(
                    (s) => s['id'].toString() == v,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Date & Time'),
              subtitle: Text(
                _selectedDateTime != null
                    ? _selectedDateTime.toString()
                    : 'Not selected',
              ),
              trailing: ElevatedButton(
                onPressed: _pickDateTime,
                child: const Text('Pick'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _makeBooking,
                child: _processing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Confirm Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
