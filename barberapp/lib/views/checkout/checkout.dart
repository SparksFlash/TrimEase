import 'package:flutter/material.dart';

class Checkout extends StatefulWidget {
  final String serviceName;
  final DateTime date;
  final String time;
  final double amount;
  final String description;

  const Checkout({
    Key? key,
    required this.serviceName,
    required this.date,
    required this.time,
    required this.amount,
    required this.description,
  }) : super(key: key);

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  bool _processing = false;

  Future<void> _simulatePayment() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _processing = false);
    // return success
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.serviceName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'When: ${widget.date.toLocal().toString().split(' ')[0]} at ${widget.time}',
            ),
            const SizedBox(height: 8),
            Text('Amount: ৳${widget.amount.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            Text(widget.description),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _processing
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _processing ? null : _simulatePayment,
                    child: _processing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Pay'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
