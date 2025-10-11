import 'package:flutter/material.dart';
import 'helpers/payment_helper.dart' as helper;

class Checkout extends StatefulWidget {
  final String serviceName;
  final DateTime date;
  final String time;
  final double amount;
  final String description;

  const Checkout({
    super.key,
    required this.serviceName,
    required this.date,
    required this.time,
    required this.amount,
    required this.description,
  });

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
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
      builder: (c) => AlertDialog(
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
      );
    } catch (e) {
      success = false;
    } finally {
      if (mounted) setState(() => _processing = false);
    }

    if (success) {
      // return success to caller (DetailPage)
      if (mounted) Navigator.of(context).pop(true);
    } else {
      // show failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed or cancelled')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Text(
              widget.serviceName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'When: ${widget.date.toLocal().toString().split(' ')[0]} • ${widget.time}',
            ),
            const SizedBox(height: 6),
            Text('Amount: ${widget.amount.toStringAsFixed(2)} BDT'),
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
                    onTap: selectedKey == null
                        ? null
                        : () => _confirmAndProceed(selectedKey!),
                    child: Container(
                      height: 50,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: selectedKey == null
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
            color: isSelected
                ? Colors.blueAccent
                : Colors.black.withOpacity(.1),
            width: 2,
          ),
        ),
        child: ListTile(
          leading: Image.network(
            logo,
            height: 35,
            width: 35,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.payment, size: 35, color: Colors.black26),
          ),
          title: Text(name),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Colors.blueAccent)
              : null,
        ),
      ),
    );
  }
}
