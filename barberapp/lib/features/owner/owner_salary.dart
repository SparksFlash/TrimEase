import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/premium_background.dart';
import '../../utils/theme_provider.dart';

class OwnerSalaryPage extends StatefulWidget {
  final String shopId;
  const OwnerSalaryPage({Key? key, required this.shopId}) : super(key: key);

  @override
  State<OwnerSalaryPage> createState() => _OwnerSalaryPageState();
}

class _OwnerSalaryPageState extends State<OwnerSalaryPage> {
  String _monthKey = _currentMonthKey();
  bool _processing = false;

  static String _currentMonthKey({DateTime? dt}) {
    final now = dt ?? DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _paySalary({
    required String barberId,
    required String barberName,
  }) async {
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Pay Monthly Salary'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Barber: $barberName'),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (BDT)',
                    prefixText: '৳',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Pay'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    setState(() => _processing = true);
    final fire = FirebaseFirestore.instance;
    final shopRef = fire.collection('shop').doc(widget.shopId);
    final monthRef = shopRef.collection('salary').doc(_monthKey);
    final barberMonthRef = monthRef.collection('barbers').doc(barberId);
    final barberRef = shopRef.collection('barber').doc(barberId);

    try {
      await fire.runTransaction((tx) async {
        // Append salary record under shop salary/{month}/barbers/{barberId}
        tx.set(barberMonthRef, {
          'barberId': barberId,
          'barberName': barberName,
          'amount': FieldValue.increment(amount),
          'month': _monthKey,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Mirror under barber doc collection for personal records
        final mirrorRef = barberRef.collection('salary').doc(_monthKey);
        tx.set(mirrorRef, {
          'amount': FieldValue.increment(amount),
          'month': _monthKey,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Optionally track totals on shop doc
        tx.update(shopRef, {
          'salaryTotal_${_monthKey}': FieldValue.increment(amount),
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Salary paid: ৳${amount.toStringAsFixed(2)} to $barberName',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pay salary: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopId = widget.shopId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Salary'),
        actions: [
          Consumer<ThemeProvider>(
            builder:
                (ctx, theme, _) => IconButton(
                  tooltip: theme.isDark ? 'Light mode' : 'Dark mode',
                  icon: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => theme.toggle(),
                ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _monthKey = v),
            itemBuilder: (c) {
              final now = DateTime.now();
              return List.generate(6, (i) {
                final dt = DateTime(now.year, now.month - i, 1);
                final key = _currentMonthKey(dt: dt);
                return PopupMenuItem(value: key, child: Text(key));
              });
            },
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      body: PremiumBackground(
        showBadge: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Premium Salary Manager • $_monthKey',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection('shop')
                        .doc(shopId)
                        .collection('barber')
                        .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final barbers = snap.data?.docs ?? [];
                  if (barbers.isEmpty) {
                    return const Center(
                      child: Text('No barbers found in this shop'),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: barbers.length,
                    itemBuilder: (context, i) {
                      final d = barbers[i];
                      final m = d.data();
                      final barberId = d.id;
                      final name = (m['name'] ?? barberId).toString();
                      return Material(
                        color: Theme.of(context).cardColor,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap:
                              _processing
                                  ? null
                                  : () => _paySalary(
                                    barberId: barberId,
                                    barberName: name,
                                  ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.workspace_premium,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>
                                >(
                                  stream:
                                      FirebaseFirestore.instance
                                          .collection('shop')
                                          .doc(shopId)
                                          .collection('salary')
                                          .doc(_monthKey)
                                          .collection('barbers')
                                          .doc(barberId)
                                          .snapshots(),
                                  builder: (c, s2) {
                                    double total = 0.0;
                                    if (s2.data?.exists == true) {
                                      final mm = s2.data!.data();
                                      final a = mm?['amount'];
                                      if (a is num)
                                        total = a.toDouble();
                                      else if (a is String)
                                        total = double.tryParse(a) ?? 0.0;
                                    }
                                    return Row(
                                      children: [
                                        Text(
                                          'Paid this month: ',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          '৳${total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const Spacer(),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child:
                                      _processing
                                          ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : ElevatedButton.icon(
                                            icon: const Icon(Icons.payments),
                                            label: const Text('Pay'),
                                            onPressed:
                                                () => _paySalary(
                                                  barberId: barberId,
                                                  barberName: name,
                                                ),
                                          ),
                                ),
                              ],
                            ),
                          ),
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
