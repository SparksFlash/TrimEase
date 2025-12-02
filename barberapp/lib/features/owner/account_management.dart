import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AccountManagement extends StatefulWidget {
  final String shopId;
  const AccountManagement({Key? key, required this.shopId}) : super(key: key);

  @override
  State<AccountManagement> createState() => _AccountManagementState();
}

class _AccountManagementState extends State<AccountManagement> {
  final TextEditingController _accessoryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _accessoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addAccessory() async {
    final name = _accessoryController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (name.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('shop')
          .doc(widget.shopId)
          .collection('accessories')
          .add({
            'name': name,
            'amount': amount,
            'createdAt': FieldValue.serverTimestamp(),
          });
      _accessoryController.clear();
      _amountController.clear();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Accessory added')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Management')),
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
                      controller: _accessoryController,
                      decoration: const InputDecoration(labelText: 'Accessory'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (৳)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _addAccessory,
                      child: const Text('Add Accessory'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Accessories & Salaries',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shop')
                    .doc(widget.shopId)
                    .collection('accessories')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, ss) {
                  if (ss.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (!ss.hasData || ss.data!.docs.isEmpty)
                    return const Center(child: Text('No records yet'));
                  final docs = ss.data!.docs;
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, idx) {
                      final d = docs[idx];
                      final m = d.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(m['name'] ?? ''),
                        subtitle: Text('৳${(m['amount'] ?? 0).toString()}'),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async => await d.reference.delete(),
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
