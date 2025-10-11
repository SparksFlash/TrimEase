import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/checkout/checkout.dart';

class DetailPage extends StatefulWidget {
  final String serviceName;
  const DetailPage({super.key, required this.serviceName});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  int selectedDayIndex = 0;
  int selectedTimeIndex = -1;

  late final List<DateTime> availableDates;
  final List<String> times = [
    "09:00 AM",
    "10:00 AM",
    "11:00 AM",
    "12:00 PM",
    "01:00 PM",
    "02:00 PM",
    "03:00 PM",
    "04:00 PM",
    "05:00 PM",
    "06:00 PM",
    "07:00 PM",
    "08:00 PM",
    "09:00 PM",
  ];

  // booking store key
  static const String _prefsKey = 'booked_slots';

  // map of slotKey -> timestamp millis (when booked)
  Map<String, int> _bookedSlots = {};

  String? idToken;
  final String bkashBaseUrl = "http://localhost:34893/"; // test URL
  final String appKey = "trime68e81f8f7f99f@ssl";
  final String appSecret = "trime68e81f8f7f99f@ssl";
  final String username = "Sandipta Saha ";
  final String password = "souravug2102056";

  @override
  void initState() {
    super.initState();
    // generate next 6 days (including today)
    availableDates = List.generate(
      6,
      (i) => DateTime.now().add(Duration(days: i)),
    );
    _loadBookedSlots();
  }

  String _weekdayShort(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }

  // load and cleanup expired bookings (older than 24h)
  Future<void> _loadBookedSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
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
      await prefs.setString(_prefsKey, jsonEncode(_bookedSlots));
      if (mounted) setState(() {});
    } catch (_) {
      _bookedSlots = {};
    }
  }

  Future<void> _saveBookedSlots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_bookedSlots));
  }

  // build a stable slot key for selected date/time
  String _slotKeyForDate(DateTime dt, String time) {
    final dateStr =
        "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    return "$dateStr|$time|${widget.serviceName}";
  }

  bool _isSlotBookedForDate(DateTime dt, String time) {
    final key = _slotKeyForDate(dt, time);
    final ts = _bookedSlots[key];
    if (ts == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - ts < Duration(hours: 24).inMilliseconds;
  }

  Future<void> _markSlotBooked(DateTime dt, String time) async {
    final key = _slotKeyForDate(dt, time);
    _bookedSlots[key] = DateTime.now().millisecondsSinceEpoch;
    await _saveBookedSlots();
    if (mounted) setState(() {});
  }

  // bKash Authentication (kept for completeness, not used directly here)
  Future<void> authenticateBkash() async {
    final response = await http.post(
      Uri.parse("$bkashBaseUrl/v1.2.0-beta/token/grant"),
      headers: {"username": username, "password": password},
      body: {"app_key": appKey, "app_secret": appSecret},
    );
    if (response.statusCode == 200) {
      setState(() {
        idToken = jsonDecode(response.body)['id_token'];
      });
    } else {
      throw Exception("bKash authentication failed");
    }
  }

  // Create Payment (kept for reference)
  Future<void> createPayment() async {
    if (idToken == null) await authenticateBkash();

    final response = await http.post(
      Uri.parse("$bkashBaseUrl/v1.2.0-beta/payment/create"),
      headers: {
        "Authorization": idToken ?? "",
        "X-APP-Key": appKey,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "amount": "500",
        "currency": "BDT",
        "intent": "sale",
        "merchantInvoiceNumber": "INV-${DateTime.now().millisecondsSinceEpoch}",
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final bkashUrl = data["bkashURL"];
      if (bkashUrl == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Payment URL missing")));
        return;
      }
      final uri = Uri.parse(bkashUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception("Could not launch bKash URL");
      }
    } else {
      throw Exception("Payment failed");
    }
  }

  Future<void> _onBookNow() async {
    if (selectedTimeIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a time slot!")),
      );
      return;
    }

    final dt = availableDates[selectedDayIndex];
    final time = times[selectedTimeIndex];
    if (_isSlotBookedForDate(dt, time)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This slot is already booked for 24 hours"),
        ),
      );
      return;
    }

    // Navigate to Checkout and wait for payment result
    // pass minimal info: serviceName, date, time, amount
    final amount = 500.0; // change as needed or pass dynamic price
    final description =
        '${widget.serviceName} on ${dt.toLocal().toString().split(' ')[0]} at $time';

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => Checkout(
          serviceName: widget.serviceName,
          date: dt,
          time: time,
          amount: amount,
          description: description,
        ),
      ),
    );

    // if payment successful -> mark slot booked
    if (result == true) {
      await _markSlotBooked(dt, time);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Booking confirmed.")));
      }
    } else {
      // payment failed / cancelled
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment cancelled or failed.")),
        );
      }
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
          widget.serviceName,
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
            // Barber info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.asset(
                      'images/barber1.png', // ensure this exists in pubspec; errorBuilder used as fallback
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
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
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "John Doe",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Barberman",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "CHOOSE YOUR SLOT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Date selector (increased height + padding to avoid overlap)
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
                    onTap: () => setState(() {
                      selectedDayIndex = index;
                      selectedTimeIndex = -1;
                    }),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: isSelected
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
                      "CHOOSE YOUR TIME",
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
                          final disabled = _isSlotBookedForDate(dt, time);
                          final isSelected =
                              selectedTimeIndex == index && !disabled;
                          return GestureDetector(
                            onTap: disabled
                                ? null
                                : () =>
                                      setState(() => selectedTimeIndex = index),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: disabled
                                    ? Colors.grey.shade300
                                    : (isSelected
                                          ? const Color(0xFF2E3B2A)
                                          : Colors.white),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black26,
                                ),
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  color: disabled
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
                          "BOOK NOW",
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
