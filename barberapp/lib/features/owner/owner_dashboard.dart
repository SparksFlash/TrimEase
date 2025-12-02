import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/premium_background.dart';
import '../../utils/theme_provider.dart';
import '../auth/provider/auth_provider.dart';
import 'account_management.dart';
import 'barber_management.dart';
import 'service_management.dart';
import 'owner_profile.dart';
import 'owner_wallet.dart';
import 'owner_salary.dart';
import '../../utils/local_store.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({Key? key}) : super(key: key);

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  late final String _uid;
  // Service inputs removed from inline dashboard; managed in ServiceManagement page
  int _selectedIndex = 0;
  static const _navPrefKey = 'owner_nav_index';

  @override
  void initState() {
    super.initState();
    // Avoid accessing FirebaseAuth.instance during construction; it can throw
    // on web when Firebase isn't initialized. Read lazily if available.
    try {
      if (firebase_core.Firebase.apps.isEmpty) {
        _uid = '';
      } else {
        final user = fb_auth.FirebaseAuth.instance.currentUser;
        _uid = user?.uid ?? '';
      }
    } catch (_) {
      _uid = '';
    }
    _loadNavIndex();
  }

  @override
  void dispose() {
    // nothing to dispose here related to services
    super.dispose();
  }

  Future<void> _loadNavIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt(_navPrefKey) ?? 0;
      if (mounted) setState(() => _selectedIndex = idx);
    } catch (_) {}
  }

  Future<void> _saveNavIndex(int idx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_navPrefKey, idx);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Owner Dashboard')),
        body: const Center(child: Text('No authenticated owner found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          Consumer<ThemeProvider>(
            builder:
                (ctx, theme, _) => IconButton(
                  tooltip: theme.isDark ? 'Light mode' : 'Dark mode',
                  icon: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => theme.toggle(),
                ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOutIfAny();
              if (mounted) Navigator.of(context).pushReplacementNamed('/auth');
            },
          ),
        ],
      ),
      body:
          _selectedIndex == 0
              ? StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('shop')
                        .doc(_uid)
                        .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    // Show a lightweight cached view if available
                    final cachedName = LocalStore.instance.ownerShopName;
                    return PremiumBackground(
                      showBadge: true,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              cachedName.isNotEmpty
                                  ? 'Loading $cachedName…'
                                  : 'Loading…',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (!snap.hasData || !snap.data!.exists) {
                    return const Center(child: Text('Shop data not found'));
                  }
                  final data = snap.data!.data() as Map<String, dynamic>;
                  final shopName = (data['shopName'] ?? 'My Shop').toString();
                  final ownerName = (data['ownerName'] ?? '').toString();
                  final contact = (data['contact'] ?? '').toString();
                  final address = (data['address'] ?? '').toString();
                  final logo = (data['logoUrl'] ?? '').toString();
                  final ownerPhoto = (data['ownerPhotoUrl'] ?? '').toString();

                  // Persist some quick cache values
                  LocalStore.instance.setOwnerShopName(shopName);
                  LocalStore.instance.setLastSyncNow();

                  return PremiumBackground(
                    showBadge: true,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade700,
                                  Colors.green.shade400,
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.white24,
                                  backgroundImage:
                                      (ownerPhoto.isNotEmpty
                                          ? NetworkImage(ownerPhoto)
                                          : (logo.isNotEmpty
                                              ? NetworkImage(logo)
                                              : null)),
                                  child:
                                      (ownerPhoto.isEmpty && logo.isEmpty)
                                          ? Text(
                                            shopName.isNotEmpty
                                                ? shopName[0].toUpperCase()
                                                : 'S',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              color: Colors.white,
                                            ),
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shopName,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (ownerName.isNotEmpty)
                                            Text(
                                              ownerName,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          const Spacer(),
                                          Chip(
                                            label: Text(
                                              'Owner',
                                              style: TextStyle(
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Details Card
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Shop Details',
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
                                            contact.isNotEmpty
                                                ? contact
                                                : 'No contact provided',
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => _showEditShopDialog(
                                                context,
                                                contact,
                                                address,
                                              ),
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

                          const SizedBox(height: 16),

                          // Action tiles
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.people),
                                    label: const Text('Barbers'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.calendar_today),
                                    label: const Text('Bookings'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Premium feature grid
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.black54
                                            : Colors.black12,
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Border.all(
                                          color: Colors.white.withOpacity(0.08),
                                        )
                                        : null,
                              ),
                              padding: const EdgeInsets.all(12),
                              child: GridView.count(
                                shrinkWrap: true,
                                crossAxisCount: 3,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  _FeatureTile(
                                    icon: Icons.account_balance_wallet,
                                    title: 'Account',
                                    subtitle: 'Accessories & Salaries',
                                    onTap:
                                        () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => AccountManagement(
                                                  shopId: _uid,
                                                ),
                                          ),
                                        ),
                                  ),
                                  _FeatureTile(
                                    icon: Icons.payments,
                                    title: 'Salary',
                                    subtitle: 'Pay monthly',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) =>
                                                  OwnerSalaryPage(shopId: _uid),
                                        ),
                                      );
                                    },
                                  ),
                                  _FeatureTile(
                                    icon: Icons.person_search,
                                    title: 'Barbers',
                                    subtitle: 'Manage barbers',
                                    onTap:
                                        () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => BarberManagement(
                                                  shopId: _uid,
                                                ),
                                          ),
                                        ),
                                  ),
                                  _FeatureTile(
                                    icon: Icons.design_services,
                                    title: 'Services',
                                    subtitle: 'Add / Remove',
                                    onTap:
                                        () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => ServiceManagement(
                                                  shopId: _uid,
                                                ),
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Overview
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
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
                    ),
                  );
                },
              )
              : _selectedIndex == 1
              ? OwnerProfile(shopId: _uid)
              : OwnerWallet(shopId: _uid),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          setState(() {
            _selectedIndex = i;
          });
          _saveNavIndex(i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
        ],
      ),
    );
  }
  // Profile and Wallet moved to separate pages: see owner_profile.dart and owner_wallet.dart

  // Profile and Wallet moved to separate pages: see owner_profile.dart and owner_wallet.dart

  Future<void> _showEditShopDialog(
    BuildContext context,
    String currentContact,
    String currentAddress,
  ) async {
    // Prefill controllers; also fetch existing shopName/ownerName if available
    final shopNameCtrl = TextEditingController();
    final ownerNameCtrl = TextEditingController();
    final contactCtrl = TextEditingController(text: currentContact);
    final addressCtrl = TextEditingController(text: currentAddress);

    try {
      final doc =
          await FirebaseFirestore.instance.collection('shop').doc(_uid).get();
      if (doc.exists) {
        final map = doc.data();
        if (map != null) {
          shopNameCtrl.text = (map['shopName'] ?? '').toString();
          ownerNameCtrl.text = (map['ownerName'] ?? '').toString();
        }
      }
    } catch (_) {}

    bool loading = false;

    String _formatPhoneLive(String input) {
      final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
      // Simple grouping for readability
      if (digits.startsWith('+')) {
        final rest = digits.substring(1);
        if (rest.length <= 3) return digits;
        return '+${rest.substring(0, 3)} ${rest.substring(3)}';
      }
      if (digits.length <= 3) return digits;
      if (digits.length <= 7)
        return '${digits.substring(0, 3)} ${digits.substring(3)}';
      return '${digits.substring(0, 3)} ${digits.substring(3, 7)} ${digits.substring(7)}';
    }

    bool isValidPhone(String s) {
      final digits = s.replaceAll(RegExp(r'[^0-9+]'), '');
      final cleaned = digits.replaceAll('+', '');
      return cleaned.length >= 8 && cleaned.length <= 15;
    }

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade700,
                            Colors.green.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white24,
                            child: Text(
                              shopNameCtrl.text.isNotEmpty
                                  ? shopNameCtrl.text[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Shop',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Update shop, owner and contact info',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: shopNameCtrl,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.store),
                              labelText: 'Shop name',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) {
                              if (v == null) return null;
                              if (v.trim().isEmpty) return null;
                              if (v.trim().length < 2) return 'Too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: ownerNameCtrl,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person),
                              labelText: 'Owner name',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) {
                              if (v == null) return null;
                              if (v.trim().isEmpty) return null;
                              if (v.trim().length < 2) return 'Too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: contactCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone),
                              labelText: 'Contact (phone)',
                              helperText: 'Include country code if available',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged:
                                (v) => setState(() {
                                  // live format preview (no direct text overwrite to avoid caret jumps)
                                  _formatPhoneLive(v);
                                }),
                            validator: (v) {
                              if (v == null) return null;
                              if (v.trim().isEmpty) return null;
                              if (!isValidPhone(v))
                                return 'Enter a valid phone number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: addressCtrl,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.location_on),
                              labelText: 'Address',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            maxLines: 2,
                            validator: (v) {
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                loading
                                    ? null
                                    : () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false))
                                        return;
                                      final newShop = shopNameCtrl.text.trim();
                                      final newOwner =
                                          ownerNameCtrl.text.trim();
                                      final newContact =
                                          contactCtrl.text.trim();
                                      final newAddress =
                                          addressCtrl.text.trim();

                                      if (newShop.isEmpty &&
                                          newOwner.isEmpty &&
                                          newContact.isEmpty &&
                                          newAddress.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Enter at least one field to update',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (newContact.isNotEmpty &&
                                          !isValidPhone(newContact)) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Enter a valid phone number',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() => loading = true);
                                      try {
                                        final updates = <String, dynamic>{};
                                        if (newShop.isNotEmpty)
                                          updates['shopName'] = newShop;
                                        if (newOwner.isNotEmpty)
                                          updates['ownerName'] = newOwner;
                                        if (newContact.isNotEmpty)
                                          updates['contact'] = _formatPhoneLive(
                                            newContact,
                                          );
                                        if (newAddress.isNotEmpty)
                                          updates['address'] = newAddress;

                                        if (updates.isNotEmpty) {
                                          await FirebaseFirestore.instance
                                              .collection('shop')
                                              .doc(_uid)
                                              .update(updates);
                                          await FirebaseFirestore.instance
                                              .collection('shop')
                                              .doc(_uid)
                                              .collection('activity')
                                              .add({
                                                'type': 'update_details',
                                                'changes': updates,
                                                'updatedBy': _uid,
                                                'timestamp':
                                                    FieldValue.serverTimestamp(),
                                              });
                                        }

                                        Navigator.of(ctx).pop(true);
                                      } catch (e) {
                                        setState(() => loading = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to save: $e'),
                                          ),
                                        );
                                      }
                                    },
                            child:
                                loading
                                    ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text('Save changes'),
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

    if (result == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shop details updated')));
    }
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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withOpacity(0.06) : theme.cardColor;
    final primary = theme.colorScheme.primary;
    return Material(
      color: baseColor,
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
                backgroundColor: primary.withOpacity(isDark ? 0.25 : 0.15),
                child: Icon(icon, color: isDark ? Colors.white : primary),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withOpacity(0.95) : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color:
                      isDark
                          ? Colors.white.withOpacity(0.65)
                          : Colors.grey.shade600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
