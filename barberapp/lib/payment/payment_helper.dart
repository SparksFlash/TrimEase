import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:url_launcher/url_launcher.dart';

// Native payment SDKs
import 'package:bkash/bkash.dart' show Bkash, BkashFailure;
import 'package:flutter_sslcommerz/sslcommerz.dart' show Sslcommerz;
import 'package:flutter_sslcommerz/model/SSLCommerzInitialization.dart';
import 'package:flutter_sslcommerz/model/SSLCurrencyType.dart';
import 'package:flutter_sslcommerz/model/SSLCSdkType.dart';
import 'package:uddoktapay/uddoktapay.dart' show UddoktaPay;
import 'package:uddoktapay/models/customer_model.dart';
import 'package:uddoktapay/models/request_response.dart';

/// Unified payment helper for Checkout page.
/// Replace the placeholder store IDs / URLs with your real ones.
/// Test on Android/iOS (native plugins don’t work on Web).

Future<bool> onButtonTap(
  BuildContext context,
  String selected,
  double amount,
  String description,
) async {
  final key = selected.toLowerCase().trim();

  if (kIsWeb && (key == 'bkash' || key == 'sslcommerz')) {
    _showSnack(context, 'Selected gateway is not supported on Web.');
    return false;
  }

  try {
    switch (key) {
      case 'bkash':
        return await _bkashPayment(context, amount, description);
      case 'uddoktapay':
        return await _uddoktaPay(context, amount, description);
      case 'sslcommerz':
        return await _sslCommerz(context, amount, description);
      default:
        _showSnack(context, 'Unknown payment gateway: $selected');
        return false;
    }
  } on MissingPluginException {
    _showSnack(context, 'Payment plugin not available on this platform.');
    return false;
  } catch (e, s) {
    debugPrint('onButtonTap error: $e\n$s');
    _showSnack(context, 'Payment error: $e');
    return false;
  }
}

/// ---------------- Common Helpers ----------------

void _showSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  if (!context.mounted) return false;
  final res = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// ---------------- bKash (Native) ----------------
Future<bool> _bkashPayment(
  BuildContext context,
  double amount,
  String invoice,
) async {
  try {
    final bkash = Bkash(logResponse: true);
    final resp = await bkash.pay(
      context: context,
      amount: amount,
      merchantInvoiceNumber: invoice,
    );

    final dyn = resp as dynamic;
    final trx = dyn?.trxId ?? '';
    final pid = dyn?.paymentId ?? '';

    if (trx.toString().isNotEmpty || pid.toString().isNotEmpty) {
      return true;
    }

    _showSnack(context, 'bKash payment incomplete.');
    return false;
  } on BkashFailure catch (e) {
    debugPrint('bKash failure: ${e.message}');
    _showSnack(context, 'bKash error: ${e.message}');
    return false;
  } on MissingPluginException {
    _showSnack(context, 'bKash plugin not available on this platform.');
    return false;
  } catch (e, s) {
    debugPrint('bKash error: $e\n$s');
    _showSnack(context, 'bKash error: $e');
    return false;
  }
}

/// ---------------- UddoktaPay ----------------
Future<bool> _uddoktaPay(
  BuildContext context,
  double amount,
  String description,
) async {
  const webCheckoutBase = 'https://your-checkout.example.com/uddokta';
  // web/native redirect/cancel URLs can be configured here if needed

  // Web flow
  if (kIsWeb) {
    final webUri = Uri.parse(
      '$webCheckoutBase?amount=${Uri.encodeComponent(amount.toString())}&desc=${Uri.encodeComponent(description)}',
    );

    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      final ok = await _confirmDialog(
        context,
        title: 'Complete Payment',
        message:
            'A payment page was opened in a new tab. Complete the payment and press Confirm.',
      );
      return ok;
    } else {
      _showSnack(context, 'Could not open UddoktaPay web checkout.');
      return false;
    }
  }

  // Native flow
  try {
    final response = await UddoktaPay.createPayment(
      context: context,
      customer: CustomerDetails(
        email: 'no-reply@example.com',
        fullName: 'Customer',
      ),
      amount: amount.toString(),
    );

    // Completed
    if (response.status == ResponseStatus.completed) return true;

    // Handle dynamic URLs
    final dyn = response as dynamic;
    final checkoutUrl = dyn?.redirectUrl ?? dyn?.paymentUrl ?? dyn?.checkoutUrl;

    if (checkoutUrl != null && checkoutUrl.toString().isNotEmpty) {
      final uri = Uri.tryParse(checkoutUrl.toString());
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return await _confirmDialog(
          context,
          title: 'Complete Payment',
          message:
              'A payment page was opened. Complete the payment and press Confirm.',
        );
      }
    }

    _showSnack(
      context,
      'UddoktaPay returned status: ${dyn?.status ?? 'unknown'}',
    );
    return false;
  } on MissingPluginException {
    _showSnack(context, 'UddoktaPay plugin not available on this platform.');
    return false;
  } catch (e, s) {
    debugPrint('UddoktaPay error: $e\n$s');
    _showSnack(context, 'UddoktaPay error: $e');
    return false;
  }
}

/// ---------------- SSLCommerz (Native) ----------------
Future<bool> _sslCommerz(
  BuildContext context,
  double amount,
  String invoice,
) async {
  if (kIsWeb) {
    _showSnack(context, 'SslCommerz is not supported on Web.');
    return false;
  }

  try {
    final initializer = SSLCommerzInitialization(
      multi_card_name: "visa,master,bkash",
      currency: SSLCurrencyType.BDT,
      product_category: "Service",
      sdkType: SSLCSdkType.TESTBOX, // Change to PRODUCTION in release
      store_id: "trime68e81f8f7f99f", 
      store_passwd: "trime68e81f8f7f99f@ssl", 
      total_amount: amount,
      tran_id: invoice,
    );

    final ssl = Sslcommerz(initializer: initializer);
    final resp = await ssl.payNow();

    final dyn = resp as dynamic;
    final status = (dyn?.status?.toString() ?? '').toUpperCase();

    if (status == 'VALID' || status == 'SUCCESS') return true;

    _showSnack(context, 'SslCommerz: $status');
    return false;
  } on MissingPluginException {
    _showSnack(context, 'SslCommerz plugin not available on this platform.');
    return false;
  } catch (e, s) {
    debugPrint('SslCommerz error: $e\n$s');
    _showSnack(context, 'SslCommerz error: $e');
    return false;
  }
}
