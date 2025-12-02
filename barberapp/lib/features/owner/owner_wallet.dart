import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/premium_background.dart';
import '../../utils/local_store.dart';
import '../../payment/payment_helper.dart';

class OwnerWallet extends StatefulWidget {
  final String shopId;
  const OwnerWallet({Key? key, required this.shopId}) : super(key: key);

  @override
  State<OwnerWallet> createState() => _OwnerWalletState();
}

class _OwnerWalletState extends State<OwnerWallet> {
  bool _processingRefund = false;
  String? _refundTargetId;

  Future<void> _attemptRefund(String docId, double originalAmount) async {
    if (_processingRefund) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Refund Payment'),
            content: Text(
              'Refund ৳${originalAmount.toStringAsFixed(2)} and adjust wallet balance? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Refund'),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    setState(() {
      _processingRefund = true;
      _refundTargetId = docId;
    });
    try {
      final ok = await processRefund(
        shopId: widget.shopId,
        paymentHistoryId: docId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Refund successful' : 'Refund failed')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Refund error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingRefund = false;
          _refundTargetId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopDocStream =
        FirebaseFirestore.instance
            .collection('shop')
            .doc(widget.shopId)
            .snapshots();
    final historyStream =
        FirebaseFirestore.instance
            .collection('shop')
            .doc(widget.shopId)
            .collection('payment_history')
            .orderBy('createdAt', descending: true)
            .snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: shopDocStream,
      builder: (context, shopSnap) {
        final walletBalance = () {
          if (shopSnap.hasData && shopSnap.data!.exists) {
            final data = shopSnap.data!.data() as Map<String, dynamic>?;
            final bal = data?['walletBalance'];
            if (bal is num) return bal.toDouble();
            return double.tryParse(bal?.toString() ?? '') ?? 0.0;
          }
          return 0.0;
        }();

        return PremiumBackground(
          showBadge: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Owner Wallet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '৳${walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final cached = LocalStore.instance.lastSyncString;
                          final waiting =
                              shopSnap.connectionState ==
                              ConnectionState.waiting;
                          final text =
                              waiting ? 'Updated (cached: $cached)' : 'Updated';
                          return Text(
                            text,
                            style: TextStyle(color: Colors.grey.shade600),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: historyStream,
                  builder: (context, histSnap) {
                    if (histSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = histSnap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No payment history yet'),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = docs[i].data() as Map<String, dynamic>;
                        final rawAmount =
                            (m['amount'] is num)
                                ? (m['amount'] as num).toDouble()
                                : double.tryParse(m['amount'].toString()) ??
                                    0.0;
                        final serviceName =
                            (m['serviceName'] ?? 'Service').toString();
                        final customerId = (m['customerId'] ?? '').toString();
                        final status = (m['status'] ?? 'success').toString();
                        final gateway = (m['gateway'] ?? '').toString();
                        final ts = m['createdAt'];
                        DateTime? dt;
                        if (ts is Timestamp) dt = ts.toDate();
                        final isRefund =
                            (m['type'] ?? '') == 'refund' || rawAmount < 0;
                        final displayAmount = rawAmount;
                        final amountWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isRefund
                                  ? '-৳${displayAmount.abs().toStringAsFixed(2)}'
                                  : '৳${displayAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isRefund ? Colors.red.shade700 : null,
                              ),
                            ),
                            Text(
                              status == 'refunded' ? 'refunded' : status,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    isRefund
                                        ? Colors.red.shade700
                                        : (status == 'success'
                                            ? Colors.green.shade700
                                            : Colors.orange.shade700),
                              ),
                            ),
                          ],
                        );
                        Widget trailing;
                        if (!isRefund && status == 'success') {
                          trailing = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              amountWidget,
                              const SizedBox(width: 8),
                              _processingRefund && _refundTargetId == docs[i].id
                                  ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : IconButton(
                                    tooltip: 'Refund',
                                    icon: const Icon(
                                      Icons.undo,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed:
                                        () => _attemptRefund(
                                          docs[i].id,
                                          rawAmount.abs(),
                                        ),
                                  ),
                            ],
                          );
                        } else {
                          trailing = amountWidget;
                        }
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isRefund
                                    ? Colors.red.shade50
                                    : Colors.green.shade50,
                            child: Text(
                              isRefund ? '↺' : '৳',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(serviceName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (customerId.isNotEmpty)
                                Text(
                                  'Customer: $customerId',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              if (gateway.isNotEmpty)
                                Text(
                                  'Via: $gateway',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              if (dt != null)
                                Text(
                                  dt.toLocal().toString().split(' ')[0],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                          trailing: trailing,
                          onLongPress:
                              (!isRefund && status == 'success')
                                  ? () => _attemptRefund(
                                    docs[i].id,
                                    rawAmount.abs(),
                                  )
                                  : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
