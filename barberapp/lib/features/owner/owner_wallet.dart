import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OwnerWallet extends StatelessWidget {
  final String shopId;
  const OwnerWallet({Key? key, required this.shopId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('shop')
        .doc(shopId)
        .collection('payments')
        .orderBy('createdAt', descending: true);
    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No payments yet'));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final amount =
                (d['amount'] is num)
                    ? (d['amount'] as num).toDouble()
                    : double.tryParse((d['amount'] ?? '').toString()) ?? 0.0;
            final title = (d['serviceTitle'] ?? 'Payment').toString();
            final dt = (d['createdAt'] as Timestamp?)?.toDate();
            return ListTile(
              leading: CircleAvatar(child: Text('৳')),
              title: Text(title),
              subtitle:
                  dt != null
                      ? Text(dt.toLocal().toString().split(' ')[0])
                      : null,
              trailing: Text(
                '৳${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            );
          },
        );
      },
    );
  }
}
