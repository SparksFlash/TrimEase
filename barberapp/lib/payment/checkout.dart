import 'package:flutter/material.dart';
import 'payment_helper.dart' as helper;

class PaymentCheckout extends StatefulWidget {
  final String serviceName;
  final DateTime date;
  final String time;
  final double amount;
  final String description;
  final String? shopId;
  final String? customerId;
  final double? baseAmount; // original base before dynamic adjustment
  final String? pricingApplied; // 'discount' | 'premium' | 'none'
  final double?
  percentApplied; // signed percent (+ for premium, - for discount)
  final double? demandScore; // raw demand metric

  const PaymentCheckout({
    Key? key,
    required this.serviceName,
    required this.date,
    required this.time,
    required this.amount,
    required this.description,
    this.shopId,
    this.customerId,
    this.baseAmount,
    this.pricingApplied,
    this.percentApplied,
    this.demandScore,
  }) : super(key: key);

  @override
  State<PaymentCheckout> createState() => _PaymentCheckoutState();
}

class _PaymentCheckoutState extends State<PaymentCheckout> {
  String? selectedKey;
  bool _processing = false;

  final List<Map<String, String>> gateways = [
    {
      'name': 'bKash',
      'logo':
          'https://freelogopng.com/images/all_img/1656234841bkash-icon-png.png',
    },
    {
      'name': 'UddoktaPay',
      'logo':
          'https://uddoktapay.com/assets/images/xlogo-icon.png.pagespeed.ic.IbVircDZ7p.png',
    },
    {
      'name': 'SslCommerz',
      'logo':
          'https://apps.odoo.com/web/image/loempia.module/193670/icon_image?unique=c301a64',
    },
  ];

  String _keyFromName(String name) => name.replaceAll(' ', '_').toLowerCase();

  String _displayNameFromKey(String key) {
    final match = gateways.firstWhere(
      (g) => _keyFromName(g['name'] ?? '') == key,
      orElse: () => {},
    );
    return match['name'] ?? key;
  }

  Future<void> _confirmAndProceed(String gatewayKey) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Proceed to payment'),
            content: Text(
              'Continue to payment with ${_displayNameFromKey(gatewayKey)} ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    setState(() => _processing = true);
    bool success = false;
    try {
      success = await helper.onButtonTap(
        context,
        gatewayKey,
        widget.amount,
        widget.description,
        shopId: widget.shopId,
        customerId: widget.customerId,
        serviceName: widget.serviceName,
      );
    } catch (e) {
      success = false;
    } finally {
      if (mounted) setState(() => _processing = false);
    }

    if (success) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed or cancelled')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseAmount ?? widget.amount;
    final applied = widget.pricingApplied ?? 'none';
    final percent = widget.percentApplied ?? 0.0;
    final demand = widget.demandScore;
    final adjusted = widget.amount;
    final isDiscount = applied == 'discount' && adjusted < base - 0.009;
    final isPremium = applied == 'premium' && adjusted > base + 0.009;
    final showDynamic = (isDiscount || isPremium) && base != adjusted;
    Color badgeColor;
    Gradient cardGradient;
    String badgeText;
    if (isDiscount) {
      badgeColor = Colors.green.shade600;
      cardGradient = const LinearGradient(
        colors: [Color(0xFF0F9D58), Color(0xFF34A853)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      badgeText = '${(percent.abs()).toStringAsFixed(0)}% OFF';
    } else if (isPremium) {
      badgeColor = Colors.deepOrange.shade600;
      cardGradient = const LinearGradient(
        colors: [Color(0xFFFF8A00), Color(0xFFFF3D00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      badgeText = '+${(percent.abs()).toStringAsFixed(0)}% Peak';
    } else {
      badgeColor = Colors.blueAccent;
      cardGradient = const LinearGradient(
        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      badgeText = 'Standard';
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // Dynamic pricing summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: cardGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(.92),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (showDynamic)
                        Text(
                          isDiscount ? 'Low Demand Slot' : 'Peak Demand Slot',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.serviceName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When: ${widget.date.toLocal().toString().split(' ')[0]} • ${widget.time}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (showDynamic)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '৳${adjusted.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '৳${base.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '৳${adjusted.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (demand != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Demand score: ${demand.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Select a payment method',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: gateways.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = gateways[index];
                  final name = item['name'] ?? '';
                  final logo = item['logo'] ?? '';
                  final key = _keyFromName(name);
                  return PaymentMethodTile(
                    logo: logo,
                    name: name,
                    selectedKey: selectedKey ?? '',
                    onTap: () {
                      setState(() {
                        selectedKey = key;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _processing
                ? const SizedBox(
                  height: 50,
                  child: Center(child: CircularProgressIndicator()),
                )
                : InkWell(
                  onTap:
                      selectedKey == null
                          ? null
                          : () => _confirmAndProceed(selectedKey!),
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color:
                          selectedKey == null
                              ? Colors.blueAccent.withOpacity(.5)
                              : Colors.blueAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Continue to payment',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class PaymentMethodTile extends StatelessWidget {
  final String logo;
  final String name;
  final VoidCallback? onTap;
  final String selectedKey;

  const PaymentMethodTile({
    super.key,
    required this.logo,
    required this.name,
    this.onTap,
    required this.selectedKey,
  });

  String _keyFromName(String name) => name.replaceAll(' ', '_').toLowerCase();

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedKey == _keyFromName(name);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? Colors.blueAccent : Colors.black.withOpacity(.1),
            width: 2,
          ),
        ),
        child: ListTile(
          leading: Image.network(
            logo,
            height: 35,
            width: 35,
            fit: BoxFit.contain,
            errorBuilder:
                (context, error, stackTrace) =>
                    const Icon(Icons.payment, size: 35, color: Colors.black26),
          ),
          title: Text(name),
          trailing:
              isSelected
                  ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                  : null,
        ),
      ),
    );
  }
}
