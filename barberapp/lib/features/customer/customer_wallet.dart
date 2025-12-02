import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/premium_background.dart';
import '../../utils/local_store.dart';

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
        if (snap.connectionState == ConnectionState.waiting) {
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
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty)
          return const Center(child: Text('No transactions yet'));
        return PremiumBackground(
          showBadge: false,
          child: ListView.separated(
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
              LocalStore.instance.setLastSyncNow();
              return ListTile(
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : null,
                  ),
                ),
                subtitle: Text(
                  status.isNotEmpty ? status : '---',
                  style: TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black54,
                  ),
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '৳${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.amberAccent
                                : Colors.green.shade800,
                      ),
                    ),
                    if (dt != null)
                      Text(
                        dt.toLocal().toString().split(' ')[0],
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white54
                                  : Colors.black54,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
