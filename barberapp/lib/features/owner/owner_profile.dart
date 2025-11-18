import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/cloudinary_service.dart';

class OwnerProfile extends StatefulWidget {
  final String shopId;
  const OwnerProfile({Key? key, required this.shopId}) : super(key: key);

  @override
  State<OwnerProfile> createState() => _OwnerProfileState();
}

class _OwnerProfileState extends State<OwnerProfile> {
  bool _uploading = false;

  Future<void> _pickAndUpload(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final resp = await CloudinaryService.uploadXFile(picked, folder: 'shops');
      final secure = (resp['secure_url'] ?? '').toString();
      final deleteToken = (resp['delete_token'] ?? '').toString();
      if (secure.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('shop')
            .doc(widget.shopId)
            .update({
              'logoUrl': secure,
              if (deleteToken.isNotEmpty) 'logoDeleteToken': deleteToken,
            });
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Photo uploaded')));
      }
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
    final ownerCtrl = TextEditingController(
      text: (data['ownerName'] ?? '').toString(),
    );
    final contactCtrl = TextEditingController(
      text: (data['contact'] ?? '').toString(),
    );
    final addressCtrl = TextEditingController(
      text: (data['address'] ?? '').toString(),
    );
    bool saving = false;

    final res = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
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
                      Row(
                        children: [
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ownerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Owner name',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: contactCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contact',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  saving
                                      ? null
                                      : () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  saving
                                      ? null
                                      : () async {
                                        setState(() => saving = true);
                                        try {
                                          final updates = <String, dynamic>{
                                            'ownerName': ownerCtrl.text.trim(),
                                            'contact': contactCtrl.text.trim(),
                                            'address': addressCtrl.text.trim(),
                                          };
                                          await FirebaseFirestore.instance
                                              .collection('shop')
                                              .doc(widget.shopId)
                                              .update(updates);
                                          Navigator.of(ctx).pop(true);
                                        } catch (e) {
                                          setState(() => saving = false);
                                          if (mounted)
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Save failed: $e',
                                                ),
                                              ),
                                            );
                                        }
                                      },
                              child:
                                  saving
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
          ),
    );

    if (res == true && mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('shop')
              .doc(widget.shopId)
              .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || !snap.data!.exists)
          return const Center(child: Text('Shop not found'));
        final data = snap.data!.data() as Map<String, dynamic>;
        final shopName = (data['shopName'] ?? '').toString();
        final ownerName = (data['ownerName'] ?? '').toString();
        final contact = (data['contact'] ?? '').toString();
        final address = (data['address'] ?? '').toString();
        final logo = (data['logoUrl'] ?? '').toString();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade800, Colors.green.shade400],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.white24,
                      backgroundImage:
                          logo.isNotEmpty ? NetworkImage(logo) : null,
                      child:
                          logo.isEmpty
                              ? Text(
                                shopName.isNotEmpty
                                    ? shopName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                ),
                              )
                              : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName.isEmpty ? 'Unnamed Shop' : shopName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ownerName,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () => _pickAndUpload(context),
                          icon:
                              _uploading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
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
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text(
                              'Owner Information',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditDialog(data),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(
                            ownerName.isNotEmpty ? ownerName : 'No owner name',
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.phone),
                          title: Text(
                            contact.isNotEmpty ? contact : 'No contact',
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(
                            address.isNotEmpty ? address : 'No address',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
