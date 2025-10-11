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
      final list = snap.docs
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
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  DropdownMenuItem(value: 'barber', child: Text('Barber')),
                  DropdownMenuItem(value: 'customer', child: Text('Customer')),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'customer'),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: null,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter name' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter valid email' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Minimum 6 chars' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) => (v != _passwordController.text)
                  ? 'Passwords do not match'
                  : null,
            ),
            const SizedBox(height: 12),

            // Owner: enter shop name
            if (_category == 'owner') ...[
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(
                  labelText: 'Shop name',
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter shop name' : null,
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
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      controller.text = _shopPickerController.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Select shop',
                          prefixIcon: Icon(Icons.storefront),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
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
                      children: options.map((opt) {
                        return ListTile(
                          title: Text(opt['name'] ?? opt['id']!),
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
                onPressed: auth.loading
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
                          // success
                          _clearForm();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sign up successful')),
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
                child: auth.loading
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
