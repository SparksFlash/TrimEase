import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ServicesPage extends StatelessWidget {
  final String shopId;
  const ServicesPage({Key? key, required this.shopId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shop')
            .doc(shopId)
            .collection('services')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty)
            return const Center(child: Text('No services yet'));
          final docs = snap.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final m = docs[i].data() as Map<String, dynamic>;
              final title = (m['title'] ?? '').toString();
              final price = (m['price'] ?? '').toString();
              final desc = (m['description'] ?? '').toString();
              return ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: desc.isNotEmpty ? Text(desc) : null,
                trailing: Text(price.isNotEmpty ? '৳$price' : ''),
              );
            },
          );
        },
      ),
    );
  }
}
