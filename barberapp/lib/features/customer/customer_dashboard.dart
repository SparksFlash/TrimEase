import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services_page.dart';
import 'booking_page.dart';
import 'my_bookings.dart';
import '../../payment/checkout.dart';
import '../../utils/theme_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/cloudinary_service.dart';
import 'customer_profile.dart';
import 'customer_wallet.dart';
import 'customer_chatbot.dart';
import '../pricing/pricing_service.dart';
import '../../utils/local_store.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({Key? key}) : super(key: key);

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard>
    with SingleTickerProviderStateMixin {
  late final String _uid;
  // bottom nav selected index
  int _selectedIndex = 0;
  static const _navPrefKey = 'customer_nav_index';
  late final AnimationController _premiumAnim;

  @override
  void initState() {
    super.initState();
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
    _premiumAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat(reverse: true);
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
  void dispose() {
    try {
      _premiumAnim.dispose();
    } catch (_) {}
    super.dispose();
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
    String currentPhoto = (data['photoUrl'] ?? '').toString();
    String currentPhotoDeleteToken =
        (data['photoDeleteToken'] ?? '').toString();

    final result = await showDialog<bool>(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, setState) {
            String photoLocal = currentPhoto;
            String photoDeleteTokenLocal = currentPhotoDeleteToken;
            bool uploading = false;

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
                if (!dctx.mounted) return;
                setState(() => uploading = true);
                final resp = await CloudinaryService.uploadXFile(
                  picked,
                  folder: 'user_photos',
                );
                photoLocal = (resp['secure_url'] ?? '').toString();
                photoDeleteTokenLocal = (resp['delete_token'] ?? '').toString();
                if (!dctx.mounted) return;
                setState(() => uploading = false);
              } catch (e) {
                if (dctx.mounted) setState(() => uploading = false);
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
                    // (Logout moved to AppBar) keep dialog focused on profile fields
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
                                        : 'C',
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
                            ],
                          ),
                        ),
                      ],
                    ),
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
                            onPressed:
                                loading
                                    ? null
                                    : () => Navigator.of(dctx).pop(false),
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
                                          updates['name'] =
                                              nameCtrl.text.trim();
                                        if (phone.isNotEmpty)
                                          updates['phone'] = _formatPhone(
                                            phone,
                                          );
                                        if (addressCtrl.text.trim().isNotEmpty)
                                          updates['address'] =
                                              addressCtrl.text.trim();
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
                            child:
                                loading
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
          Consumer<ThemeProvider>(
            builder:
                (ctx, theme, _) => IconButton(
                  tooltip: 'Toggle theme',
                  icon: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => theme.toggle(),
                ),
          ),
          IconButton(
            tooltip: 'Logout',
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
                await fb_auth.FirebaseAuth.instance.signOut();
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder:
            (child, anim) => FadeTransition(opacity: anim, child: child),
        child:
            _selectedIndex == 0
                ? StreamBuilder<DocumentSnapshot>(
                  key: const ValueKey('home'),
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(_uid)
                          .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting)
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              LocalStore.instance.ownerShopName.isNotEmpty
                                  ? 'Loading ${LocalStore.instance.ownerShopName}…'
                                  : 'Loading…',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    final data =
                        snap.data?.data() as Map<String, dynamic>? ?? {};
                    final name = (data['name'] ?? '').toString();
                    final email = (data['email'] ?? '').toString();
                    final phone = (data['phone'] ?? '').toString();
                    final address = (data['address'] ?? '').toString();
                    final photo = (data['photoUrl'] ?? '').toString();
                    // Cache basic customer info time
                    LocalStore.instance.setLastSyncNow();

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: _CustomerPremiumBackground(
                            animation: _premiumAnim,
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 12,
                          child: AnimatedBuilder(
                            animation: _premiumAnim,
                            builder: (c, _) {
                              final bob =
                                  math.sin(_premiumAnim.value * 2 * math.pi) *
                                  5;
                              return Transform.translate(
                                offset: Offset(0, bob),
                                child: Icon(
                                  Icons.workspace_premium,
                                  color: Colors.amber.shade400,
                                  size: 28,
                                ),
                              );
                            },
                          ),
                        ),
                        SingleChildScrollView(
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
                                    colors: [
                                      Color(0xFF217D5A),
                                      Color(0xFF49B07E),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
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
                                      backgroundImage:
                                          photo.isNotEmpty
                                              ? NetworkImage(photo)
                                              : null,
                                      child:
                                          photo.isEmpty
                                              ? Text(
                                                name.isNotEmpty
                                                    ? name[0].toUpperCase()
                                                    : 'C',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 28,
                                                ),
                                              )
                                              : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed:
                                          () => _showEditDialog(context, data),
                                      child: const Text('Edit'),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 18,
                                              ),
                                              onPressed:
                                                  () => _showEditDialog(
                                                    context,
                                                    data,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 18,
                                            ),
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
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _openServices(context),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).cardColor,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.05,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Builder(
                                                builder: (ctx) {
                                                  final isDark =
                                                      Theme.of(
                                                        ctx,
                                                      ).brightness ==
                                                      Brightness.dark;
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          isDark
                                                              ? Colors.blue
                                                                  .withOpacity(
                                                                    0.25,
                                                                  )
                                                              : Colors
                                                                  .blue
                                                                  .shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.content_cut,
                                                      color:
                                                          isDark
                                                              ? Colors
                                                                  .blue
                                                                  .shade200
                                                              : Colors.blue,
                                                    ),
                                                  );
                                                },
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
                                              Builder(
                                                builder: (ctx) {
                                                  final isDark =
                                                      Theme.of(
                                                        ctx,
                                                      ).brightness ==
                                                      Brightness.dark;
                                                  return Text(
                                                    'Browse services & prices',
                                                    style: TextStyle(
                                                      color:
                                                          isDark
                                                              ? Colors.white70
                                                              : Colors.black54,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap:
                                            () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => const BookingPage(),
                                              ),
                                            ),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).cardColor,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.05,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Builder(
                                                builder: (ctx) {
                                                  final isDark =
                                                      Theme.of(
                                                        ctx,
                                                      ).brightness ==
                                                      Brightness.dark;
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          isDark
                                                              ? Colors.green
                                                                  .withOpacity(
                                                                    0.25,
                                                                  )
                                                              : Colors
                                                                  .green
                                                                  .shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.calendar_today,
                                                      color:
                                                          isDark
                                                              ? Colors
                                                                  .green
                                                                  .shade200
                                                              : Colors.green,
                                                    ),
                                                  );
                                                },
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
                                              Builder(
                                                builder: (ctx) {
                                                  final isDark =
                                                      Theme.of(
                                                        ctx,
                                                      ).brightness ==
                                                      Brightness.dark;
                                                  return Text(
                                                    'Schedule an appointment',
                                                    style: TextStyle(
                                                      color:
                                                          isDark
                                                              ? Colors.white70
                                                              : Colors.black54,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap:
                                            () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder:
                                                    (_) =>
                                                        const MyBookingsPage(),
                                              ),
                                            ),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).cardColor,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.05,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Builder(
                                                builder: (ctx) {
                                                  final isDark =
                                                      Theme.of(
                                                        ctx,
                                                      ).brightness ==
                                                      Brightness.dark;
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          isDark
                                                              ? Colors.purple
                                                                  .withOpacity(
                                                                    0.28,
                                                                  )
                                                              : Colors
                                                                  .purple
                                                                  .shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.view_list,
                                                      color:
                                                          isDark
                                                              ? Colors
                                                                  .purple
                                                                  .shade200
                                                              : Colors.purple,
                                                    ),
                                                  );
                                                },
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
                                              Builder(
                                                builder: (ctx) {
                                                  final isDark =
                                                      Theme.of(
                                                        ctx,
                                                      ).brightness ==
                                                      Brightness.dark;
                                                  return Text(
                                                    'View and manage your bookings',
                                                    style: TextStyle(
                                                      color:
                                                          isDark
                                                              ? Colors.white70
                                                              : Colors.black54,
                                                    ),
                                                  );
                                                },
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
                        ),
                      ],
                    );
                  },
                )
                : _selectedIndex == 1
                ? CustomerProfile(userId: _uid)
                : CustomerWallet(userId: _uid),
      ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CustomerChatbot(userId: _uid)),
          );
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Assistant'),
      ),
    );
  }

  Future<void> _openServices(BuildContext context) async {
    // let user pick a shop, then open ServicesPage
    final shopsSnap = await FirebaseFirestore.instance.collection('shop').get();
    final shops =
        shopsSnap.docs
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
    final amount =
        (data['price'] is num)
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

    // Dynamic pricing calculation before payment
    final basePrice = amount > 0 ? amount : 500.0;
    final pricing = await PricingService.getDynamicPrice(
      shopId: shopId,
      serviceTitle: serviceTitle,
      scheduledAt: scheduledAt,
      basePrice: basePrice,
    );

    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => PaymentCheckout(
              serviceName: serviceTitle,
              date: scheduledAt,
              time: scheduledAt
                  .toLocal()
                  .toString()
                  .split(' ')[1]
                  .substring(0, 5),
              amount: pricing.finalPrice,
              description: desc,
              shopId: shopId,
              customerId: fb_auth.FirebaseAuth.instance.currentUser?.uid,
              baseAmount: pricing.basePrice,
              pricingApplied: pricing.adjustmentType,
              percentApplied: pricing.percentApplied,
              demandScore: pricing.demandScore,
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

        // update central booking with pricing metadata
        tx.update(centralRef, {
          'status': 'confirmed',
          'booking_confirmed': true,
          'confirmedAt': FieldValue.serverTimestamp(),
          ...PricingService.pricingMetadata(pricing),
        });

        // mirror under barber
        tx.set(barberRef, {
          ...snap.data() as Map<String, dynamic>,
          'status': 'confirmed',
          'booking_confirmed': true,
          ...PricingService.pricingMetadata(pricing),
        });

        // write payment record under shop/<shopId>/payments/<paymentId>
        final payRef =
            FirebaseFirestore.instance
                .collection('shop')
                .doc(shopId)
                .collection('payments')
                .doc();
        tx.set(payRef, {
          'bookingId': bookingRef.id,
          'userId': userId,
          'barberId': barberId,
          'amount': pricing.finalPrice,
          'baseAmount': basePrice,
          'serviceTitle': serviceTitle,
          ...PricingService.pricingMetadata(pricing),
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
            ...PricingService.pricingMetadata(pricing),
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

// Premium animated background (lightweight, non-intrusive)
class _CustomerPremiumBackground extends StatelessWidget {
  final Animation<double> animation;
  const _CustomerPremiumBackground({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _CustomerBlobPainter(
            progress: animation.value,
            dark: Theme.of(context).brightness == Brightness.dark,
          ),
        );
      },
    );
  }
}

class _CustomerBlobPainter extends CustomPainter {
  final double progress;
  final bool dark;
  _CustomerBlobPainter({required this.progress, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    // Brighter premium gradient background
    final bgShader = LinearGradient(
      colors:
          dark
              ? [const Color(0xFF0C1114), const Color(0xFF1E262C)]
              : [const Color(0xFFFDFDFE), const Color(0xFFE4F2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = bgShader);

    // Soft radial highlight to lift center area
    final centerHighlight = RadialGradient(
      colors:
          dark
              ? [Colors.white.withOpacity(0.06), Colors.transparent]
              : [Colors.white.withOpacity(0.12), Colors.transparent],
      radius: 0.85,
    ).createShader(
      Rect.fromCircle(
        center: Offset(size.width * 0.55, size.height * 0.35),
        radius: size.shortestSide * 0.65,
      ),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = centerHighlight
        ..blendMode = BlendMode.plus,
    );

    // Animated drifting blobs
    final t = progress;
    final blobPaint = Paint()..style = PaintingStyle.fill;

    void drawBlob({
      required Offset center,
      required double r,
      required List<Color> colors,
      BlendMode mode = BlendMode.screen,
    }) {
      final rect = Rect.fromCircle(center: center, radius: r);
      blobPaint.shader = RadialGradient(
        colors: colors,
        stops: const [0.0, 1.0],
      ).createShader(rect);
      final path = Path();
      // Simple organic shape via sin modulation
      const int segments = 40;
      for (int i = 0; i <= segments; i++) {
        final ang = (i / segments) * math.pi * 2;
        final wobble = math.sin(ang * 3 + t * math.pi * 2) * (r * 0.12);
        final dx = center.dx + (r + wobble) * math.cos(ang);
        final dy = center.dy + (r + wobble) * math.sin(ang);
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }
      path.close();
      canvas.drawPath(path, blobPaint..blendMode = mode);
      // Optional subtle stroke to increase definition in light mode
      if (!dark) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withOpacity(0.15)
            ..blendMode = BlendMode.overlay,
        );
      }
    }

    final w = size.width;
    final h = size.height;

    drawBlob(
      center: Offset(w * 0.24 + math.sin(t * 2 * math.pi) * 26, h * 0.32),
      r: 120 + math.sin(t * 2 * math.pi) * 10,
      colors: [
        (dark ? Colors.cyanAccent : Colors.blueAccent).withOpacity(0.85),
        (dark ? Colors.teal : Colors.indigo).withOpacity(0.20),
      ],
    );
    drawBlob(
      center: Offset(
        w * 0.72 + math.cos(t * 2 * math.pi) * 30,
        h * 0.30 + math.sin(t * 2 * math.pi) * 18,
      ),
      r: 105 + math.cos(t * 2 * math.pi) * 8,
      colors: [
        (dark ? Colors.orangeAccent : Colors.pinkAccent).withOpacity(0.80),
        (dark ? Colors.deepOrange : Colors.purple).withOpacity(0.25),
      ],
    );
    drawBlob(
      center: Offset(
        w * 0.50 + math.sin(t * 2 * math.pi) * 22,
        h * 0.58 + math.cos(t * 2 * math.pi) * 24,
      ),
      r: 150 + math.sin(t * 2 * math.pi) * 14,
      colors: [
        (dark ? Colors.amberAccent : Colors.amber).withOpacity(0.75),
        (dark ? Colors.yellowAccent : Colors.orangeAccent).withOpacity(0.22),
      ],
    );

    // Soft wide glows for additional premium depth
    drawBlob(
      center: Offset(w * 0.35, h * 0.75),
      r: 180,
      colors: [
        (dark ? Colors.blueGrey : Colors.lightBlueAccent).withOpacity(0.18),
        Colors.transparent,
      ],
      mode: BlendMode.plus,
    );
    drawBlob(
      center: Offset(w * 0.8, h * 0.65),
      r: 160,
      colors: [
        (dark ? Colors.deepPurpleAccent : Colors.pinkAccent).withOpacity(0.15),
        Colors.transparent,
      ],
      mode: BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant _CustomerBlobPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}
