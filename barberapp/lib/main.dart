import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/auth/ui/auth_page.dart';
import 'features/owner/owner_dashboard.dart';
import 'features/barber/barber_dashboard.dart';
import 'features/customer/customer_dashboard.dart';
// firebase_auth and cloud_firestore not needed here after removing auto-redirect logic

// NOTE: Ensure firebase_options.dart exists from FlutterFire CLI if you use it.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'BarberApp',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.green),
        routes: {
          '/': (_) => const RootRouter(),
          '/auth': (_) => const AuthPage(),
          '/owner_dashboard': (_) => const OwnerDashboard(),
          '/barber_dashboard': (_) => const BarberDashboard(),
          '/customer_dashboard': (_) => const CustomerDashboard(),
        },
        initialRoute: '/auth',
      ),
    );
  }
}

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  @override
  void initState() {
    super.initState();
    // Auto-login/redirect logic removed: app will start at the Auth page
    // and users must explicitly login from the UI.
  }

  @override
  Widget build(BuildContext context) {
    // Directly send to /auth so the app always opens the authentication UI first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/auth');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
