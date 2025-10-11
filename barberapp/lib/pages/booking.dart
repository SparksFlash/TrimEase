// import 'package:flutter/material.dart';

// class Booking extends StatelessWidget {
//   const Booking({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(
//         child: Text(
//           "Booking Page",
//           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//         ),
//       ),
//     );
//   }
// }

// ...existing code...
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Booking extends StatefulWidget {
  const Booking({super.key});

  @override
  State<Booking> createState() => _BookingState();
}

class BookingItem {
  final String id;
  final String service;
  final String date; // e.g. "2025-10-12"
  final String time; // e.g. "09:00 AM"

  BookingItem({
    required this.id,
    required this.service,
    required this.date,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'service': service,
    'date': date,
    'time': time,
  };

  static BookingItem fromJson(Map<String, dynamic> j) => BookingItem(
    id: j['id'] as String,
    service: j['service'] as String,
    date: j['date'] as String,
    time: j['time'] as String,
  );
}

class _BookingState extends State<Booking> {
  List<BookingItem> _bookings = [];
  bool _loading = true;

  String get _prefsKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'bookings_$uid';
  }

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _bookings = list
            .map((e) => BookingItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _bookings = [];
      }
    } else {
      _bookings = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_bookings.map((b) => b.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  Future<void> _removeBooking(String id) async {
    _bookings.removeWhere((b) => b.id == id);
    await _saveBookings();
    if (mounted) setState(() {});
  }

  Future<void> _addSampleBooking() async {
    final now = DateTime.now();
    final sample = BookingItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      service: "HAIR CUT",
      date:
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      time: "10:00 AM",
    );
    _bookings.insert(0, sample);
    await _saveBookings();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Booking"), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      "No bookings yet",
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Your upcoming bookings will appear here.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black45),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addSampleBooking,
                      child: const Text("Add sample booking"),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBookings,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final b = _bookings[index];
                  return Dismissible(
                    key: ValueKey(b.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Cancel booking'),
                          content: const Text(
                            'Are you sure you want to cancel this booking?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(c).pop(false),
                              child: const Text('No'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(c).pop(true),
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );
                      return ok == true;
                    },
                    onDismissed: (_) => _removeBooking(b.id),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        title: Text(
                          b.service,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text("${b.date} • ${b.time}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.service,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text("Date: ${b.date}"),
                                    const SizedBox(height: 4),
                                    Text("Time: ${b.time}"),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _removeBooking(b.id);
                                      },
                                      icon: const Icon(Icons.cancel),
                                      label: const Text("Cancel booking"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSampleBooking,
        icon: const Icon(Icons.add),
        label: const Text("Sample"),
      ),
    );
  }
}
