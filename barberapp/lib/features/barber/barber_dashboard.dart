import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../auth/provider/auth_provider.dart';
import '../../utils/theme_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/cloudinary_service.dart';

class BarberDashboard extends StatefulWidget {
  const BarberDashboard({Key? key}) : super(key: key);

  @override
  State<BarberDashboard> createState() => _BarberDashboardState();
}

class _BarberDashboardState extends State<BarberDashboard>
    with SingleTickerProviderStateMixin {
  late final fb_auth.User? _user;
  List<Map<String, String>> _shops = [];
  String? _selectedShopId;
  bool _linkingLoading = false;
  int _currentIndex = 0;
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    try {
      if (firebase_core.Firebase.apps.isEmpty) {
        _user = null;
      } else {
        _user = fb_auth.FirebaseAuth.instance.currentUser;
      }
    } catch (_) {
      _user = null;
    }
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findBarberDoc() async {
    if (_user == null) return null;
    final user = _user;
    final uid = user.uid;
    final email = user.email ?? '';
    final fire = FirebaseFirestore.instance;

    // Try to find by uid first (set when barber signed up), otherwise by email
    try {
      // helper to try queries across collectionGroup names
      Future<DocumentSnapshot<Map<String, dynamic>>?> tryGroups(
        List<String> groups,
      ) async {
        for (final g in groups) {
          try {
            final q1 =
                await fire
                    .collectionGroup(g)
                    .where('uid', isEqualTo: uid)
                    .limit(1)
                    .get();
            if (q1.docs.isNotEmpty)
              return q1.docs.first as DocumentSnapshot<Map<String, dynamic>>;

            if (email.isNotEmpty) {
              final q2 =
                  await fire
                      .collectionGroup(g)
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();
              if (q2.docs.isNotEmpty)
                return q2.docs.first as DocumentSnapshot<Map<String, dynamic>>;

              // try matching document id to email or uid (some older entries used email as doc id)
              final q3 =
                  await fire
                      .collectionGroup(g)
                      .where(FieldPath.documentId, isEqualTo: email)
                      .limit(1)
                      .get();
              if (q3.docs.isNotEmpty)
                return q3.docs.first as DocumentSnapshot<Map<String, dynamic>>;
              final q4 =
                  await fire
                      .collectionGroup(g)
                      .where(FieldPath.documentId, isEqualTo: uid)
                      .limit(1)
                      .get();
              if (q4.docs.isNotEmpty)
                return q4.docs.first as DocumentSnapshot<Map<String, dynamic>>;
            }
          } catch (_) {
            // ignore per-group errors and try the next
          }
        }
        return null;
      }

      final groupsToTry = ['barber', 'barbers'];
      final found = await tryGroups(groupsToTry);
      if (found != null) return found;

      // Fallback: iterate shop docs and check subcollection barber/barbers
      try {
        final shops = await fire.collection('shop').get();
        for (final s in shops.docs) {
          for (final sub in ['barber', 'barbers']) {
            try {
              final ref = fire.collection('shop').doc(s.id).collection(sub);
              // direct doc id
              if (email.isNotEmpty) {
                final d1 = await ref.doc(email).get();
                if (d1.exists) return d1;
              }
              final d2 = await ref.doc(uid).get();
              if (d2.exists) return d2;
              // query by email/uid field
              final q =
                  await ref.where('email', isEqualTo: email).limit(1).get();
              if (q.docs.isNotEmpty)
                return q.docs.first as DocumentSnapshot<Map<String, dynamic>>;
              final q2 = await ref.where('uid', isEqualTo: uid).limit(1).get();
              if (q2.docs.isNotEmpty)
                return q2.docs.first as DocumentSnapshot<Map<String, dynamic>>;
            } catch (_) {}
          }
        }
      } catch (_) {}
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    try {
      _bgController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barber Dashboard'),
        leading: BackButton(
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              try {
                navigator.pushReplacementNamed('/auth');
              } catch (_) {
                navigator.pushNamed('/auth');
              }
            }
          },
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder:
                (ctx, theme, _) => IconButton(
                  icon: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => theme.toggle(),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder:
                    (c) => AlertDialog(
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

              // show blocking progress
              showDialog(
                context: context,
                barrierDismissible: false,
                builder:
                    (ctx) => const Center(child: CircularProgressIndicator()),
              );

              try {
                await auth.signOutIfAny();
              } catch (e) {
                debugPrint('Sign out failed: $e');
              }

              try {
                Navigator.of(context).pop();
              } catch (_) {}

              if (mounted) {
                try {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/auth', (r) => false);
                } catch (_) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
        future: _findBarberDoc(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data == null) {
            // Show a helpful linking UI so the barber can self-link to a shop
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_off,
                      size: 56,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Barber profile not found',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your account is not linked to any shop yet.',
                      style: TextStyle(color: isDark ? Colors.white70 : null),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Select your shop from the list below to link your account.',
                      style: TextStyle(color: isDark ? Colors.white60 : null),
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<Map<String, String>>(
                      displayStringForOption:
                          (opt) => opt['name'] ?? opt['id']!,
                      optionsBuilder: (TextEditingValue txt) {
                        if (txt.text.isEmpty)
                          return const Iterable<Map<String, String>>.empty();
                        return _shops.where(
                          (s) => s['name']!.toLowerCase().contains(
                            txt.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (selection) {
                        _selectedShopId = selection['id'];
                      },
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          cursorColor: isDark ? Colors.white70 : Colors.black54,
                          decoration: InputDecoration(
                            hintText: 'Type shop name',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                            prefixIcon: const Icon(
                              Icons.storefront,
                              color: Colors.white70,
                            ),
                            filled: true,
                            fillColor:
                                isDark
                                    ? (focusNode.hasFocus
                                        ? Colors.grey.shade900
                                        : Colors.black)
                                    : (focusNode.hasFocus
                                        ? Colors.white
                                        : Colors.grey.shade100),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.white54,
                                width: 1.2,
                              ),
                            ),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        final list = options.toList();
                        return Material(
                          color: isDark ? Colors.black : Colors.white,
                          elevation: 8,
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child:
                                list.isEmpty
                                    ? Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'No shops match',
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? Colors.white54
                                                  : Colors.black54,
                                        ),
                                      ),
                                    )
                                    : ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: list.length,
                                      separatorBuilder:
                                          (_, __) => Divider(
                                            height: 1,
                                            color:
                                                isDark
                                                    ? Colors.white12
                                                    : const Color.fromARGB(
                                                      255,
                                                      139,
                                                      5,
                                                      5,
                                                    ),
                                          ),
                                      itemBuilder: (ctx, i) {
                                        final opt = list[i];
                                        final selected =
                                            _selectedShopId == opt['id'];
                                        return InkWell(
                                          onTap: () => onSelected(opt),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  selected
                                                      ? (isDark
                                                          ? Colors
                                                              .indigo
                                                              .shade600
                                                          : Colors
                                                              .indigo
                                                              .shade700)
                                                      : (isDark
                                                          ? Colors.black
                                                          : Colors.white),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    opt['name'] ?? opt['id']!,
                                                    style: TextStyle(
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                              : Colors.black87,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                if (selected)
                                                  const Icon(
                                                    Icons.check,
                                                    color: Colors.white70,
                                                    size: 18,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _linkingLoading
                                ? null
                                : () async {
                                  if (_selectedShopId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please select a shop'),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => _linkingLoading = true);
                                  try {
                                    final shopDoc =
                                        await FirebaseFirestore.instance
                                            .collection('shop')
                                            .doc(_selectedShopId)
                                            .get();
                                    final shopName =
                                        shopDoc.exists
                                            ? (shopDoc.data()?['shopName'] ??
                                                    '')
                                                .toString()
                                            : '';
                                    final uid = _user?.uid ?? '';
                                    final email = _user?.email ?? '';
                                    final barberRef = FirebaseFirestore.instance
                                        .collection('shop')
                                        .doc(_selectedShopId)
                                        .collection('barber')
                                        .doc(email.isNotEmpty ? email : uid);
                                    await barberRef.set({
                                      'uid': uid,
                                      'email': email,
                                      'shopId': _selectedShopId,
                                      'shopName': shopName,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Linked to shop successfully',
                                        ),
                                      ),
                                    );
                                    // refresh by rebuilding widget (future will re-run)
                                    setState(() => _linkingLoading = false);
                                  } catch (e) {
                                    setState(() => _linkingLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to link: $e'),
                                      ),
                                    );
                                  }
                                },
                        child:
                            _linkingLoading
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Link to selected shop'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        // fetch shops if not loaded
                        if (_shops.isEmpty) {
                          try {
                            final s =
                                await FirebaseFirestore.instance
                                    .collection('shop')
                                    .get();
                            final list =
                                s.docs
                                    .map(
                                      (d) => {
                                        'id': d.id,
                                        'name':
                                            (d.data()['shopName'] ?? d.id)
                                                .toString(),
                                      },
                                    )
                                    .toList();
                            if (mounted)
                              setState(
                                () =>
                                    _shops = List<Map<String, String>>.from(
                                      list,
                                    ),
                              );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to load shops: $e'),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'Refresh shop list',
                        style: TextStyle(color: isDark ? Colors.white70 : null),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final doc = snap.data!;
          final data = doc.data() ?? <String, dynamic>{};
          final barberName = (data['name'] ?? '').toString();
          final barberEmail = (data['email'] ?? '').toString();
          final photo = (data['photoUrl'] ?? '').toString();

          // derive shop id from doc reference: shop/{shopId}/barber/{id}
          final shopRef = doc.reference.parent.parent;
          final shopId = shopRef?.id ?? '';

          // Tab views based on `_currentIndex`
          Widget homeView = Stack(
            children: [
              Positioned.fill(
                child: _PremiumBackground(animation: _bgController),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedBuilder(
                  animation: _bgController,
                  builder: (c, _) {
                    final dy =
                        math.sin(_bgController.value * 2 * math.pi) * 4.0;
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Icon(
                        Icons.workspace_premium,
                        color: Colors.amber.shade400,
                        size: 26,
                      ),
                    );
                  },
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Premium Header (barber info)
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF217D5A), Color(0xFF49B07E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 18,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar with subtle border (tappable to edit profile)
                              GestureDetector(
                                onTap:
                                    () => _showEditBarberDialog(
                                      doc.reference,
                                      data,
                                    ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 42,
                                    backgroundColor: Colors.white24,
                                    backgroundImage:
                                        photo.isNotEmpty
                                            ? NetworkImage(photo)
                                                as ImageProvider
                                            : null,
                                    child:
                                        photo.isEmpty
                                            ? Text(
                                              barberName.isNotEmpty
                                                  ? barberName[0].toUpperCase()
                                                  : 'B',
                                              style: const TextStyle(
                                                fontSize: 28,
                                                color: Colors.white,
                                              ),
                                            )
                                            : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      barberName.isNotEmpty
                                          ? barberName
                                          : barberEmail,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FutureBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>?
                                    >(
                                      future:
                                          shopId.isNotEmpty
                                              ? FirebaseFirestore.instance
                                                  .collection('shop')
                                                  .doc(shopId)
                                                  .get()
                                              : Future.value(null),
                                      builder: (ctx, s2) {
                                        final shopName =
                                            (s2.data?.data()?['shopName'] ?? '')
                                                .toString();
                                        return Row(
                                          children: [
                                            if (shopName.isNotEmpty)
                                              Text(
                                                shopName,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            Text(
                                              barberEmail,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Barber',
                                  style: TextStyle(
                                    color: Colors.indigo.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Small stat chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Today',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '0 bookings',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Earnings',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '৳0',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Quick action tiles
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: const Text('Today'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                  builder: (c) {
                                    final monthKey =
                                        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Monthly Earnings',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          StreamBuilder<
                                            DocumentSnapshot<
                                              Map<String, dynamic>
                                            >
                                          >(
                                            stream:
                                                (shopId.isNotEmpty)
                                                    ? FirebaseFirestore.instance
                                                        .collection('shop')
                                                        .doc(shopId)
                                                        .collection('barber')
                                                        .doc(doc.id)
                                                        .collection('salary')
                                                        .doc(monthKey)
                                                        .snapshots()
                                                    : const Stream.empty(),
                                            builder: (ctx2, snap2) {
                                              double monthSalary = 0.0;
                                              if (snap2.hasData &&
                                                  snap2.data!.exists) {
                                                final mm = snap2.data!.data();
                                                final a = mm?['amount'];
                                                if (a is num)
                                                  monthSalary = a.toDouble();
                                                else if (a is String)
                                                  monthSalary =
                                                      double.tryParse(a) ?? 0.0;
                                              }
                                              return Row(
                                                children: [
                                                  const Icon(
                                                    Icons.attach_money,
                                                    color: Colors.green,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'This month ($monthKey): ',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  Text(
                                                    '৳${monthSalary.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'History',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 240,
                                            child: StreamBuilder<
                                              QuerySnapshot<
                                                Map<String, dynamic>
                                              >
                                            >(
                                              stream:
                                                  (shopId.isNotEmpty)
                                                      ? FirebaseFirestore
                                                          .instance
                                                          .collection('shop')
                                                          .doc(shopId)
                                                          .collection('barber')
                                                          .doc(doc.id)
                                                          .collection('salary')
                                                          .orderBy(
                                                            'updatedAt',
                                                            descending: true,
                                                          )
                                                          .limit(12)
                                                          .snapshots()
                                                      : const Stream.empty(),
                                              builder: (ctx3, snap3) {
                                                if (snap3.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  );
                                                }
                                                final entries =
                                                    snap3.data?.docs ?? [];
                                                if (entries.isEmpty) {
                                                  return const Center(
                                                    child: Text(
                                                      'No salary records yet',
                                                    ),
                                                  );
                                                }
                                                return ListView.separated(
                                                  itemCount: entries.length,
                                                  separatorBuilder:
                                                      (_, __) => const Divider(
                                                        height: 1,
                                                      ),
                                                  itemBuilder: (ctx4, i) {
                                                    final m = entries[i].data();
                                                    final month =
                                                        (m['month'] ?? '')
                                                            .toString();
                                                    final amountRaw =
                                                        m['amount'];
                                                    double amt = 0.0;
                                                    if (amountRaw is num)
                                                      amt =
                                                          amountRaw.toDouble();
                                                    else if (amountRaw
                                                        is String)
                                                      amt =
                                                          double.tryParse(
                                                            amountRaw,
                                                          ) ??
                                                          0.0;
                                                    final ts = m['updatedAt'];
                                                    DateTime? dt;
                                                    if (ts is Timestamp)
                                                      dt = ts.toDate();
                                                    return ListTile(
                                                      leading: const Icon(
                                                        Icons.workspace_premium,
                                                        color: Colors.amber,
                                                      ),
                                                      title: Text(
                                                        month.isNotEmpty
                                                            ? month
                                                            : 'Month',
                                                      ),
                                                      subtitle:
                                                          dt != null
                                                              ? Text(
                                                                dt
                                                                    .toLocal()
                                                                    .toString()
                                                                    .split(
                                                                      ' ',
                                                                    )[0],
                                                              )
                                                              : null,
                                                      trailing: Text(
                                                        '৳${amt.toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              icon: const Icon(Icons.monetization_on_outlined),
                              label: const Text('Earnings'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Overview cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _OverviewCard(
                              title: 'Bookings',
                              value: '0',
                              subtitle: 'Today',
                              color: const Color(0xFF217D5A),
                              icon: Icons.event_available,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream:
                                  (shopId.isNotEmpty)
                                      ? FirebaseFirestore.instance
                                          .collection('shop')
                                          .doc(shopId)
                                          .collection('barber')
                                          .doc(doc.id)
                                          .collection('salary')
                                          .doc(
                                            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
                                          )
                                          .snapshots()
                                      : const Stream.empty(),
                              builder: (ctx, salarySnap) {
                                double monthSalary = 0.0;
                                if (salarySnap.hasData &&
                                    salarySnap.data!.exists) {
                                  final mm = salarySnap.data!.data();
                                  final a = mm?['amount'];
                                  if (a is num)
                                    monthSalary = a.toDouble();
                                  else if (a is String)
                                    monthSalary = double.tryParse(a) ?? 0.0;
                                }
                                return _OverviewCard(
                                  title: 'Earnings',
                                  value: '৳${monthSalary.toStringAsFixed(0)}',
                                  subtitle: 'This month',
                                  color: const Color(0xFF49B07E),
                                  icon: Icons.attach_money,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Actions grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.grey.shade900
                                  : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 8),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _FeatureTile(
                              icon: Icons.person,
                              title: 'Profile',
                              subtitle: 'Edit profile',
                              onTap: () {
                                _showEditBarberDialog(doc.reference, data);
                              },
                            ),
                            _FeatureTile(
                              icon: Icons.checklist_rtl,
                              title: 'Bookings',
                              subtitle: 'View bookings',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Bookings feature coming soon',
                                    ),
                                  ),
                                );
                              },
                            ),
                            _FeatureTile(
                              icon: Icons.history,
                              title: 'History',
                              subtitle: 'Past jobs',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'History feature coming soon',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Small footer
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Bottom actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Update Profile / Photo'),
                            onPressed:
                                () =>
                                    _showEditBarberDialog(doc.reference, data),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );

          Widget bookingsView = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      'Live Bookings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('shop')
                              .doc(shopId)
                              .collection('barber')
                              .doc(doc.id)
                              .collection('bookings')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                      builder: (ctx, s) {
                        if (s.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!s.hasData ||
                            s.data == null ||
                            s.data!.docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('No bookings yet'),
                            ),
                          );
                        }
                        final docs = s.data!.docs;
                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final b = docs[i].data();
                            final customerName =
                                (b['customerName'] ?? '').toString();
                            final serviceName =
                                (b['serviceName'] ?? '').toString();
                            final status =
                                (b['status'] ?? 'pending').toString();
                            final timeStr =
                                (b['time'] ?? b['createdAt'] ?? '').toString();
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isDark
                                        ? Colors.green.shade900
                                        : Colors.green.shade100,
                                child: Icon(
                                  Icons.event_available,
                                  color:
                                      isDark
                                          ? Colors.greenAccent
                                          : Colors.green,
                                ),
                              ),
                              title: Text(
                                customerName.isNotEmpty
                                    ? customerName
                                    : 'Customer',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (serviceName.isNotEmpty) Text(serviceName),
                                  if (timeStr.isNotEmpty)
                                    Text(
                                      'Time: $timeStr',
                                      style: TextStyle(
                                        color:
                                            isDark
                                                ? Colors.white60
                                                : Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      status == 'completed'
                                          ? (isDark
                                              ? Colors.green.shade900
                                                  .withOpacity(0.25)
                                              : Colors.green.shade50)
                                          : status == 'cancelled'
                                          ? (isDark
                                              ? Colors.red.shade900.withOpacity(
                                                0.25,
                                              )
                                              : Colors.red.shade50)
                                          : (isDark
                                              ? Colors.orange.shade900
                                                  .withOpacity(0.25)
                                              : Colors.orange.shade50),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        status == 'completed'
                                            ? (isDark
                                                ? Colors.greenAccent
                                                : Colors.green)
                                            : status == 'cancelled'
                                            ? (isDark
                                                ? Colors.redAccent
                                                : Colors.red)
                                            : (isDark
                                                ? Colors.orangeAccent
                                                : Colors.orange),
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color:
                                        status == 'completed'
                                            ? (isDark
                                                ? Colors.greenAccent
                                                : Colors.green.shade800)
                                            : status == 'cancelled'
                                            ? (isDark
                                                ? Colors.redAccent
                                                : Colors.red.shade800)
                                            : (isDark
                                                ? Colors.orangeAccent
                                                : Colors.orange.shade800),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );

          Widget profileView = Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Edit your profile'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Update Profile / Photo'),
                    onPressed: () => _showEditBarberDialog(doc.reference, data),
                  ),
                ],
              ),
            ),
          );

          switch (_currentIndex) {
            case 1:
              return bookingsView;
            case 2:
              return profileView;
            case 0:
            default:
              return homeView;
          }
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _showEditBarberDialog(
    DocumentReference docRef,
    Map<String, dynamic> data,
  ) async {
    final nameCtrl = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );
    final email = (data['email'] ?? '').toString();
    String currentPhoto = (data['photoUrl'] ?? '').toString();
    String currentPhotoDeleteToken =
        (data['photoDeleteToken'] ?? '').toString();
    bool loading = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            String photoLocal = currentPhoto;
            String photoDeleteTokenLocal = currentPhotoDeleteToken;
            bool uploading = false;
            double uploadProgress = 0.0;

            Future<void> _pickAndUpload() async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1600,
                  maxHeight: 1600,
                  imageQuality: 80,
                );
                if (picked == null) return;
                setState(() {
                  uploading = true;
                  uploadProgress = 0.0;
                });
                final resp = await CloudinaryService.uploadXFile(
                  picked,
                  folder: 'barber_photos',
                  onProgress: (sent, total) {
                    if (total > 0) {
                      if (!ctx.mounted) return;
                      setState(() => uploadProgress = sent / total);
                    }
                  },
                );
                photoLocal = (resp['secure_url'] ?? '').toString();
                photoDeleteTokenLocal = (resp['delete_token'] ?? '').toString();
                if (!ctx.mounted) return;
                setState(() {
                  uploading = false;
                  uploadProgress = 0.0;
                });
              } catch (e) {
                if (ctx.mounted) {
                  setState(() {
                    uploading = false;
                    uploadProgress = 0.0;
                  });
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Image upload failed: $e')),
                );
              }
            }

            Future<void> _removePhoto() async {
              if (photoDeleteTokenLocal.isNotEmpty) {
                setState(() => uploading = true);
                try {
                  final ok = await CloudinaryService.deleteByToken(
                    photoDeleteTokenLocal,
                  );
                  if (ok) {
                    photoLocal = '';
                    photoDeleteTokenLocal = '';
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to remove photo')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Remove failed: $e')));
                }
                setState(() => uploading = false);
              } else {
                photoLocal = '';
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Photo preview + controls
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage:
                              (photoLocal.isNotEmpty)
                                  ? NetworkImage(photoLocal) as ImageProvider
                                  : null,
                          child:
                              photoLocal.isEmpty
                                  ? Text(
                                    nameCtrl.text.isNotEmpty
                                        ? nameCtrl.text[0].toUpperCase()
                                        : 'B',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton.icon(
                                onPressed:
                                    uploading
                                        ? null
                                        : () async {
                                          await _pickAndUpload();
                                        },
                                icon:
                                    uploading
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Icons.photo_camera),
                                label: const Text('Change photo'),
                              ),
                              if (photoLocal.isNotEmpty)
                                TextButton.icon(
                                  onPressed:
                                      uploading
                                          ? null
                                          : () async {
                                            await _removePhoto();
                                          },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  label: const Text(
                                    'Remove photo',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              if (uploading)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8.0,
                                    right: 8.0,
                                  ),
                                  child: LinearProgressIndicator(
                                    value:
                                        uploadProgress > 0
                                            ? uploadProgress
                                            : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Edit profile',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: email),
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Email (read-only)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                loading
                                    ? null
                                    : () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                loading
                                    ? null
                                    : () async {
                                      final newName = nameCtrl.text.trim();
                                      if (newName.isEmpty) return;
                                      setState(() => loading = true);
                                      try {
                                        final updates = <String, dynamic>{
                                          'name': newName,
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        };

                                        // Persist photo fields if present or removed
                                        if (photoLocal.isNotEmpty) {
                                          updates['photoUrl'] = photoLocal;
                                          if (photoDeleteTokenLocal.isNotEmpty)
                                            updates['photoDeleteToken'] =
                                                photoDeleteTokenLocal;
                                        } else {
                                          if (currentPhoto.isNotEmpty) {
                                            updates['photoUrl'] =
                                                FieldValue.delete();
                                            updates['photoDeleteToken'] =
                                                FieldValue.delete();
                                          }
                                        }

                                        await docRef.update(updates);
                                        Navigator.of(ctx).pop(true);
                                      } catch (e) {
                                        setState(() => loading = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Failed: $e')),
                                        );
                                      }
                                    },
                            child:
                                loading
                                    ? const SizedBox(
                                      height: 16,
                                      width: 16,
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

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      setState(() {});
    }
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color baseColor;
    if (icon == Icons.person) {
      baseColor = const Color(0xFF217D5A);
    } else if (icon == Icons.checklist_rtl) {
      baseColor = Colors.blue.shade600;
    } else if (icon == Icons.history) {
      baseColor = Colors.purple.shade600;
    } else {
      baseColor = Colors.teal.shade600;
    }
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: baseColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumBackground extends StatelessWidget {
  final Animation<double> animation;
  const _PremiumBackground({Key? key, required this.animation})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _BlobPainter(progress: animation.value, isDark: isDark),
        );
      },
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  _BlobPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bg =
        Paint()
          ..shader = (isDark
                  ? const LinearGradient(
                    colors: [Color(0xFF0F1D1A), Color(0xFF1F3A30)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : const LinearGradient(
                    colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ))
              .createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final blob1 =
        Paint()
          ..color = const Color(0xFF49B07E).withOpacity(isDark ? 0.20 : 0.12);
    final blob2 =
        Paint()
          ..color = const Color(0xFF217D5A).withOpacity(isDark ? 0.18 : 0.10);
    final blob3 =
        Paint()
          ..color = const Color(0xFF81C784).withOpacity(isDark ? 0.18 : 0.10);

    // simple drifting positions
    final w = size.width;
    final h = size.height;
    final x1 = (w * (0.2 + 0.1 * math.sin(progress * 2 * math.pi)));
    final y1 = (h * (0.15 + 0.05 * math.cos(progress * 2 * math.pi)));
    final x2 = (w * (0.75 + 0.08 * math.cos(progress * 2 * math.pi)));
    final y2 = (h * (0.30 + 0.06 * math.sin(progress * 2 * math.pi)));
    final x3 = (w * (0.5 + 0.12 * math.sin(progress * 2 * math.pi)));
    final y3 = (h * (0.75 + 0.08 * math.cos(progress * 2 * math.pi)));

    canvas.drawCircle(Offset(x1, y1), w * 0.35, blob1);
    canvas.drawCircle(Offset(x2, y2), w * 0.30, blob2);
    canvas.drawCircle(Offset(x3, y3), w * 0.40, blob3);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
