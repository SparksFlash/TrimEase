import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BarberManagement extends StatefulWidget {
  final String shopId;
  const BarberManagement({Key? key, required this.shopId}) : super(key: key);

  @override
  State<BarberManagement> createState() => _BarberManagementState();
}

class _BarberManagementState extends State<BarberManagement> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showEditDialog(String docId, Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');
    final photo = data['photoUrl'] ?? '';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit barber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            if (photo != '') Image.network(photo, height: 80, width: 80),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final newName = nameCtrl.text.trim();
    final newEmail = emailCtrl.text.trim();

    final ref = FirebaseFirestore.instance
        .collection('shop')
        .doc(widget.shopId)
        .collection('barber');
    final docRef = ref.doc(docId);

    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('shop')
          .doc(widget.shopId)
          .get();
      final shopName = shopDoc.exists
          ? (shopDoc.data()?['shopName'] ?? '').toString()
          : '';
      if (newEmail.isNotEmpty && newEmail != (data['email'] ?? '')) {
        // create new doc using newEmail as id and delete old
        await ref.doc(newEmail).set({
          'name': newName,
          'email': newEmail,
          'photoUrl': data['photoUrl'] ?? '',
          'shopId': widget.shopId,
          'shopName': shopName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await docRef.delete();
      } else {
        await docRef.update({
          'name': newName,
          'updatedAt': FieldValue.serverTimestamp(),
          'shopName': shopName,
          'shopId': widget.shopId,
        });
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Barber updated')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  Future<void> _addBarber() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('shop')
        .doc(widget.shopId)
        .collection('barber');
    final shopDoc = await FirebaseFirestore.instance
        .collection('shop')
        .doc(widget.shopId)
        .get();
    final shopName = shopDoc.exists
        ? (shopDoc.data()?['shopName'] ?? '').toString()
        : '';
    await ref.doc(email).set({
      'name': name,
      'email': email,
      'shopId': widget.shopId,
      'shopName': shopName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _nameController.clear();
    _emailController.clear();
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Barber added')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barber Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _addBarber,
                      child: const Text('Add Barber (no auth)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Search box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search barbers by name or email',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shop')
                    .doc(widget.shopId)
                    .collection('barber')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, ss) {
                  if (ss.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (!ss.hasData || ss.data!.docs.isEmpty)
                    return const Center(child: Text('No barbers yet'));
                  final query = _searchController.text.trim().toLowerCase();
                  var docs = ss.data!.docs;
                  if (query.isNotEmpty) {
                    docs = docs.where((d) {
                      final m = d.data() as Map<String, dynamic>;
                      final name = (m['name'] ?? '').toString().toLowerCase();
                      final email = (m['email'] ?? '').toString().toLowerCase();
                      return name.contains(query) || email.contains(query);
                    }).toList();
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, idx) {
                      final d = docs[idx];
                      final m = d.data() as Map<String, dynamic>;
                      final name = (m['name'] ?? '').toString();
                      final email = (m['email'] ?? '').toString();
                      final photo = (m['photoUrl'] ?? '').toString();
                      return ListTile(
                        leading: photo.isNotEmpty
                            ? CircleAvatar(backgroundImage: NetworkImage(photo))
                            : CircleAvatar(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'B',
                                ),
                              ),
                        title: Text(name),
                        subtitle: Text(email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                await _showEditDialog(d.id, m);
                                setState(() {});
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Remove barber'),
                                    content: const Text('Remove this barber?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await d.reference.delete();
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Barber removed'),
                                      ),
                                    );
                                }
                              },
                            ),
                          ],
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
  }
}
