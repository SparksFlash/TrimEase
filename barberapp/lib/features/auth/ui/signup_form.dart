import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({Key? key}) : super(key: key);

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _shopPickerController = TextEditingController();

  String _category = 'customer';
  bool _obscure = true;

  // Shops fetched from Firestore for barber selection
  List<Map<String, String>> _shops = []; // { 'id': uid, 'name': shopName }
  String? _selectedShopId;

  @override
  void initState() {
    super.initState();
    _fetchShops();
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

  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _confirmController.clear();
    _shopNameController.clear();
    _nameController.clear();
    _shopPickerController.clear();
    setState(() {
      _category = 'customer';
      _selectedShopId = null;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _shopNameController.dispose();
    _nameController.dispose();
    _shopPickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    // Shared styles for better visibility on dark backgrounds
    final fieldTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final labelStyle = TextStyle(
      color: Colors.white70,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final hintStyle = TextStyle(color: Colors.white54, fontSize: 14);
    final iconColor = Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: null,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameController,
              style: fieldTextStyle,
              decoration: InputDecoration(
                labelText: 'Full name',
                labelStyle: labelStyle,
                hintStyle: hintStyle,
                prefixIcon: Icon(Icons.person, color: iconColor),
              ),
              validator:
                  (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _emailController,
              style: fieldTextStyle,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: labelStyle,
                hintStyle: hintStyle,
                prefixIcon: Icon(Icons.email, color: iconColor),
              ),
              validator:
                  (v) =>
                      (v == null || !v.contains('@'))
                          ? 'Enter valid email'
                          : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              style: fieldTextStyle,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: labelStyle,
                hintStyle: hintStyle,
                prefixIcon: Icon(Icons.lock, color: iconColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                    color: iconColor,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator:
                  (v) => (v == null || v.length < 6) ? 'Minimum 6 chars' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              style: fieldTextStyle,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                labelStyle: labelStyle,
                hintStyle: hintStyle,
                prefixIcon: Icon(Icons.lock_outline, color: iconColor),
              ),
              validator:
                  (v) =>
                      (v != _passwordController.text)
                          ? 'Passwords do not match'
                          : null,
            ),
            const SizedBox(height: 12),

            // Owner: enter shop name
            if (_category == 'owner') ...[
              TextFormField(
                controller: _shopNameController,
                style: fieldTextStyle,
                decoration: InputDecoration(
                  labelText: 'Shop name',
                  labelStyle: labelStyle,
                  hintStyle: hintStyle,
                  prefixIcon: Icon(Icons.store, color: iconColor),
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Enter shop name'
                            : null,
              ),
              const SizedBox(height: 12),
            ],

            // Barber: select existing shop (autocomplete)
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
                  controller.text = _shopPickerController.text;
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

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    auth.loading
                        ? null
                        : () async {
                          if (!_formKey.currentState!.validate()) return;

                          final email = _emailController.text.trim();
                          final password = _passwordController.text.trim();

                          String? err;
                          if (_category == 'owner') {
                            final shopName = _shopNameController.text.trim();
                            err = await auth.signUp(
                              email: email,
                              password: password,
                              category: 'owner',
                              shopName: shopName,
                            );
                          } else if (_category == 'customer') {
                            err = await auth.signUp(
                              email: email,
                              password: password,
                              category: 'customer',
                            );
                          } else {
                            // barber
                            if (_selectedShopId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a shop'),
                                ),
                              );
                              return;
                            }
                            err = await auth.signUp(
                              email: email,
                              password: password,
                              category: 'barber',
                              selectedShopId: _selectedShopId,
                            );
                          }

                          if (err == null) {
                            // success (should not happen because provider signs out and returns verification status)
                            _clearForm();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sign up successful'),
                              ),
                            );
                          } else if (err == 'verification_sent') {
                            _clearForm();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Verification email sent — please check your inbox and verify before logging in.',
                                ),
                                duration: Duration(seconds: 6),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(err)));
                          }
                        },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child:
                    auth.loading
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Sign Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
