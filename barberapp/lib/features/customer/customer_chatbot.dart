import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/provider/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../payment/checkout.dart';
import '../../widgets/premium_background.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime timestamp;
  ChatMessage(this.text, {this.fromUser = true, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class PendingBooking {
  final String shopId;
  final String serviceId;
  final DateTime scheduled;
  PendingBooking({
    required this.shopId,
    required this.serviceId,
    required this.scheduled,
  });
}

class CustomerChatbot extends StatefulWidget {
  final String userId;
  const CustomerChatbot({Key? key, required this.userId}) : super(key: key);

  @override
  State<CustomerChatbot> createState() => _CustomerChatbotState();
}

class _CustomerChatbotState extends State<CustomerChatbot> {
  final List<ChatMessage> _messages = [];
  final _controller = TextEditingController();
  bool _loading = false;
  bool _botTyping = false;
  bool _awaitingConfirmation = false;
  PendingBooking? _pendingBooking;
  // Multi-step booking conversation state
  String? _selectedShopId;
  String? _selectedShopName;
  String? _selectedBarberId;
  String? _selectedBarberName;
  String? _selectedServiceId;
  Map<String, dynamic>? _selectedServiceData;
  DateTime? _selectedDate;
  String? _selectedTime;
  List<QueryDocumentSnapshot<Object?>>? _lastShopDocs;
  List<QueryDocumentSnapshot<Object?>>? _lastBarberDocs;
  List<QueryDocumentSnapshot<Object?>>? _lastServiceDocs;

  @override
  void initState() {
    super.initState();
    _tryLoadDotenv();
    _addBotMessage(
      'Hi! I can help you find shops, services, and make bookings. Try: "show shops" or "book".',
    );
  }

  Future<void> _tryLoadDotenv() async {
    try {
      if (!dotenv.isInitialized) await dotenv.load();
    } catch (_) {}
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.insert(0, ChatMessage(text, fromUser: true));
    });
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.insert(0, ChatMessage(text, fromUser: false));
    });
  }

  Future<void> _sendBotMessage(String text, {int delayMs = 500}) async {
    if (!mounted) return;
    setState(() {
      _botTyping = true;
    });
    await Future.delayed(Duration(milliseconds: delayMs));
    if (!mounted) return;
    _addBotMessage(text);
    if (!mounted) return;
    setState(() {
      _botTyping = false;
    });
  }

  Future<void> _onSend(String text) async {
    if (text.trim().isEmpty) return;
    // debug
    print('[Chatbot] _onSend called with: "$text"');
    _addUserMessage(text);
    _controller.clear();
    final lower = text.toLowerCase();

    // If we're awaiting confirmation, interpret yes/no
    if (_awaitingConfirmation && _pendingBooking != null) {
      final l = lower.trim();
      if (l.startsWith('y') || l.contains('yes') || l.contains('confirm')) {
        // proceed with booking
        _awaitingConfirmation = false;
        final pb = _pendingBooking!;
        _pendingBooking = null;
        await _handleDirectBooking(
          pb.shopId,
          pb.serviceId,
          _formatDate(pb.scheduled),
          _formatTime(pb.scheduled),
        );
        return;
      }
      if (l.startsWith('n') || l.contains('no') || l.contains('cancel')) {
        _awaitingConfirmation = false;
        _pendingBooking = null;
        await _sendBotMessage(
          'Booking cancelled. Let me know if you want to try another time or service.',
        );
        return;
      }
      // if unclear, ask again
      await _sendBotMessage(
        'Please reply with "Yes" to confirm or "No" to cancel the booking.',
      );
      return;
    }

    // Regex-based NLU: look for booking intent in several formats
    final bookRegex = RegExp(
      r'book\s+(\S+)\s+(\S+)\s+(\d{4}-\d{2}-\d{2})\s+(\d{1,2}:\d{2})',
      caseSensitive: false,
    );
    final m = bookRegex.firstMatch(text);
    if (m != null) {
      final shopId = m.group(1)!.trim();
      final serviceId = m.group(2)!.trim();
      final date = m.group(3)!.trim();
      final time = m.group(4)!.trim();
      try {
        final parts = date.split('-');
        final y = int.parse(parts[0]);
        final mo = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        final tparts = time.split(':');
        final h = int.parse(tparts[0]);
        final min = int.parse(tparts[1]);
        final scheduled = DateTime(y, mo, d, h, min);
        _pendingBooking = PendingBooking(
          shopId: shopId,
          serviceId: serviceId,
          scheduled: scheduled,
        );
        _awaitingConfirmation = true;
        await _sendBotMessage(
          'Do you want to confirm booking for service "$serviceId" at shop "$shopId" on ${_formatDate(scheduled.toLocal())} ${_formatTime(scheduled.toLocal())}? Reply Yes or No.',
        );
      } catch (e) {
        await _sendBotMessage(
          'Could not parse the date/time. Please use YYYY-MM-DD HH:MM format.',
        );
      }
      return;
    }
    // Interactive flow commands: select shop/barber/service/date/time, or list barbers/services
    // Recognize select / choose commands for interactive flow
    final selectShopRe = RegExp(
      r'(?:select|choose|pick) shop\s+(\S+)',
      caseSensitive: false,
    );
    final selectBarberRe = RegExp(
      r'(?:select|choose|pick) barber\s+(\S+)',
      caseSensitive: false,
    );
    final selectServiceRe = RegExp(
      r'(?:select|choose|pick) service\s+(\S+)',
      caseSensitive: false,
    );
    final chooseDateRe = RegExp(
      r'(?:choose|select|pick) date\s+(\d{4}-\d{2}-\d{2})',
      caseSensitive: false,
    );
    final chooseTimeRe = RegExp(
      r'(?:choose|select|pick|time)\s+(\d{1,2}:\d{2})',
      caseSensitive: false,
    );
    // Short forms accepted to make chat commands easy for users
    final shortDateRe = RegExp(
      r'^\s*date\s+(\d{4}-\d{2}-\d{2})\s*$',
      caseSensitive: false,
    );
    final shortTimeRe = RegExp(
      r'^\s*(?:timeslot|timeslot:)\s*(\d{1,2}:\d{2})\s*$',
      caseSensitive: false,
    );

    final sm = selectShopRe.firstMatch(text);
    if (sm != null) {
      final id = sm.group(1)!.trim();
      await _selectShopByIdOrIndex(id);
      return;
    }

    final bm = selectBarberRe.firstMatch(text);
    if (bm != null) {
      final id = bm.group(1)!.trim();
      await _selectBarberByIdOrIndex(id);
      return;
    }

    final sv = selectServiceRe.firstMatch(text);
    if (sv != null) {
      final id = sv.group(1)!.trim();
      await _selectServiceByIdOrIndex(id);
      return;
    }

    final dm = chooseDateRe.firstMatch(text);
    if (dm != null) {
      final d = dm.group(1)!.trim();
      try {
        final parts = d.split('-');
        final dt = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        _selectedDate = dt;
        await _sendBotMessage(
          'Date selected: ${_formatDate(dt)}. Now choose a time (e.g. "choose time 14:30").',
        );
      } catch (e) {
        await _sendBotMessage('Invalid date format, use YYYY-MM-DD.');
      }
      return;
    }

    final tm = chooseTimeRe.firstMatch(text);
    if (tm != null) {
      final t = tm.group(1)!.trim();
      _selectedTime = t;
      await _sendBotMessage(
        'Time selected: $t. When ready, say "pay" to open checkout and complete booking.',
      );
      return;
    }

    // Accept short forms like: "shop <name>", "barber <name>", "Date 2025-12-01", "Timeslot 14:30"
    // Note: allow users to give shop/barber by index, id or name (selection uses previous lists)
    final sshort = RegExp(
      r'^\s*shop\s+(.+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (sshort != null) {
      final id = sshort.group(1)!.trim();
      await _selectShopByIdOrIndex(id);
      return;
    }

    final bshort = RegExp(
      r'^\s*barber\s+(.+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (bshort != null) {
      final id = bshort.group(1)!.trim();
      await _selectBarberByIdOrIndex(id);
      return;
    }

    final dshort = shortDateRe.firstMatch(text);
    if (dshort != null) {
      final d = dshort.group(1)!.trim();
      try {
        final parts = d.split('-');
        final dt = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        _selectedDate = dt;
        await _sendBotMessage(
          'Date selected: ${_formatDate(dt)}. Now choose a time (e.g. "Timeslot 14:30").',
        );
      } catch (e) {
        await _sendBotMessage('Invalid date format, use YYYY-MM-DD.');
      }
      return;
    }

    final tshort = shortTimeRe.firstMatch(text);
    if (tshort != null) {
      final t = tshort.group(1)!.trim();
      _selectedTime = t;
      await _sendBotMessage(
        'Time selected: $t. When ready, say "pay" to open checkout and complete booking.',
      );
      return;
    }

    // commands to list barbers/services for current shop
    if (lower == 'show barbers' || lower == 'list barbers') {
      if (_selectedShopId == null) {
        await _sendBotMessage(
          'No shop selected. Use "show shops" and then "select shop <id|index>".',
        );
      } else {
        await _listBarbers(_selectedShopId!);
      }
      return;
    }

    if (lower == 'show services' || lower == 'list services') {
      if (_selectedShopId == null) {
        await _sendBotMessage(
          'No shop selected. Use "show shops" and then "select shop <id|index>".',
        );
      } else {
        await _handleShowServices(_selectedShopId!);
      }
      return;
    }

    if (lower.contains('show shops') || lower.contains('list shops')) {
      await _handleShowShops();
      return;
    }

    if (lower.startsWith('show services') || lower.startsWith('services')) {
      final parts = text.split(' ');
      final idx = parts.indexWhere((p) => p.toLowerCase() == 'for');
      String shopId = '';
      if (idx >= 0 && parts.length > idx + 1) shopId = parts[idx + 1];
      if (shopId.isEmpty) {
        _addBotMessage(
          'Please say "show services for <shopId>" or provide shop id.',
        );
      } else {
        await _handleShowServices(shopId);
      }
      return;
    }

    if (lower.startsWith('book')) {
      final parts = text.split(RegExp(r'\s+'));
      if (parts.length >= 5) {
        final shopId = parts[1];
        final service = parts[2];
        final date = parts[3];
        final time = parts[4];
        await _handleDirectBooking(shopId, service, date, time);
      } else {
        _addBotMessage(
          'To book via chat please use: book <shopId> <serviceId> <YYYY-MM-DD> <HH:MM>',
        );
      }
      return;
    }

    // Accept simple 'pay' or 'payment' commands to start checkout
    if (lower == 'pay' ||
        lower == 'payment' ||
        lower == 'goto payment' ||
        lower == 'done payment' ||
        lower == 'go to payment') {
      await _sendBotMessage('Opening payment...');
      await _proceedToPaymentAndBooking();
      return;
    }

    final apiUrl = dotenv.env['CHATBOT_API_URL'] ?? '';
    final apiKey = dotenv.env['CHATBOT_API_KEY'] ?? '';

    if (apiUrl.isNotEmpty) {
      await _forwardToApi(text, apiUrl, apiKey);
    } else {
      await _fallbackReply(text);
    }
  }

  Future<void> _forwardToApi(String text, String apiUrl, String apiKey) async {
    setState(() => _loading = true);
    try {
      final resp = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({'prompt': text}),
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final reply =
            (body['reply'] ?? body['text'] ?? body['message'] ?? '').toString();
        _addBotMessage(reply.isNotEmpty ? reply : 'No response from API');
      } else {
        _addBotMessage('API error: ${resp.statusCode}');
      }
    } catch (e) {
      _addBotMessage('Failed to call API: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Helpers for interactive booking flow
  Future<void> _selectShopByIdOrIndex(String idOrIndex) async {
    if (_lastShopDocs == null) {
      await _sendBotMessage('No shop list available. Say "show shops" first.');
      return;
    }
    QueryDocumentSnapshot<Object?>? doc;
    final idx = int.tryParse(idOrIndex);
    if (idx != null) {
      if (idx > 0 && idx <= _lastShopDocs!.length)
        doc = _lastShopDocs![idx - 1];
    }
    if (doc == null) {
      try {
        doc = _lastShopDocs!.firstWhere((d) => d.id == idOrIndex);
      } catch (_) {
        try {
          doc = _lastShopDocs!.firstWhere(
            (d) =>
                ((d.data() as Map)['shopName'] ?? '')
                    .toString()
                    .toLowerCase() ==
                idOrIndex.toLowerCase(),
          );
        } catch (_) {
          doc = null;
        }
      }
    }
    if (doc == null) {
      await _sendBotMessage('Shop not found in last results: $idOrIndex');
      return;
    }
    _selectedShopId = doc.id;
    _selectedShopName = (doc.data() as Map)['shopName']?.toString() ?? doc.id;
    await _sendBotMessage(
      'Selected shop: ${_selectedShopName} (id: ${_selectedShopId}). You can say "show barbers" or "show services".',
    );
  }

  Future<void> _listBarbers(String shopId) async {
    try {
      setState(() => _loading = true);
      final snap =
          await FirebaseFirestore.instance
              .collection('shop')
              .doc(shopId)
              .collection('barber')
              .get();
      _lastBarberDocs = snap.docs;
      if (snap.docs.isEmpty) {
        await _sendBotMessage('No barbers found for this shop.');
        return;
      }
      final buf = StringBuffer();
      for (var i = 0; i < snap.docs.length; i++) {
        final d = snap.docs[i];
        final name = (d.data() as Map)['name'] ?? d.id;
        buf.writeln('${i + 1}. ${name} (id: ${d.id})');
      }
      await _sendBotMessage(
        'Barbers for ${_selectedShopName ?? shopId}:\n${buf.toString()}\nSelect a barber with "select barber <id|index>".',
      );
    } catch (e) {
      await _sendBotMessage('Failed to list barbers: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectBarberByIdOrIndex(String idOrIndex) async {
    if (_lastBarberDocs == null) {
      await _sendBotMessage(
        'No barber list available. Say "show barbers" first.',
      );
      return;
    }
    QueryDocumentSnapshot<Object?>? doc;
    final idx = int.tryParse(idOrIndex);
    if (idx != null) {
      if (idx > 0 && idx <= _lastBarberDocs!.length)
        doc = _lastBarberDocs![idx - 1];
    }
    if (doc == null) {
      try {
        doc = _lastBarberDocs!.firstWhere((d) => d.id == idOrIndex);
      } catch (_) {
        try {
          doc = _lastBarberDocs!.firstWhere(
            (d) =>
                ((d.data() as Map)['name'] ?? '').toString().toLowerCase() ==
                idOrIndex.toLowerCase(),
          );
        } catch (_) {
          doc = null;
        }
      }
    }
    if (doc == null) {
      await _sendBotMessage('Barber not found in last results: $idOrIndex');
      return;
    }
    _selectedBarberId = doc.id;
    _selectedBarberName = (doc.data() as Map)['name']?.toString() ?? doc.id;
    await _sendBotMessage(
      'Selected barber: ${_selectedBarberName} (id: ${_selectedBarberId}). Now you can say "show services".',
    );
  }

  Future<void> _selectServiceByIdOrIndex(String idOrIndex) async {
    if (_lastServiceDocs == null) {
      await _sendBotMessage(
        'No service list available. Say "show services" first.',
      );
      return;
    }
    QueryDocumentSnapshot<Object?>? doc;
    final idx = int.tryParse(idOrIndex);
    if (idx != null) {
      if (idx > 0 && idx <= _lastServiceDocs!.length)
        doc = _lastServiceDocs![idx - 1];
    }
    if (doc == null) {
      try {
        doc = _lastServiceDocs!.firstWhere((d) => d.id == idOrIndex);
      } catch (_) {
        try {
          doc = _lastServiceDocs!.firstWhere(
            (d) =>
                ((d.data() as Map)['title'] ?? '').toString().toLowerCase() ==
                idOrIndex.toLowerCase(),
          );
        } catch (_) {
          doc = null;
        }
      }
    }
    if (doc == null) {
      await _sendBotMessage('Service not found in last results: $idOrIndex');
      return;
    }
    _selectedServiceId = doc.id;
    _selectedServiceData = Map<String, dynamic>.from(doc.data() as Map);
    await _sendBotMessage(
      'Selected service: ${_selectedServiceData?['title'] ?? _selectedServiceId} — ৳${_selectedServiceData?['price'] ?? 0}. Now choose a date with "choose date YYYY-MM-DD".',
    );
  }

  Future<void> _proceedToPaymentAndBooking() async {
    if (_selectedShopId == null ||
        _selectedServiceId == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      await _sendBotMessage(
        'Incomplete booking details. Make sure you selected shop, service, date and time.',
      );
      return;
    }
    final scheduled = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      int.parse(_selectedTime!.split(':')[0]),
      int.parse(_selectedTime!.split(':')[1]),
    );
    final serviceName = _selectedServiceData?['title'] ?? _selectedServiceId!;
    final amount =
        (_selectedServiceData?['price'] is num)
            ? (_selectedServiceData!['price'] as num).toDouble()
            : double.tryParse(
                  (_selectedServiceData?['price'] ?? '0').toString(),
                ) ??
                0.0;
    final desc = '$serviceName @ ${_selectedShopName ?? _selectedShopId}';

    // Navigate to checkout
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => PaymentCheckout(
              serviceName: serviceName.toString(),
              date: _selectedDate!,
              time: _selectedTime!,
              amount: amount,
              description: desc,
              shopId: _selectedShopId,
              customerId: widget.userId,
            ),
      ),
    );
    if (ok == true) {
      // payment succeeded, create booking
      await _createBooking(_selectedShopId!, _selectedServiceId!, scheduled);
      // reset selections
      _selectedShopId = null;
      _selectedServiceId = null;
      _selectedServiceData = null;
      _selectedDate = null;
      _selectedTime = null;
    } else {
      await _sendBotMessage(
        'Payment was cancelled or failed. Booking not created.',
      );
    }
  }

  Future<void> _createBooking(
    String shopId,
    String serviceId,
    DateTime scheduled,
  ) async {
    try {
      final shopRef = FirebaseFirestore.instance.collection('shop').doc(shopId);
      final serviceDoc =
          await shopRef.collection('services').doc(serviceId).get();
      if (!serviceDoc.exists) {
        await _sendBotMessage('Service not found at confirmation time.');
        return;
      }
      final bookingsRef = shopRef.collection('bookings');
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final conflictQuery =
            await bookingsRef
                .where('scheduledAt', isEqualTo: Timestamp.fromDate(scheduled))
                .get();
        if (conflictQuery.docs.isNotEmpty) throw 'slot_conflict';
        final bookingData = {
          'shopId': shopId,
          'serviceId': serviceId,
          'serviceTitle': serviceDoc.data()?['title'] ?? serviceId,
          'userId': widget.userId,
          'status': 'confirmed',
          'createdAt': FieldValue.serverTimestamp(),
          'scheduledAt': Timestamp.fromDate(scheduled),
          'price': serviceDoc.data()?['price'] ?? 0,
        };
        final newBookingRef = bookingsRef.doc();
        tx.set(newBookingRef, bookingData);
        final userBookingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('bookings')
            .doc(newBookingRef.id);
        tx.set(userBookingRef, bookingData);
        final chatbotBookingRef = FirebaseFirestore.instance
            .collection('booking_with_chatbot')
            .doc(newBookingRef.id);
        final chatbotData = Map<String, dynamic>.from(bookingData);
        chatbotData['bookedVia'] = 'chatbot';
        tx.set(chatbotBookingRef, chatbotData);
      });
      await _sendBotMessage(
        'Booking confirmed for ${serviceDoc.data()?['title'] ?? serviceId} at ${_formatTimestamp(scheduled)}',
      );
    } catch (e) {
      if (e == 'slot_conflict') {
        await _sendBotMessage('Slot conflict: selected time already booked.');
      } else {
        await _sendBotMessage('Failed to create booking: $e');
      }
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  String _formatTime(DateTime dt) {
    final d = dt.toLocal();
    return '${_two(d.hour)}:${_two(d.minute)}';
  }

  String _formatTimestamp(DateTime dt) {
    return '${_formatDate(dt)} ${_formatTime(dt)}';
  }

  Future<void> _fallbackReply(String text) async {
    print('[Chatbot] _fallbackReply handling: "$text"');
    final lower = text.toLowerCase().trim();

    // Basic conversational replies
    final greetings = [
      'hi',
      'hello',
      'hey',
      'hiya',
      'good morning',
      'good afternoon',
      'good evening',
    ];
    for (final g in greetings) {
      if (lower == g || lower.startsWith('$g ') || lower.contains(' $g ')) {
        _addBotMessage(
          'Hi there! 👋 I can help you find shops, list services, and make bookings. Try: "show shops" or "book <shopId> <serviceId> <YYYY-MM-DD> <HH:MM>".',
        );
        return;
      }
    }

    if (lower.contains('how are you') || lower.contains('how are u')) {
      _addBotMessage(
        'I\'m doing great — ready to help! What would you like to do?',
      );
      return;
    }

    if (lower.startsWith('thank') ||
        lower.contains(' thanks') ||
        lower.contains('thank you')) {
      _addBotMessage('You\'re welcome! Happy to help.');
      return;
    }

    if (lower.contains('what can you do') ||
        lower == 'help' ||
        lower == 'what can you do?') {
      _addBotMessage(
        'I can: show shops, list services for a shop, tell you how many barbers a shop has, and create bookings from chat. Example: "show services for shop123" or "book shop123 service456 2025-12-01 14:00".',
      );
      return;
    }

    // Preserve existing info-backed replies (how many barbers in a shop)
    if (lower.contains('how many') && lower.contains('barber')) {
      final parts = text.split(RegExp(r'\s+'));
      final idx = parts.indexWhere((p) => p.toLowerCase() == 'in');
      if (idx >= 0 && parts.length > idx + 1) {
        final shopId = parts[idx + 1];
        final shopDoc =
            await FirebaseFirestore.instance
                .collection('shop')
                .doc(shopId)
                .get();
        if (!shopDoc.exists) {
          _addBotMessage('Shop "$shopId" not found');
          return;
        }
        final barberSnap =
            await FirebaseFirestore.instance
                .collection('shop')
                .doc(shopId)
                .collection('barber')
                .get();
        _addBotMessage(
          'Shop ${shopDoc.data()?['shopName'] ?? shopId} has ${barberSnap.docs.length} barber(s).',
        );
        return;
      }
    }

    // Default help message
    _addBotMessage(
      'I can: show shops, show services for <shopId>, and book if you provide shopId, serviceId, date and time. Say "help" for examples.',
    );
  }

  Future<void> _handleShowShops() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('shop').get();
      if (snap.docs.isEmpty) {
        _addBotMessage('No shops found.');
        return;
      }
      _lastShopDocs = snap.docs;
      final buffer = StringBuffer();
      for (var i = 0; i < snap.docs.length; i++) {
        final d = snap.docs[i];
        final map = d.data();
        final shopName = (map['shopName'] ?? d.id).toString();
        final barberSnap =
            await FirebaseFirestore.instance
                .collection('shop')
                .doc(d.id)
                .collection('barber')
                .get();
        final servicesSnap =
            await FirebaseFirestore.instance
                .collection('shop')
                .doc(d.id)
                .collection('services')
                .get();
        buffer.writeln(
          '${i + 1}. ${shopName} (id: ${d.id}) — ${barberSnap.docs.length} barber(s), ${servicesSnap.docs.length} service(s)',
        );
      }
      _addBotMessage(
        'Shops:\n${buffer.toString()}\nSelect a shop with "select shop <id|index>".',
      );
    } catch (e) {
      _addBotMessage('Failed to load shops: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleShowServices(String shopId) async {
    setState(() => _loading = true);
    try {
      final shopDoc =
          await FirebaseFirestore.instance.collection('shop').doc(shopId).get();
      if (!shopDoc.exists) {
        _addBotMessage('Shop not found: $shopId');
        return;
      }
      final servicesSnap =
          await FirebaseFirestore.instance
              .collection('shop')
              .doc(shopId)
              .collection('services')
              .get();
      if (servicesSnap.docs.isEmpty) {
        _addBotMessage(
          'No services found for ${shopDoc.data()?['shopName'] ?? shopId}',
        );
        return;
      }
      _lastServiceDocs = servicesSnap.docs;
      final buffer = StringBuffer();
      buffer.writeln('Services for ${shopDoc.data()?['shopName'] ?? shopId}:');
      for (var i = 0; i < servicesSnap.docs.length; i++) {
        final s = servicesSnap.docs[i];
        final m = s.data();
        buffer.writeln(
          '${i + 1}. ${m['title'] ?? s.id} (id: ${s.id}) — ৳${(m['price'] ?? '0').toString()}',
        );
      }
      _addBotMessage(
        '${buffer.toString()}\nSelect a service with "select service <id|index>".',
      );
    } catch (e) {
      _addBotMessage('Failed to load services: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleDirectBooking(
    String shopId,
    String serviceId,
    String date,
    String time,
  ) async {
    try {
      final parts = date.split('-');
      if (parts.length != 3) throw 'Invalid date format';
      final y = int.parse(parts[0]);
      final mo = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      final tparts = time.split(':');
      if (tparts.length < 2) throw 'Invalid time format';
      final h = int.parse(tparts[0]);
      final min = int.parse(tparts[1]);
      final scheduled = DateTime(y, mo, d, h, min);

      final shopRef = FirebaseFirestore.instance.collection('shop').doc(shopId);
      final shopDoc = await shopRef.get();
      if (!shopDoc.exists) {
        _addBotMessage('Shop not found: $shopId');
        return;
      }
      final serviceDoc =
          await shopRef.collection('services').doc(serviceId).get();
      if (!serviceDoc.exists) {
        _addBotMessage('Service not found: $serviceId');
        return;
      }

      final bookingsRef = shopRef.collection('bookings');

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final conflictQuery =
            await bookingsRef
                .where('scheduledAt', isEqualTo: Timestamp.fromDate(scheduled))
                .get();
        if (conflictQuery.docs.isNotEmpty) {
          throw 'slot_conflict';
        }

        final bookingData = {
          'shopId': shopId,
          'serviceId': serviceId,
          'serviceTitle': serviceDoc.data()?['title'] ?? serviceId,
          'userId': widget.userId,
          'status': 'confirmed',
          'createdAt': FieldValue.serverTimestamp(),
          'scheduledAt': Timestamp.fromDate(scheduled),
          'price': serviceDoc.data()?['price'] ?? 0,
        };

        final newBookingRef = bookingsRef.doc();
        tx.set(newBookingRef, bookingData);
        final userBookingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('bookings')
            .doc(newBookingRef.id);
        tx.set(userBookingRef, bookingData);
      });

      _addBotMessage(
        'Booking confirmed for ${serviceDoc.data()?['title'] ?? serviceId} at ${scheduled.toLocal()}',
      );
    } catch (e) {
      if (e == 'slot_conflict') {
        _addBotMessage(
          'Selected slot is already booked. Please choose another time.',
        );
      } else {
        _addBotMessage('Booking failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await auth.signOutIfAny();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/auth');
                }
              } catch (_) {}
            },
          ),
        ],
      ),
      body: PremiumBackground(
        showBadge: false,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  return Row(
                    mainAxisAlignment:
                        m.fromUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!m.fromUser) ...[
                        CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.smart_toy, size: 18),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment:
                              m.fromUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: () {
                                  final isDark =
                                      Theme.of(context).brightness ==
                                      Brightness.dark;
                                  if (m.fromUser) {
                                    return isDark
                                        ? Colors.green.shade700
                                        : Colors.green.shade100;
                                  } else {
                                    return isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200;
                                  }
                                }(),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                m.text,
                                style: TextStyle(
                                  color: () {
                                    final isDark =
                                        Theme.of(context).brightness ==
                                        Brightness.dark;
                                    if (m.fromUser) {
                                      return isDark
                                          ? Colors.white
                                          : Colors.black87;
                                    } else {
                                      return isDark
                                          ? Colors.white70
                                          : Colors.black87;
                                    }
                                  }(),
                                ),
                              ),
                            ),
                            Text(
                              _formatTimestamp(m.timestamp),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (m.fromUser) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.person, size: 18),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_botTyping)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: const [
                    CircleAvatar(
                      radius: 12,
                      child: Icon(Icons.smart_toy, size: 14),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Assistant is typing...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _onSend,
                        decoration: const InputDecoration(
                          hintText: 'Ask assistant...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _onSend(_controller.text),
                      child: const Icon(Icons.send),
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
