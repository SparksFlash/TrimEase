import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerWallet extends StatelessWidget {
  final String userId;
  const CustomerWallet({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bookings')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty)
          return const Center(child: Text('No transactions yet'));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final title = (d['serviceTitle'] ?? 'Service').toString();
            final amount =
                (d['price'] is num)
                    ? (d['price'] as num).toDouble()
                    : double.tryParse((d['price'] ?? '').toString()) ?? 0.0;
            final status = (d['status'] ?? '').toString();
            final dt = (d['createdAt'] as Timestamp?)?.toDate();
            return ListTile(
              title: Text(title),
              subtitle: Text(status.isNotEmpty ? status : '---'),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '৳${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (dt != null)
                    Text(
                      dt.toLocal().toString().split(' ')[0],
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
