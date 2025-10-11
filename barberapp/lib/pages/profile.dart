// import 'package:flutter/material.dart';

// class ProfilePage extends StatelessWidget {
//   const ProfilePage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5E6E6), // light background (pinkish tone)
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF2D402D), // dark green
//         title: const Text(
//           "PROFILE",
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             letterSpacing: 1.2,
//           ),
//         ),
//         centerTitle: false,
//         elevation: 0,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // Avatar
//             CircleAvatar(
//               radius: 50,
//               backgroundColor: Colors.brown.shade200,
//               child: const Icon(
//                 Icons.person,
//                 size: 70,
//                 color: Colors.white,
//               ),
//             ),
//             const SizedBox(height: 30),

//             // Name Tile
//             _buildProfileTile(
//               icon: Icons.person,
//               title: "Name",
//               subtitle: "Shivam Gupta",
//               onTap: () {},
//             ),

//             const SizedBox(height: 15),

//             // Email Tile
//             _buildProfileTile(
//               icon: Icons.email,
//               title: "Email",
//               subtitle: "shivam22ckp@gmail.com",
//               onTap: () {},
//             ),

//             const SizedBox(height: 15),

//             // Logout
//             _buildProfileTile(
//               icon: Icons.logout,
//               title: "LogOut",
//               subtitle: "",
//               onTap: () {
//                 // handle logout
//               },
//             ),

//             const SizedBox(height: 15),

//             // Delete Account
//             _buildProfileTile(
//               icon: Icons.delete,
//               title: "Delete Account",
//               subtitle: "",
//               onTap: () {
//                 // handle delete account
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // 🔹 Reusable tile widget
//   Widget _buildProfileTile({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//         decoration: BoxDecoration(
//           color: const Color(0xFF2D402D), // dark green
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Row(
//           children: [
//             Icon(icon, color: Colors.white),
//             const SizedBox(width: 15),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: const TextStyle(
//                       color: Colors.white70,
//                       fontSize: 12,
//                     ),
//                   ),
//                   if (subtitle.isNotEmpty)
//                     Text(
//                       subtitle,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//             const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
//           ],
//         ),
//       ),
//     );
//   }
// }

// ...existing code...
// ...existing code...
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  bool _loading = false;
  String? _email;
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    final user = _auth.currentUser;
    _email = user?.email;
    _name = user?.displayName;
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');
    if (path != null && mounted) {
      setState(() => _imageFile = File(path));
    }
  }

  Future<void> _saveProfilePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', path);
  }

  Future<void> _clearProfilePath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path');
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
      await _saveProfilePath(picked.path);
    }
  }

  Future<void> _removeImage() async {
    if (!mounted) return;
    setState(() => _imageFile = null);
    await _clearProfilePath();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile picture removed')));
  }

  Future<void> _editEmailDialog() async {
    final TextEditingController newEmailCtrl = TextEditingController(
      text: _email ?? '',
    );
    final TextEditingController passwordCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'New email'),
              ),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password (for re-auth)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newEmail = newEmailCtrl.text.trim();
                final password = passwordCtrl.text;
                if (newEmail.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter email and password')),
                  );
                  return;
                }
                Navigator.of(context).pop();
                await _updateEmail(newEmail, password);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateEmail(String newEmail, String password) async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw firebase_auth.FirebaseAuthException(
          code: 'no-user',
          message: 'No signed-in user',
        );
      }

      final cred = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      await (user as dynamic).updateEmail(newEmail);
      setState(() => _email = newEmail);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email updated')));
    } on firebase_auth.FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message ?? e.code}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editNameDialog() async {
    final TextEditingController nameCtrl = TextEditingController(
      text: _name ?? '',
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameCtrl.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name cannot be empty')),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _updateName(newName);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateName(String newName) async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw firebase_auth.FirebaseAuthException(
          code: 'no-user',
          message: 'No signed-in user',
        );
      }
      await (user as dynamic).updateDisplayName(newName);
      setState(() => _name = newName);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name updated')));
    } on firebase_auth.FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message ?? e.code}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok == true) await _logout();
  }

  // resilient navigation helper: try named route, fallback to '/', finally pop to first
  Future<void> _safeNavigateToRoot(String targetRouteName) async {
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(targetRouteName, (r) => false);
      return;
    } catch (_) {
      // ignore and try '/'
    }
    try {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
      return;
    } catch (_) {
      // last resort: just pop to first route
    }
    try {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {
      // nothing else we can do
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out')));
      // Try to send user to login route, fallback safely if route isn't defined.
      await _safeNavigateToRoot('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will permanently delete your account. Enter password to confirm re-authentication.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final password = passwordCtrl.text;
      if (password.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password required')));
        return;
      }
      await _deleteAccount(password);
    }
  }

  Future<void> _deleteAccount(String password) async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw firebase_auth.FirebaseAuthException(
          code: 'no-user',
          message: 'No signed-in user',
        );
      }

      final cred = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      await user.delete();
      await _clearProfilePath();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account deleted')));
      await _safeNavigateToRoot('/signup');
    } on firebase_auth.FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message ?? e.code}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: color ?? const Color(0xFF2D402D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeGreen = const Color(0xFF2D402D);
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6E6),
      appBar: AppBar(
        backgroundColor: themeGreen,
        title: const Text(
          "PROFILE",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar + edit actions
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.brown.shade200,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : null,
                        child: _imageFile == null
                            ? const Icon(
                                Icons.person,
                                size: 70,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.photo_camera,
                              color: Colors.white,
                            ),
                            onPressed: () => _pickImage(ImageSource.camera),
                            tooltip: 'Take photo',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.photo_library,
                              color: Colors.white,
                            ),
                            onPressed: () => _pickImage(ImageSource.gallery),
                            tooltip: 'Choose from gallery',
                          ),
                          if (_imageFile != null)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.white,
                              ),
                              onPressed: _removeImage,
                              tooltip: 'Remove photo',
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  _buildProfileTile(
                    icon: Icons.person,
                    title: "Name",
                    subtitle:
                        _name ?? _auth.currentUser?.displayName ?? 'Your name',
                    onTap: _editNameDialog,
                  ),
                  const SizedBox(height: 15),

                  _buildProfileTile(
                    icon: Icons.email,
                    title: "Email",
                    subtitle: _email ?? '',
                    onTap: _editEmailDialog,
                  ),
                  const SizedBox(height: 15),

                  _buildProfileTile(
                    icon: Icons.logout,
                    title: "LogOut",
                    subtitle: '',
                    onTap: _confirmLogout,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(height: 15),

                  _buildProfileTile(
                    icon: Icons.delete,
                    title: "Delete Account",
                    subtitle: '',
                    onTap: _confirmDeleteAccount,
                    color: Colors.red.shade700,
                  ),
                ],
              ),
            ),
    );
  }
}
