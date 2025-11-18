import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../provider/auth_provider.dart';
import '../../owner/owner_dashboard.dart';
import '../../barber/barber_dashboard.dart';
import '../../customer/customer_dashboard.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'customer';
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _shopPickerController = TextEditingController();
  List<Map<String, String>> _shops = [];
  String? _selectedShopId;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _shopPickerController.dispose();
    super.dispose();
  }

  Future<void> _fetchShops() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('shop').get();
      final list =
          snap.docs
              .map(
                (d) => {
                  'id': d.id,
                  'name': (d.data()['shopName'] ?? d.id).toString(),
                },
              )
              .where((m) => (m['name'] ?? '').isNotEmpty)
              .toList();
      if (mounted) setState(() => _shops = list);
    } catch (e) {
      debugPrint('Failed to load shops: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    // Shared styles for better visibility on dark backgrounds (match signup)
    final fieldTextStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final labelStyle = const TextStyle(
      color: Colors.white70,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final hintStyle = const TextStyle(color: Colors.white54, fontSize: 14);
    final iconColor = Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: Colors.black87,
                style: fieldTextStyle,
                items: [
                  DropdownMenuItem(
                    value: 'owner',
                    child: Text('Owner', style: fieldTextStyle),
                  ),
                  DropdownMenuItem(
                    value: 'barber',
                    child: Text('Barber', style: fieldTextStyle),
                  ),
                  DropdownMenuItem(
                    value: 'customer',
                    child: Text('Customer', style: fieldTextStyle),
                  ),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'customer'),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // If barber category, show shop picker
            if (_category == 'barber') ...[
              Autocomplete<Map<String, String>>(
                displayStringForOption: (opt) => opt['name'] ?? opt['id']!,
                optionsBuilder: (TextEditingValue txt) {
                  if (txt.text.isEmpty)
                    return const Iterable<Map<String, String>>.empty();
                  return _shops.where(
                    (s) => s['name']!.toLowerCase().contains(
                      txt.text.toLowerCase(),
                    ),
                  );
                },
                onSelected: (selection) {
                  _shopPickerController.text = selection['name']!;
                  _selectedShopId = selection['id'];
                },
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onFieldSubmitted,
                ) {
                  // Avoid assigning to the passed controller synchronously
                  // during build (which can trigger widget rebuilds). Defer
                  // the update to the next frame so we don't cause
                  // "setState() or markNeedsBuild() called during build".
                  if (controller.text != _shopPickerController.text) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) controller.text = _shopPickerController.text;
                    });
                  }
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: fieldTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Select shop',
                      labelStyle: labelStyle,
                      hintStyle: hintStyle,
                      prefixIcon: Icon(Icons.storefront, color: iconColor),
                    ),
                    validator:
                        (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Select shop'
                                : null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Material(
                    elevation: 4,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children:
                          options.map((opt) {
                            return ListTile(
                              title: Text(
                                opt['name'] ?? opt['id']!,
                                style: fieldTextStyle.copyWith(fontSize: 15),
                              ),
                              onTap: () => onSelected(opt),
                            );
                          }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            // Email
            _buildInput(
              controller: _email,
              hint: 'Email',
              icon: Icons.email,
              validator:
                  (v) =>
                      v != null && v.contains('@')
                          ? null
                          : 'Enter a valid email',
            ),
            const SizedBox(height: 10),

            // Password
            _buildInput(
              controller: _password,
              hint: 'Password',
              icon: Icons.lock,
              obscure: _obscure,
              suffix: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator:
                  (v) => (v != null && v.length >= 6) ? null : '6+ chars',
            ),
            const SizedBox(height: 18),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final emailVal = _email.text.trim();
                  final result = await showDialog<String?>(
                    context: context,
                    builder: (ctx) {
                      final TextEditingController _dlgEmail =
                          TextEditingController(text: emailVal);
                      return AlertDialog(
                        title: const Text('Reset password'),
                        content: TextField(
                          controller: _dlgEmail,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed:
                                () => Navigator.of(
                                  ctx,
                                ).pop(_dlgEmail.text.trim()),
                            child: const Text('Send'),
                          ),
                        ],
                      );
                    },
                  );

                  if (result != null && result.isNotEmpty) {
                    final err = await auth.sendPasswordReset(email: result);
                    if (err == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset email sent.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(err)));
                    }
                  }
                },
                child: const Text('Forgot password?'),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.green.shade600,
                ),
                onPressed:
                    auth.loading
                        ? null
                        : () async {
                          if (!_formKey.currentState!.validate()) return;
                          // If barber, ensure shop selected
                          if (_category == 'barber' &&
                              _selectedShopId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a shop'),
                              ),
                            );
                            return;
                          }
                          final err = await auth.login(
                            email: _email.text.trim(),
                            password: _password.text.trim(),
                            category: _category,
                            selectedShopId: _selectedShopId,
                          );
                          if (err != null) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(err)));
                            return;
                          }
                          // navigate by category
                          if (_category == 'owner') {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const OwnerDashboard(),
                              ),
                            );
                          } else if (_category == 'barber') {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const BarberDashboard(),
                              ),
                            );
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const CustomerDashboard(),
                              ),
                            );
                          }
                        },
                child:
                    auth.loading
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Login', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    TextStyle? textStyle,
    TextStyle? hintStyle,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        style: textStyle ?? const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          icon: Icon(icon, color: iconColor ?? Colors.white70),
          hintText: hint,
          hintStyle: hintStyle ?? const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
