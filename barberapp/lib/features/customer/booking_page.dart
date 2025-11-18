import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter/material.dart';
import 'dart:async';
import '../../payment/checkout.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({Key? key}) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late final FirebaseFirestore _fire;
  fb_auth.User? _user;

  String? _selectedShopId;
  Map<String, String>? _selectedBarber; // {id, name}
  Map<String, dynamic>? _selectedService; // doc data
  DateTime? _selectedDate;
  String? _selectedSlotId;

  // 12 slots from 9-10am to 8-9pm
  final List<Map<String, dynamic>> _timeSlots = List.generate(12, (i) {
    final start = 9 + i;
    final end = start + 1;
    final label =
        '${start.toString().padLeft(2, '0')}:00 - ${end.toString().padLeft(2, '0')}:00';
    final id =
        '${start.toString().padLeft(2, '0')}-${end.toString().padLeft(2, '0')}';
    return {'id': id, 'label': label, 'start': start};
  });

  // booked slot ids for selected barber/date
  Set<String> _bookedSlotIds = {};
  StreamSubscription<QuerySnapshot>? _bookedSub;

  List<Map<String, String>> _shops = [];
  List<Map<String, String>> _barbers = [];
  List<Map<String, dynamic>> _services = [];
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    try {
      _fire = FirebaseFirestore.instance;
      if (firebase_core.Firebase.apps.isNotEmpty) {
        _user = fb_auth.FirebaseAuth.instance.currentUser;
      }
    } catch (_) {
      _fire = FirebaseFirestore.instance;
      _user = null;
    }
    _loadShops();
  }

  Future<void> _loadShops() async {
    final snap = await _fire.collection('shop').get();
    final list =
        snap.docs
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
    final snap =
        await _fire.collection('shop').doc(shopId).collection('barber').get();
    final list =
        snap.docs
            .map(
              (d) => {
                'id': d.id,
                'name': (d.data()['name'] ?? d.id).toString(),
              },
            )
            .toList();
    setState(() => _barbers = List<Map<String, String>>.from(list));
  }

  Future<void> _loadServices(String shopId) async {
    final snap =
        await _fire.collection('shop').doc(shopId).collection('services').get();
    final list =
        snap.docs.map((d) {
          final m = d.data();
          m['id'] = d.id;
          return m;
        }).toList();
    setState(() => _services = List<Map<String, dynamic>>.from(list));
  }

  Future<void> _pickDateTime() async {
    // Deprecated: replaced by date-only picker + slot selection UI.
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null) return;
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _selectedSlotId = null;
    });
    // fetch booked slots for selected barber+date
    if (_selectedBarber != null && _selectedShopId != null) {
      await _fetchBookedSlots(
        _selectedShopId!,
        _selectedBarber!['id']!,
        _selectedDate!,
      );
    }
  }

  Future<void> _fetchBookedSlots(
    String shopId,
    String barberId,
    DateTime date,
  ) async {
    // normalize date to yyyy-mm-dd string for equality
    final dayStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // cancel any previous listener
    try {
      await _bookedSub?.cancel();
    } catch (_) {}

    try {
      final query = _fire
          .collection('shop')
          .doc(shopId)
          .collection('bookings')
          .where('barberId', isEqualTo: barberId)
          .where('status', isEqualTo: 'confirmed')
          .where('scheduledDate', isEqualTo: dayStr);

      _bookedSub = query.snapshots().listen(
        (snap) {
          final ids = <String>{};
          for (final d in snap.docs) {
            final slot = (d.data()['slotId'] ?? '').toString();
            if (slot.isNotEmpty) ids.add(slot);
          }
          if (mounted) setState(() => _bookedSlotIds = ids);
        },
        onError: (e) {
          debugPrint('Booked slots listener error: $e');
          if (mounted) setState(() => _bookedSlotIds = {});
        },
      );
    } catch (e) {
      debugPrint('Failed to start booked slots listener: $e');
      if (mounted) setState(() => _bookedSlotIds = {});
    }
  }

  @override
  void dispose() {
    _bookedSub?.cancel();
    super.dispose();
  }

  Future<void> _makeBooking() async {
    if (_processing) return;
    setState(() => _processing = true);

    if (_selectedShopId == null ||
        _selectedBarber == null ||
        _selectedService == null ||
        _selectedDate == null ||
        _selectedSlotId == null) {
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
    final serviceTitle =
        (_selectedService!['title'] ?? _selectedService!['name'] ?? 'Service')
            .toString();
    final price =
        (_selectedService!['price'] is num)
            ? (_selectedService!['price'] as num).toDouble()
            : double.tryParse((_selectedService!['price'] ?? '').toString()) ??
                0.0;

    final chosenDate = _selectedDate!;
    final slotId = _selectedSlotId!;

    // For backwards compatibility we store scheduledDate (yyyy-mm-dd) and slotId
    final scheduledDateStr =
        '${chosenDate.year.toString().padLeft(4, '0')}-${chosenDate.month.toString().padLeft(2, '0')}-${chosenDate.day.toString().padLeft(2, '0')}';

    // create provisional booking ref+data
    final provRef =
        _fire
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
      'scheduledDate': scheduledDateStr,
      'slotId': slotId,
      // Keep scheduledAt for compatibility (set to start hour of slot)
      'scheduledAt': Timestamp.fromDate(
        DateTime(
          chosenDate.year,
          chosenDate.month,
          chosenDate.day,
          int.parse(slotId.split('-')[0]),
        ),
      ),
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

    final slotLabel = _timeSlots.firstWhere((s) => s['id'] == slotId)['label'];
    final desc = '$serviceTitle on $scheduledDateStr at $slotLabel';

    bool? paid;
    try {
      paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (_) => PaymentCheckout(
                serviceName: serviceTitle,
                date: DateTime.parse(scheduledDateStr),
                time: slotLabel,
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

          // Re-check conflicts: ensure no confirmed booking exists with same barber, date and slotId
          final conflicts =
              await _fire
                  .collection('shop')
                  .doc(_selectedShopId)
                  .collection('bookings')
                  .where('barberId', isEqualTo: barberId)
                  .where('status', isEqualTo: 'confirmed')
                  .where('scheduledDate', isEqualTo: scheduledDateStr)
                  .where('slotId', isEqualTo: slotId)
                  .get();
          if (conflicts.docs.isNotEmpty) {
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

          final payRef =
              _fire
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
              items:
                  _shops
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
              items:
                  _barbers
                      .map(
                        (b) => DropdownMenuItem(
                          value: b['id'],
                          child: Text(b['name']!),
                        ),
                      )
                      .toList(),
              value: _selectedBarber?['id'],
              onChanged: (v) async {
                setState(() {
                  _selectedBarber = _barbers.firstWhere((b) => b['id'] == v);
                  _selectedSlotId = null;
                  _bookedSlotIds = {};
                });
                if (v != null &&
                    _selectedDate != null &&
                    _selectedShopId != null) {
                  await _fetchBookedSlots(_selectedShopId!, v, _selectedDate!);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Choose service'),
              items:
                  _services.map((s) {
                    final title = (s['title'] ?? s['name'] ?? '').toString();
                    final price = s['price'] ?? s['cost'] ?? '';
                    final label =
                        price.toString().isNotEmpty
                            ? '$title - ৳$price'
                            : title;
                    return DropdownMenuItem<String>(
                      value: s['id'].toString(),
                      child: Text(label),
                    );
                  }).toList(),
              value: _selectedService?['id']?.toString(),
              onChanged: (v) {
                if (v == null) return;
                setState(
                  () =>
                      _selectedService = _services.firstWhere(
                        (s) => s['id'].toString() == v,
                      ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Select date'),
              subtitle: Text(
                _selectedDate != null
                    ? _selectedDate!.toLocal().toString().split(' ')[0]
                    : 'Not selected',
              ),
              trailing: ElevatedButton(
                onPressed: _pickDateTime,
                child: const Text('Pick Date'),
              ),
            ),
            const SizedBox(height: 8),
            // Slot grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _timeSlots.map((s) {
                    final id = s['id'] as String;
                    final label = s['label'] as String;
                    final booked = _bookedSlotIds.contains(id);
                    final selected = _selectedSlotId == id;

                    // Disable past slots if selected date is today
                    var past = false;
                    if (_selectedDate != null) {
                      final now = DateTime.now();
                      if (_selectedDate!.year == now.year &&
                          _selectedDate!.month == now.month &&
                          _selectedDate!.day == now.day) {
                        final slotStart = DateTime(
                          _selectedDate!.year,
                          _selectedDate!.month,
                          _selectedDate!.day,
                          s['start'] as int,
                        );
                        if (slotStart.isBefore(now)) past = true;
                      }
                    }

                    final disabled = booked || past;

                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (on) async {
                        if (disabled) return;
                        setState(() => _selectedSlotId = on ? id : null);
                      },
                      selectedColor: Colors.blue,
                      backgroundColor: disabled ? Colors.grey.shade300 : null,
                    );
                  }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _makeBooking,
                child:
                    _processing
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
