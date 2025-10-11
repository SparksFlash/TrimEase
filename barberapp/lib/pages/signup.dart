// import 'package:barberapp/login.dart';
// import 'package:barberapp/services/shared_pref.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:random_string/random_string.dart';
// import 'package:barberapp/services/database.dart';
// import 'package:barberapp/pages/bottomnav.dart';

// class SignUp extends StatefulWidget {
//   const SignUp({super.key});

//   @override
//   State<SignUp> createState() => _SignUpState();
// }

// class _SignUpState extends State<SignUp> {
//   String email = "", password = "", name = "";
//   TextEditingController namecontroller = new TextEditingController();
//   TextEditingController passwordcontroller = new TextEditingController();
//   TextEditingController mailcontroller = new TextEditingController();

//   registration() async {
//     if (passwordcontroller.text != "" &&
//         namecontroller.text != "" &&
//         mailcontroller.text != "") {
//       try {
//         UserCredential userCredential = await FirebaseAuth.instance
//             .createUserWithEmailAndPassword(email: email, password: password);

//         String Id = randomAlphaNumeric(10);
//         Map<String, dynamic> userInfoMap = {
//           "Name": namecontroller.text,
//           "Email": mailcontroller.text,
//           "Id": Id,
//         };
//         await DatabaseMethods().addUserInfo(userInfoMap, Id);
//         await SharedpreferenceHelper().saveUserId(Id);
//         await SharedpreferenceHelper().saveUserName(namecontroller.text);
//         await SharedpreferenceHelper().saveUserEmail(mailcontroller.text);

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             backgroundColor: Colors.green,
//             content: Text(
//               "Registered Successfully..!!",
//               style: TextStyle(fontSize: 18.0),
//             ),
//           ),
//         );

//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (context) => BottomNav()),
//         );
//       } on FirebaseAuthException catch (e) {
//         if (e.code == 'weak-password') {
//           print('The password provided is too weak.');
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: Colors.red,
//               content: Text(
//                 "The password provided is too weak.",
//                 style: TextStyle(fontSize: 20),
//               ),
//             ),
//           );
//         } else if (e.code == 'email-already-in-use') {
//           print('The account already exists for that email.');
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: Colors.red,
//               content: Text(
//                 "The account already exists for that email.",
//                 style: TextStyle(fontSize: 18.0),
//               ),
//             ),
//           );
//         }
//       } catch (e) {
//         print(e);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xff172ca2),
//       body: Container(
//         margin: EdgeInsets.only(top: 60.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: const EdgeInsets.only(left: 20.0, right: 20.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     "Hello....!",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontFamily: 'Pacifico',
//                       fontWeight: FontWeight.bold,
//                       fontSize: 45.0,
//                     ),
//                   ),

//                   SizedBox(height: 80.0),

//                   Container(
//                     height: 55,
//                     decoration: BoxDecoration(
//                       color: const Color(0xff4c5aa5),
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                     child: TextField(
//                       controller: namecontroller,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: const InputDecoration(
//                         border: InputBorder.none,
//                         prefixIcon: Icon(Icons.person, color: Colors.white),
//                         hintText: "Name",
//                         hintStyle: TextStyle(
//                           color: const Color.fromARGB(164, 255, 255, 255),
//                         ),
//                         contentPadding: EdgeInsets.symmetric(vertical: 15),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 30),

//                   Container(
//                     height: 55,
//                     decoration: BoxDecoration(
//                       color: const Color(0xff4c5aa5),
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                     child: TextField(
//                       controller: mailcontroller,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: const InputDecoration(
//                         border: InputBorder.none,
//                         prefixIcon: Icon(Icons.email, color: Colors.white),
//                         hintText: "Email",
//                         hintStyle: TextStyle(
//                           color: const Color.fromARGB(164, 255, 255, 255),
//                         ),
//                         contentPadding: EdgeInsets.symmetric(vertical: 15),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 30),

//                   Container(
//                     height: 55,
//                     decoration: BoxDecoration(
//                       color: const Color(0xff4c5aa5),
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                     child: TextField(
//                       controller: passwordcontroller,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: const InputDecoration(
//                         border: InputBorder.none,
//                         prefixIcon: Icon(Icons.password, color: Colors.white),
//                         hintText: "Password",
//                         hintStyle: TextStyle(
//                           color: const Color.fromARGB(164, 255, 255, 255),
//                         ),
//                         contentPadding: EdgeInsets.symmetric(vertical: 15),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 30),

//                   // Container(
//                   //   height: 55,
//                   //   decoration: BoxDecoration(
//                   //     color: const Color(0xff4c5aa5),
//                   //     borderRadius: BorderRadius.circular(30),
//                   //   ),
//                   //   child: TextField(
//                   //     style: const TextStyle(color: Colors.white),
//                   //     decoration: const InputDecoration(
//                   //       border: InputBorder.none,
//                   //       prefixIcon: Icon(Icons.password, color: Colors.white),
//                   //       hintText: "Confirm Password",
//                   //       hintStyle: TextStyle(
//                   //         color: const Color.fromARGB(164, 255, 255, 255),
//                   //       ),
//                   //       contentPadding: EdgeInsets.symmetric(vertical: 15),
//                   //     ),
//                   //   ),
//                   // ),
//                   const SizedBox(height: 50),

//                   // Login Button
//                   GestureDetector(
//                     onTap: () {
//                       if (namecontroller.text != "" &&
//                           mailcontroller.text != "" &&
//                           passwordcontroller.text != "") {
//                         setState(() {
//                           email = mailcontroller.text;
//                           password = passwordcontroller.text;
//                           name = namecontroller.text;
//                         });
//                         registration();
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             backgroundColor: Colors.red,
//                             content: Text(
//                               "Please fill all the fields",
//                               style: TextStyle(fontSize: 18.0),
//                             ),
//                           ),
//                         );
//                       }
//                     },
//                     child: Center(
//                       child: Container(
//                         height: 55,
//                         width: 160,
//                         decoration: BoxDecoration(
//                           color: const Color(0xfff85f3c),
//                           borderRadius: BorderRadius.circular(60),
//                         ),
//                         child: const Center(
//                           child: Text(
//                             "Sign Up",
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 22,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             Spacer(),
//             // Signup Row
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Text(
//                   "Already have an account ? ",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.w400,
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (context) => LogIn()),
//                     );
//                   },
//                   child: Text(
//                     "Login",
//                     style: const TextStyle(
//                       color: Color(0xfff85f3c),
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),

//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Image.asset("images/redcircle.png", height: 200),
//                 Image.asset("images/yellowcircle.png", height: 200),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:barberapp/pages/login.dart';
import 'package:barberapp/services/shared_pref.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:random_string/random_string.dart';
import 'package:barberapp/services/database.dart';
import 'package:barberapp/pages/bottomnav.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  String email = "", password = "", name = "";
  TextEditingController namecontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();
  TextEditingController mailcontroller = TextEditingController();

  registration() async {
    if (passwordcontroller.text.isNotEmpty &&
        namecontroller.text.isNotEmpty &&
        mailcontroller.text.isNotEmpty) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: mailcontroller.text,
              password: passwordcontroller.text,
            );

        String Id = randomAlphaNumeric(10);
        Map<String, dynamic> userInfoMap = {
          "Name": namecontroller.text,
          "Email": mailcontroller.text,
          "Id": Id,
        };
        await DatabaseMethods().addUserInfo(userInfoMap, Id);
        await SharedpreferenceHelper().saveUserId(Id);
        await SharedpreferenceHelper().saveUserName(namecontroller.text);
        await SharedpreferenceHelper().saveUserEmail(mailcontroller.text);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              "Registered Successfully..!!",
              style: TextStyle(fontSize: 18.0),
            ),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BottomNav()),
        );
      } on FirebaseAuthException catch (e) {
        String message = "";
        if (e.code == 'weak-password') {
          message = "The password provided is too weak.";
        } else if (e.code == 'email-already-in-use') {
          message = "The account already exists for that email.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(message, style: const TextStyle(fontSize: 18.0)),
          ),
        );
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff172ca2),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.only(top: 60.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heading
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Hello....!",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Pacifico',
                        fontWeight: FontWeight.bold,
                        fontSize: 45.0,
                      ),
                    ),
                    const SizedBox(height: 80.0),

                    // Name Field
                    inputField(namecontroller, Icons.person, "Name"),
                    const SizedBox(height: 30),
                    inputField(mailcontroller, Icons.email, "Email"),
                    const SizedBox(height: 30),
                    inputField(
                      passwordcontroller,
                      Icons.lock,
                      "Password",
                      isPassword: true,
                    ),

                    const SizedBox(height: 50),

                    // Signup Button
                    GestureDetector(
                      onTap: registration,
                      child: Center(
                        child: Container(
                          height: 55,
                          width: 160,
                          decoration: BoxDecoration(
                            color: const Color(0xfff85f3c),
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: const Center(
                            child: Text(
                              "Sign Up",
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
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Already have account? Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already have an account ? ",
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
                        MaterialPageRoute(builder: (context) => const LogIn()),
                      );
                    },
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        color: Color(0xfff85f3c),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget inputField(
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool isPassword = false,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xff4c5aa5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.white),
          hintText: hint,
          hintStyle: const TextStyle(color: Color.fromARGB(164, 255, 255, 255)),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
