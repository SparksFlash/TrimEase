import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/premium_background.dart';
import '../../utils/local_store.dart';

class ServicesPage extends StatelessWidget {
  final String shopId;
  const ServicesPage({Key? key, required this.shopId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: PremiumBackground(
        showBadge: false,
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('shop')
                  .doc(shopId)
                  .collection('services')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              // show cached hint if we saved any last sync
              final cached = LocalStore.instance.lastSyncString;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text('Cached: $cached'),
                ],
              );
            }
            if (!snap.hasData || snap.data!.docs.isEmpty)
              return const Center(child: Text('No services yet'));
            final docs = snap.data!.docs;
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final m = docs[i].data() as Map<String, dynamic>;
                final title = (m['title'] ?? m['name'] ?? '').toString();
                final price = (m['price'] ?? '').toString();
                final desc = (m['description'] ?? '').toString();
                final photo = (m['photoUrl'] ?? '').toString();
                LocalStore.instance.setLastSyncNow();
                return ListTile(
                  leading:
                      photo.isNotEmpty
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              photo,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder:
                                  (ctx, err, stack) => Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image),
                                  ),
                            ),
                          )
                          : CircleAvatar(
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade800
                                    : null,
                            child: const Icon(Icons.design_services),
                          ),
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
      ),
    );
  }
}
