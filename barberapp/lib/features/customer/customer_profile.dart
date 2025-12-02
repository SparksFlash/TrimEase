import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/cloudinary_service.dart';
import '../../widgets/premium_background.dart';

class CustomerProfile extends StatefulWidget {
  final String userId;
  const CustomerProfile({Key? key, required this.userId}) : super(key: key);

  @override
  State<CustomerProfile> createState() => _CustomerProfileState();
}

class _CustomerProfileState extends State<CustomerProfile> {
  bool _uploading = false;

  Future<void> _pickAndUpload(Function(String, String) onUploaded) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _uploading = true);
      final resp = await CloudinaryService.uploadXFile(
        picked,
        folder: 'user_photos',
      );
      final url = (resp['secure_url'] ?? '').toString();
      final token = (resp['delete_token'] ?? '').toString();
      onUploaded(url, token);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController(
      text: (data['phone'] ?? '').toString(),
    );
    final addressCtrl = TextEditingController(
      text: (data['address'] ?? '').toString(),
    );
    String photo = (data['photoUrl'] ?? '').toString();
    String photoToken = (data['photoDeleteToken'] ?? '').toString();
    bool loading = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, setState) {
            bool uploading = false;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor:
                              Theme.of(dctx).brightness == Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                          backgroundImage:
                              (photo.isNotEmpty)
                                  ? NetworkImage(photo) as ImageProvider
                                  : null,
                          child:
                              photo.isEmpty
                                  ? Text(
                                    (nameCtrl.text.isNotEmpty
                                        ? nameCtrl.text[0].toUpperCase()
                                        : 'C'),
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
                              TextButton(
                                onPressed: () async {
                                  if (uploading) return;
                                  setState(() => uploading = true);
                                  await _pickAndUpload((u, t) {
                                    photo = u;
                                    photoToken = t;
                                  });
                                  setState(() => uploading = false);
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_camera),
                                    SizedBox(width: 8),
                                    Text('Change photo'),
                                  ],
                                ),
                              ),
                              if (photo.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () async {
                                    if (uploading) return;
                                    // remove locally
                                    photo = '';
                                    photoToken = '';
                                    setState(() {});
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
                                      setState(() => loading = true);
                                      try {
                                        final updates = <String, dynamic>{};
                                        if (nameCtrl.text.trim().isNotEmpty)
                                          updates['name'] =
                                              nameCtrl.text.trim();
                                        if (phoneCtrl.text.trim().isNotEmpty)
                                          updates['phone'] =
                                              phoneCtrl.text.trim();
                                        if (addressCtrl.text.trim().isNotEmpty)
                                          updates['address'] =
                                              addressCtrl.text.trim();
                                        if (photo.isNotEmpty) {
                                          updates['photoUrl'] = photo;
                                          if (photoToken.isNotEmpty)
                                            updates['photoDeleteToken'] =
                                                photoToken;
                                        } else {
                                          // remove photo keys if previously existed
                                          if ((data['photoUrl'] ?? '')
                                              .toString()
                                              .isNotEmpty) {
                                            updates['photoUrl'] =
                                                FieldValue.delete();
                                            updates['photoDeleteToken'] =
                                                FieldValue.delete();
                                          }
                                        }
                                        if (updates.isNotEmpty) {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(widget.userId)
                                              .set(
                                                updates,
                                                SetOptions(merge: true),
                                              );
                                        }
                                        Navigator.of(dctx).pop(true);
                                      } catch (e) {
                                        if (mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Save failed: $e'),
                                            ),
                                          );
                                      } finally {
                                        if (mounted)
                                          setState(() => loading = false);
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

    if (result == true && mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = (data['name'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final phone = (data['phone'] ?? '').toString();
        final address = (data['address'] ?? '').toString();
        final photo = (data['photoUrl'] ?? '').toString();

        return PremiumBackground(
          showBadge: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF217D5A),
                        const Color(0xFF49B07E),
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
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white10
                                    : Colors.white24,
                            backgroundImage:
                                photo.isNotEmpty
                                    ? NetworkImage(photo) as ImageProvider
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
                          Positioned(
                            right: -6,
                            bottom: -6,
                            child: IconButton(
                              onPressed:
                                  _uploading
                                      ? null
                                      : () async {
                                        await _pickAndUpload((u, t) async {
                                          if (u.isNotEmpty) {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(widget.userId)
                                                .set({
                                                  'photoUrl': u,
                                                  'photoDeleteToken': t,
                                                }, SetOptions(merge: true));
                                          }
                                        });
                                      },
                              icon:
                                  _uploading
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                      ),
                            ),
                          ),
                        ],
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
                        onPressed: () => _showEditDialog(data),
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
                                onPressed: () => _showEditDialog(data),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
