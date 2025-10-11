import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'services_page.dart';
import 'booking_page.dart';
import 'my_bookings.dart';
import '../../payment/checkout.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({Key? key}) : super(key: key);

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  late final String _uid;

  @override
  void initState() {
    super.initState();
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    _uid = user?.uid ?? '';
  }

  String _formatPhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.length <= 3) return digits;
    if (digits.length <= 7)
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  }

  bool _isValidPhone(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^0-9+]'), '').replaceAll('+', '');
    return cleaned.length >= 8 && cleaned.length <= 15;
  }

  Future<void> _showEditDialog(
    BuildContext ctx,
    Map<String, dynamic> data,
  ) async {
    final phoneCtrl = TextEditingController(
      text: (data['phone'] ?? '').toString(),
    );
    final addressCtrl = TextEditingController(
      text: (data['address'] ?? '').toString(),
    );
    final nameCtrl = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );
    bool loading = false;

    final result = await showDialog<bool>(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // (Logout moved to AppBar) keep dialog focused on profile fields
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading
                                ? null
                                : () => Navigator.of(dctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: loading
                                ? null
                                : () async {
                                    final phone = phoneCtrl.text.trim();
                                    if (phone.isNotEmpty &&
                                        !_isValidPhone(phone)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Enter valid phone'),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => loading = true);
                                    try {
                                      final updates = <String, dynamic>{};
                                      if (nameCtrl.text.trim().isNotEmpty)
                                        updates['name'] = nameCtrl.text.trim();
                                      if (phone.isNotEmpty)
                                        updates['phone'] = _formatPhone(phone);
                                      if (addressCtrl.text.trim().isNotEmpty)
                                        updates['address'] = addressCtrl.text
                                            .trim();
                                      if (updates.isNotEmpty) {
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(_uid)
                                            .set(
                                              updates,
                                              SetOptions(merge: true),
                                            );
                                      }
                                      Navigator.of(dctx).pop(true);
                                    } catch (e) {
                                      setState(() => loading = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('Failed: $e')),
                                      );
                                    }
                                  },
                            child: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty)
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Dashboard')),
        body: const Center(child: Text('Not signed in')),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(c).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(c).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await fb_auth.FirebaseAuth.instance.signOut();
              // try to go to a named login route if available, otherwise pop until first route
              try {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (r) => false);
              } catch (_) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final name = (data['name'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final address = (data['address'] ?? '').toString();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Premium header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade400],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white24,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty ? name : email,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              email,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _showEditDialog(context, data),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contact & Address',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  phone.isNotEmpty
                                      ? phone
                                      : 'No phone provided',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _showEditDialog(context, data),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  address.isNotEmpty
                                      ? address
                                      : 'No address provided',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                // Premium feature grid (Services, Booking, My booking)
                // (Removed inline 'Your Bookings' list; user bookings are now in a dedicated page)

                // Premium feature grid (Services, Booking)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _openServices(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.content_cut,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Services',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Browse services & prices',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BookingPage(),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Booking',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Schedule an appointment',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyBookingsPage(),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.view_list,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'My booking',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'View and manage your bookings',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openServices(BuildContext context) async {
    // let user pick a shop, then open ServicesPage
    final shopsSnap = await FirebaseFirestore.instance.collection('shop').get();
    final shops = shopsSnap.docs
        .map(
          (d) => {
            'id': d.id,
            'name': (d.data()['shopName'] ?? d.id).toString(),
          },
        )
        .toList();
    String? selected;
    await showDialog<void>(
      context: context,
      builder: (dctx) {
        return AlertDialog(
          title: const Text('Select shop'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: shops.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final s = shops[i];
                return ListTile(
                  title: Text(s['name']!),
                  onTap: () {
                    selected = s['id'];
                    Navigator.of(dctx).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
    if (selected != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ServicesPage(shopId: selected!)),
      );
    }
  }

  // ignore: unused_element
  Future<void> _confirmAndPay(QueryDocumentSnapshot bookingDoc) async {
    final data = bookingDoc.data() as Map<String, dynamic>? ?? {};
    final shopId = (data['shopId'] ?? '').toString();
    final barberId = (data['barberId'] ?? '').toString();
    final serviceTitle = (data['serviceTitle'] ?? '').toString();
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

    // On successful payment: run a transaction to mark booking confirmed and mirror it under barber and shop payments
    final bookingRef = bookingDoc.reference;
    final centralRef = FirebaseFirestore.instance
        .collection('shop')
        .doc(shopId)
        .collection('bookings')
        .doc(bookingRef.id);
    final barberRef = FirebaseFirestore.instance
        .collection('shop')
        .doc(shopId)
        .collection('barber')
        .doc(barberId)
        .collection('bookings')
        .doc(bookingRef.id);
    final userId = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(centralRef);
        if (!snap.exists) throw Exception('Central booking not found');

        // update central booking
        tx.update(centralRef, {
          'status': 'confirmed',
          'booking_confirmed': true,
          'confirmedAt': FieldValue.serverTimestamp(),
        });

        // mirror under barber
        tx.set(barberRef, {
          ...snap.data() as Map<String, dynamic>,
          'status': 'confirmed',
          'booking_confirmed': true,
        });

        // write payment record under shop/<shopId>/payments/<paymentId>
        final payRef = FirebaseFirestore.instance
            .collection('shop')
            .doc(shopId)
            .collection('payments')
            .doc();
        tx.set(payRef, {
          'bookingId': bookingRef.id,
          'userId': userId,
          'barberId': barberId,
          'amount': amount > 0 ? amount : 500.0,
          'serviceTitle': serviceTitle,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // mirror for user
        if (userId.isNotEmpty) {
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('bookings')
              .doc(bookingRef.id);
          tx.set(userRef, {
            ...snap.data() as Map<String, dynamic>,
            'status': 'confirmed',
            'booking_confirmed': true,
          });
        }
      });

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful and booking confirmed'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to finalize booking: $e')),
        );
    }
  }
}
