import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/provider/auth_provider.dart';

class BarberDashboard extends StatefulWidget {
  const BarberDashboard({Key? key}) : super(key: key);

  @override
  State<BarberDashboard> createState() => _BarberDashboardState();
}

class _BarberDashboardState extends State<BarberDashboard> {
  late final fb_auth.User? _user;
  List<Map<String, String>> _shops = [];
  String? _selectedShopId;
  bool _linkingLoading = false;

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
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barber Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOutIfAny();
              if (mounted) Navigator.of(context).pushReplacementNamed('/auth');
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
                    const Icon(Icons.person_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'Barber profile not found',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text('Your account is not linked to any shop yet.'),
                    const SizedBox(height: 18),
                    const Text(
                      'Select your shop from the list below to link your account.',
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
                        controller.text = '';
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Select your shop',
                            prefixIcon: Icon(Icons.storefront),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Material(
                          elevation: 4,
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children:
                                options.map((opt) {
                                  return ListTile(
                                    title: Text(opt['name'] ?? opt['id']!),
                                    onTap: () => onSelected(opt),
                                  );
                                }).toList(),
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
                      child: const Text('Refresh shop list'),
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

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Premium Header (barber info)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade800, Colors.indigo.shade500],
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
                                () =>
                                    _showEditBarberDialog(doc.reference, data),
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
                                        ? NetworkImage(photo) as ImageProvider
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                          onPressed: () {},
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
                          color: Colors.orange.shade50,
                          icon: Icons.event_available,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OverviewCard(
                          title: 'Earnings',
                          value: '৳0',
                          subtitle: 'This month',
                          color: Colors.green.shade50,
                          icon: Icons.attach_money,
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
                      color: Colors.grey.shade50,
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
                          onTap: () {},
                        ),
                        _FeatureTile(
                          icon: Icons.checklist_rtl,
                          title: 'Bookings',
                          subtitle: 'View bookings',
                          onTap: () {},
                        ),
                        _FeatureTile(
                          icon: Icons.history,
                          title: 'History',
                          subtitle: 'Past jobs',
                          onTap: () {},
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
              ],
            ),
          );
        },
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
    bool loading = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                        await docRef.update({
                                          'name': newName,
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        });
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(icon, color: Colors.black87),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: Colors.indigo.shade100,
                child: Icon(icon, color: Colors.indigo.shade800),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
