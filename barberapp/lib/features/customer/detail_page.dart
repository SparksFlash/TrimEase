import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../payment/checkout.dart';
import '../../utils/firebase_helper.dart';

/// DetailPage shows booking UI for a specific service at a specific barber/shop.
/// It accepts shopId, barberId, serviceId. If serviceName is null, the page
/// will try to load the service document to show the title and price.
class DetailPage extends StatefulWidget {
  final String shopId;
  final String barberId;
  final String serviceId;
  final String? serviceName;

  const DetailPage({
    super.key,
    required this.shopId,
    required this.barberId,
    required this.serviceId,
    this.serviceName,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  int selectedDayIndex = 0;
  int selectedTimeIndex = -1;

  late final List<DateTime> availableDates;
  final List<String> times = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
    '07:00 PM',
    '08:00 PM',
    '09:00 PM',
  ];

  // per-barber booking store key prefix (local cache)
  String get _prefsKeyPrefix => 'booked_slots_${widget.barberId}';

  // map of slotKey -> timestamp millis (when booked locally)
  Map<String, int> _bookedSlots = {};

  // remote blocked times for currently selected day (populate from Firestore)
  final Set<String> _remoteBlockedTimes = {};

  String _serviceTitle = '';
  double _servicePrice = 0.0;

  @override
  void initState() {
    super.initState();
    availableDates = List.generate(
      6,
      (i) => DateTime.now().add(Duration(days: i)),
    );
    _loadBookedSlots();
    _loadServiceIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadRemoteBlockedForDay(availableDates[selectedDayIndex]),
    );
  }

  String _weekdayShort(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }

  Future<void> _loadServiceIfNeeded() async {
    if (widget.serviceName != null && widget.serviceName!.isNotEmpty) {
      setState(() => _serviceTitle = widget.serviceName!);
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('shop')
              .doc(widget.shopId)
              .collection('services')
              .doc(widget.serviceId)
              .get();
      final data = doc.data();
      setState(() {
        _serviceTitle = (data?['title'] ?? data?['name'] ?? '').toString();
        _servicePrice =
            (data?['price'] is num)
                ? (data!['price'] as num).toDouble()
                : double.tryParse((data?['price'] ?? '0').toString()) ?? 0.0;
      });
    } catch (_) {}
  }

  // local cache load and cleanup expired bookings (older than 24h)
  Future<void> _loadBookedSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKeyPrefix);
    if (raw == null) {
      _bookedSlots = {};
      return;
    }
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cutoff24h = now - Duration(hours: 24).inMilliseconds;
      _bookedSlots = {};
      decoded.forEach((k, v) {
        final ts = (v as num).toInt();
        if (ts >= cutoff24h) _bookedSlots[k] = ts;
      });
      await prefs.setString(_prefsKeyPrefix, jsonEncode(_bookedSlots));
      if (mounted) setState(() {});
    } catch (_) {
      _bookedSlots = {};
    }
  }

  Future<void> _saveBookedSlots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyPrefix, jsonEncode(_bookedSlots));
  }

  // build a stable slot key for selected date/time (includes barber and service)
  String _slotKeyForDate(DateTime dt, String time) {
    final dateStr =
        '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    return '${widget.barberId}|${widget.serviceId}|$dateStr|$time';
  }

  bool _isSlotBookedForDate(DateTime dt, String time) {
    final key = _slotKeyForDate(dt, time);
    final ts = _bookedSlots[key];
    if (ts == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - ts < Duration(hours: 24).inMilliseconds;
  }

  _HourMinute? _timeStringToHourMinute(String t) {
    try {
      final parts = t.split(' ');
      final hm = parts[0].split(':');
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      final ampm = parts.length > 1 ? parts[1] : '';
      if (ampm.toUpperCase() == 'PM' && hour < 12) hour += 12;
      if (ampm.toUpperCase() == 'AM' && hour == 12) hour = 0;
      return _HourMinute(hour, minute);
    } catch (_) {
      return null;
    }
  }

  // load remote bookings for a day and mark remote blocked times
  Future<void> _loadRemoteBlockedForDay(DateTime day) async {
    try {
      _remoteBlockedTimes.clear();
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final lower = Timestamp.fromDate(
        dayStart.subtract(const Duration(minutes: 59)),
      );
      final upper = Timestamp.fromDate(dayEnd.add(const Duration(minutes: 60)));

      final snap =
          await FirebaseFirestore.instance
              .collection('shop')
              .doc(widget.shopId)
              .collection('bookings')
              .where('barberId', isEqualTo: widget.barberId)
              .where('status', whereIn: ['confirmed', 'provisional'])
              .where('scheduledAt', isGreaterThanOrEqualTo: lower)
              .where('scheduledAt', isLessThan: upper)
              .get();

      for (final d in snap.docs) {
        final data = d.data();
        final ts = (data['scheduledAt'] as Timestamp?)?.toDate();
        if (ts == null) continue;
        for (final t in times) {
          final hm = _timeStringToHourMinute(t);
          if (hm == null) continue;
          final candidate = DateTime(
            ts.year,
            ts.month,
            ts.day,
            hm.item1,
            hm.item2,
          );
          final diff = candidate.difference(ts).inMinutes;
          if (diff >= -59 && diff < 60) _remoteBlockedTimes.add(t);
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // Mark slot booked locally and block 1-hour window locally
  Future<void> _markSlotBooked(DateTime dt, String time) async {
    final key = _slotKeyForDate(dt, time);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _bookedSlots[key] = nowMs;

    final h = _timeStringToHourMinute(time);
    if (h != null) {
      final chosen = DateTime(dt.year, dt.month, dt.day, h.item1, h.item2);
      for (final t in times) {
        final hh = _timeStringToHourMinute(t);
        if (hh == null) continue;
        final candidate = DateTime(
          dt.year,
          dt.month,
          dt.day,
          hh.item1,
          hh.item2,
        );
        final diff = candidate.difference(chosen).inMinutes;
        if (diff >= -59 && diff < 60) {
          final k = _slotKeyForDate(dt, t);
          _bookedSlots[k] = nowMs;
        }
      }
    }

    await _saveBookedSlots();
    if (mounted) setState(() {});
  }

  // Main flow: provisional booking -> payment -> confirm transaction
  Future<void> _onBookNow() async {
    // validate UI selection
    if (selectedTimeIndex == -1) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a time slot!')),
        );
      return;
    }

    final dt = availableDates[selectedDayIndex];
    final time = times[selectedTimeIndex];
    if (_isSlotBookedForDate(dt, time) || _remoteBlockedTimes.contains(time)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This slot is already booked')),
        );
      return;
    }

    final chosenHM = _timeStringToHourMinute(time);
    if (chosenHM == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid time')));
      return;
    }

    final chosenStart = DateTime(
      dt.year,
      dt.month,
      dt.day,
      chosenHM.item1,
      chosenHM.item2,
    );
    final lower = Timestamp.fromDate(
      chosenStart.subtract(const Duration(minutes: 59)),
    );
    final upper = Timestamp.fromDate(
      chosenStart.add(const Duration(minutes: 60)),
    );

    // check for existing provisional/confirmed bookings in Firestore
    final conflictQuery =
        await FirebaseFirestore.instance
            .collection('shop')
            .doc(widget.shopId)
            .collection('bookings')
            .where('barberId', isEqualTo: widget.barberId)
            .where('status', whereIn: ['confirmed', 'provisional'])
            .where('scheduledAt', isGreaterThanOrEqualTo: lower)
            .where('scheduledAt', isLessThan: upper)
            .get();

    if (conflictQuery.docs.isNotEmpty) {
      await _loadRemoteBlockedForDay(dt);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected time conflicts with existing booking'),
          ),
        );
      return;
    }

    // create provisional booking (blocks the slot while paying)
    final provisionalRef =
        FirebaseFirestore.instance
            .collection('shop')
            .doc(widget.shopId)
            .collection('bookings')
            .doc();

    final provisionalData = {
      'barberId': widget.barberId,
      'serviceId': widget.serviceId,
      'serviceTitle': _serviceTitle,
      'customerId': FirebaseHelper.currentUid(),
      'scheduledAt': Timestamp.fromDate(chosenStart),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'provisional',
      'booking_confirmed': false,
    };

    await provisionalRef.set(provisionalData);
    await _loadRemoteBlockedForDay(dt);

    final amount = _servicePrice > 0 ? _servicePrice : 500.0; // fallback
    final description =
        '$_serviceTitle on ${dt.toLocal().toString().split(' ')[0]} at $time';

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => PaymentCheckout(
              serviceName: _serviceTitle,
              date: dt,
              time: time,
              amount: amount,
              description: description,
            ),
      ),
    );

    if (result == true) {
      // Payment succeeded — confirm provisional booking in a transaction
      try {
        final uid = FirebaseHelper.currentUid();
        final provRef = provisionalRef;

        await FirebaseFirestore.instance.runTransaction((tx) async {
          final provSnap = await tx.get(provRef);
          if (!provSnap.exists)
            throw Exception('Provisional booking not found');

          // ensure no confirmed booking exists in the window
          final conflicts =
              await FirebaseFirestore.instance
                  .collection('shop')
                  .doc(widget.shopId)
                  .collection('bookings')
                  .where('barberId', isEqualTo: widget.barberId)
                  .where('status', isEqualTo: 'confirmed')
                  .where('scheduledAt', isGreaterThanOrEqualTo: lower)
                  .where('scheduledAt', isLessThan: upper)
                  .get();

          if (conflicts.docs.isNotEmpty) {
            tx.delete(provRef);
            throw Exception('Conflict detected while confirming booking');
          }

          tx.update(provRef, {
            'status': 'confirmed',
            'booking_confirmed': true,
            'confirmedAt': FieldValue.serverTimestamp(),
          });

          // mirror under barber subcollection
          final barberBookingRef = FirebaseFirestore.instance
              .collection('shop')
              .doc(widget.shopId)
              .collection('barber')
              .doc(widget.barberId)
              .collection('bookings')
              .doc(provRef.id);

          tx.set(barberBookingRef, {
            ...provSnap.data() as Map<String, dynamic>,
            'status': 'confirmed',
            'booking_confirmed': true,
          });

          // mirror under user bookings
          if (uid.isNotEmpty) {
            final userBookingRef = FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('bookings')
                .doc(provRef.id);
            tx.set(userBookingRef, {
              ...provSnap.data() as Map<String, dynamic>,
              'status': 'confirmed',
              'booking_confirmed': true,
            });
          }
        });

        await _markSlotBooked(dt, time);
        await _loadRemoteBlockedForDay(dt);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Booking confirmed.')));
      } catch (e) {
        try {
          await provisionalRef.delete();
        } catch (_) {}
        await _loadRemoteBlockedForDay(dt);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to confirm booking: $e')),
          );
      }
    } else {
      // payment cancelled or failed
      try {
        await provisionalRef.delete();
      } catch (_) {}
      await _loadRemoteBlockedForDay(dt);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment cancelled or failed.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xff2c3925),
      appBar: AppBar(
        backgroundColor: const Color(0xff2c3925),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _serviceTitle.isNotEmpty ? _serviceTitle : 'Service',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barber info (could be loaded from firestore if needed)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.asset(
                      'images/barber1.png',
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Attempt to load a known-good fallback image from assets
                        return Image.asset(
                          'images/barber.png',
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context2, error2, stackTrace2) => Container(
                                height: 100,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade300,
                                  borderRadius: BorderRadius.circular(60),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Barber',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.barberId,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'CHOOSE YOUR SLOT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Date selector
            SizedBox(
              height: 86,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: availableDates.length,
                itemBuilder: (context, index) {
                  final dt = availableDates[index];
                  final isSelected = selectedDayIndex == index;
                  return GestureDetector(
                    onTap: () async {
                      setState(() {
                        selectedDayIndex = index;
                        selectedTimeIndex = -1;
                      });
                      await _loadRemoteBlockedForDay(dt);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xfffdece7)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdayShort(dt),
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dt.day.toString(),
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Time selector area
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F0E1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHOOSE YOUR TIME',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 2.6,
                            ),
                        itemCount: times.length,
                        itemBuilder: (context, index) {
                          final time = times[index];
                          final dt = availableDates[selectedDayIndex];
                          final disabled =
                              _isSlotBookedForDate(dt, time) ||
                              _remoteBlockedTimes.contains(time);
                          final isSelected =
                              selectedTimeIndex == index && !disabled;
                          return GestureDetector(
                            onTap:
                                disabled
                                    ? null
                                    : () => setState(
                                      () => selectedTimeIndex = index,
                                    ),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    disabled
                                        ? Colors.grey.shade300
                                        : (isSelected
                                            ? const Color(0xFF2E3B2A)
                                            : Colors.white),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.black26,
                                ),
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  color:
                                      disabled
                                          ? Colors.grey.shade600
                                          : (isSelected
                                              ? Colors.white
                                              : Colors.black),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // BOOK NOW button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2c3925),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _onBookNow,
                        child: const Text(
                          'BOOK NOW',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// small tuple to return hour and minute
class _HourMinute {
  final int item1;
  final int item2;
  _HourMinute(this.item1, this.item2);
}
