import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ServiceManagement extends StatefulWidget {
  final String shopId;
  const ServiceManagement({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ServiceManagement> createState() => _ServiceManagementState();
}

class _ServiceManagementState extends State<ServiceManagement> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _addService() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final duration = int.tryParse(_durationController.text.trim()) ?? 0;
    setState(() => _adding = true);
    try {
      await FirebaseFirestore.instance
          .collection('shop')
          .doc(widget.shopId)
          .collection('services')
          .add({
            'name': name,
            'price': price,
            'duration': duration,
            'createdAt': FieldValue.serverTimestamp(),
          });
      _nameController.clear();
      _priceController.clear();
      _durationController.clear();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Service added')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Management')),
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
                      decoration: const InputDecoration(
                        labelText: 'Service name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Price (৳)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _durationController,
                            decoration: const InputDecoration(
                              labelText: 'Duration (min)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _adding ? null : _addService,
                      child: _adding
                          ? const CircularProgressIndicator()
                          : const Text('Add Service'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shop')
                    .doc(widget.shopId)
                    .collection('services')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, ss) {
                  if (ss.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (!ss.hasData || ss.data!.docs.isEmpty)
                    return const Center(child: Text('No services yet'));
                  final docs = ss.data!.docs;
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, idx) {
                      final d = docs[idx];
                      final m = d.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(m['name'] ?? ''),
                        subtitle: Text(
                          '৳${(m['price'] ?? 0).toString()} • ${m['duration'] ?? 0} min',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete service'),
                                content: Text('Delete "${m['name'] ?? ''}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await d.reference.delete();
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Service removed'),
                                  ),
                                );
                            }
                          },
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
