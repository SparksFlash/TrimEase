// import 'package:barberapp/signup.dart';
// import 'package:flutter/material.dart';

// class LogIn extends StatefulWidget {
//   const LogIn({super.key});

//   @override
//   State<LogIn> createState() => _LogInState();
// }

// class _LogInState extends State<LogIn> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xff172ca2),
//       body: Stack(
//         children: [
//           Positioned.fill(
//             child: Image.asset("images/bg.png", fit: BoxFit.cover),
//           ),

//           // Main content
//           Padding(
//             padding: EdgeInsets.only(
//               top: MediaQuery.of(context).size.height / 3, // push content down
//               left: 20,
//               right: 20,
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "Welcome\nBack",
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontFamily: 'Pacifico',
//                     fontSize: 40,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 40),

//                 // Email Field
//                 Container(
//                   height: 55,
//                   decoration: BoxDecoration(
//                     color: const Color(0xff4c5aa5),
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   child: TextField(
//                     style: const TextStyle(color: Colors.white),
//                     decoration: const InputDecoration(
//                       border: InputBorder.none,
//                       prefixIcon: Icon(Icons.email, color: Colors.white),
//                       hintText: "Email",
//                       hintStyle: TextStyle(color: Colors.white70),
//                       contentPadding: EdgeInsets.symmetric(vertical: 15),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),

//                 // Password Field
//                 Container(
//                   height: 55,
//                   decoration: BoxDecoration(
//                     color: const Color(0xff4c5aa5),
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   child: TextField(
//                     obscureText: true,
//                     style: const TextStyle(color: Colors.white),
//                     decoration: const InputDecoration(
//                       border: InputBorder.none,
//                       prefixIcon: Icon(Icons.lock, color: Colors.white),
//                       hintText: "Password",
//                       hintStyle: TextStyle(color: Colors.white70),
//                       contentPadding: EdgeInsets.symmetric(vertical: 15),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 10),

//                 // Forgot Password
//                 Align(
//                   alignment: Alignment.centerRight,
//                   child: Text(
//                     "Forgot Password?",
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 40),

//                 // Login Button
//                 Center(
//                   child: Container(
//                     height: 55,
//                     width: 160,
//                     decoration: BoxDecoration(
//                       color: const Color(0xfff85f3c),
//                       borderRadius: BorderRadius.circular(60),
//                     ),
//                     child: const Center(
//                       child: Text(
//                         "Login",
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 22,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),

//                 // Signup Row
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Text(
//                       "New User ? ",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.w400,
//                       ),
//                     ),
//                     GestureDetector(
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(builder: (context) => SignUp()),
//                         );
//                       },
//                       child: Text(
//                         "Signup",
//                         style: const TextStyle(
//                           color: Color(0xfff85f3c),
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// 2nd Part
// import 'package:barberapp/pages/bottomnav.dart';
// import 'package:barberapp/pages/signup.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class LogIn extends StatefulWidget {
//   const LogIn({super.key});

//   @override
//   State<LogIn> createState() => _LogInState();
// }

// class _LogInState extends State<LogIn> {
//   TextEditingController emailController = TextEditingController();
//   TextEditingController passwordController = TextEditingController();

//   login() async {
//     try {
//       await FirebaseAuth.instance.signInWithEmailAndPassword(
//         email: emailController.text,
//         password: passwordController.text,
//       );

//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const BottomNav()),
//       );
//     } on FirebaseAuthException catch (e) {
//       String message = "";
//       if (e.code == 'user-not-found') {
//         message = "No user found for that email.";
//       } else if (e.code == 'wrong-password') {
//         message = "Wrong password provided.";
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text(message, style: const TextStyle(fontSize: 18)),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xff172ca2),
//       body: Stack(
//         children: [
//           Positioned.fill(
//             child: Image.asset("images/bg.png", fit: BoxFit.cover),
//           ),
//           Padding(
//             padding: EdgeInsets.only(
//               top: MediaQuery.of(context).size.height / 3,
//               left: 20,
//               right: 20,
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   "Welcome\nBack",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontFamily: 'Pacifico',
//                     fontSize: 40,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 40),
//                 inputField(emailController, Icons.email, "Email"),
//                 const SizedBox(height: 20),
//                 inputField(
//                   passwordController,
//                   Icons.lock,
//                   "Password",
//                   isPassword: true,
//                 ),
//                 const SizedBox(height: 20),

//                 // Login Button
//                 Center(
//                   child: GestureDetector(
//                     onTap: login,
//                     child: Container(
//                       height: 55,
//                       width: 160,
//                       decoration: BoxDecoration(
//                         color: const Color(0xfff85f3c),
//                         borderRadius: BorderRadius.circular(60),
//                       ),
//                       child: const Center(
//                         child: Text(
//                           "Login",
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 22,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),

//                 // Signup Row
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Text(
//                       "New User ? ",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.w400,
//                       ),
//                     ),
//                     GestureDetector(
//                       onTap: () {
//                         Navigator.pushReplacement(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => const SignUp(),
//                           ),
//                         );
//                       },
//                       child: const Text(
//                         "Signup",
//                         style: TextStyle(
//                           color: Color(0xfff85f3c),
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget inputField(
//     TextEditingController controller,
//     IconData icon,
//     String hint, {
//     bool isPassword = false,
//   }) {
//     return Container(
//       height: 55,
//       decoration: BoxDecoration(
//         color: const Color(0xff4c5aa5),
//         borderRadius: BorderRadius.circular(30),
//       ),
//       child: TextField(
//         controller: controller,
//         obscureText: isPassword,
//         style: const TextStyle(color: Colors.white),
//         decoration: InputDecoration(
//           border: InputBorder.none,
//           prefixIcon: Icon(icon, color: Colors.white),
//           hintText: hint,
//           hintStyle: const TextStyle(color: Colors.white70),
//           contentPadding: const EdgeInsets.symmetric(vertical: 15),
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:barberapp/pages/bottomnav.dart';
import 'package:barberapp/pages/signup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  List<String> _savedEmails = [];

  @override
  void initState() {
    super.initState();
    _loadSavedEmails();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_emails') ?? [];
    setState(() => _savedEmails = list);
  }

  Future<void> _saveEmail(String email) async {
    if (email.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_emails') ?? [];
    // keep unique and most-recent-first
    list.remove(email);
    list.insert(0, email);
    // keep only last 10 entries
    final truncated = list.take(10).toList();
    await prefs.setStringList('saved_emails', truncated);
    setState(() => _savedEmails = truncated);
  }

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // save email (not password)
      await _saveEmail(emailController.text.trim());

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BottomNav()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Authentication failed.";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password provided.";
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(message, style: const TextStyle(fontSize: 18)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // allow content to scroll when keyboard appears, avoid overflow
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xff172ca2),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset("images/bg.png", fit: BoxFit.cover),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height / 6,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome\nBack",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Pacifico',
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email with autocomplete suggestions (previously used emails)
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '')
                          return const Iterable<String>.empty();
                        return _savedEmails.where(
                          (e) => e.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (selection) {
                        emailController.text = selection;
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            // initialize the internal controller with current value
                            textEditingController.text = emailController.text;
                            textEditingController.selection =
                                emailController.selection;

                            // keep both controllers in sync
                            textEditingController.addListener(() {
                              if (emailController.text !=
                                  textEditingController.text) {
                                emailController.text =
                                    textEditingController.text;
                                emailController.selection =
                                    textEditingController.selection;
                              }
                            });

                            return inputFieldWidget(
                              controller: textEditingController,
                              icon: Icons.email,
                              hint: "Email",
                              focusNode: focusNode,
                            );
                          },
                    ),

                    const SizedBox(height: 20),

                    // Password field (regular)
                    inputField(
                      passwordController,
                      Icons.lock,
                      "Password",
                      isPassword: true,
                    ),

                    const SizedBox(height: 20),

                    // Login Button
                    Center(
                      child: GestureDetector(
                        onTap: login,
                        child: Container(
                          height: 55,
                          width: 160,
                          decoration: BoxDecoration(
                            color: const Color(0xfff85f3c),
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: const Center(
                            child: Text(
                              "Login",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Signup Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "New User ? ",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUp(),
                              ),
                            );
                          },
                          child: const Text(
                            "Signup",
                            style: TextStyle(
                              color: Color(0xfff85f3c),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable input field that accepts an external controller
  Widget inputField(
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool isPassword = false,
  }) {
    return inputFieldWidget(
      controller: controller,
      icon: icon,
      hint: hint,
      isPassword: isPassword,
    );
  }

  Widget inputFieldWidget({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    FocusNode? focusNode,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xff4c5aa5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        keyboardType: isPassword
            ? TextInputType.visiblePassword
            : TextInputType.emailAddress,
        autofillHints: isPassword
            ? const [AutofillHints.password]
            : const [AutofillHints.email],
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.white),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
