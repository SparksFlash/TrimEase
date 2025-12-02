import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // Added for kIsWeb detection
import 'firebase_options.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/auth/ui/auth_page.dart';
import 'features/owner/owner_dashboard.dart';
import 'features/barber/barber_dashboard.dart';
import 'features/customer/customer_dashboard.dart';
import 'utils/theme_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'utils/local_store.dart';
import 'utils/background_tasks.dart';
// firebase_auth and cloud_firestore not needed here after removing auto-redirect logic

// NOTE: Ensure firebase_options.dart exists from FlutterFire CLI if you use it.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  try {
    await Hive.initFlutter();
    await LocalStore.instance.init();
  } catch (e) {
    debugPrint('Hive init failed: $e');
  }

  // Try to initialize Firebase. On web, a generated `firebase_options.dart` is
  // typically required (created via `flutterfire configure`). If it's missing
  // Firebase.initializeApp() may throw. We catch errors so the app can still
  // run in a degraded (non-Firebase) mode and show a helpful banner.
  bool firebaseInitialized = false;
  try {
    // Only initialize if no Firebase apps exist yet. Some Firebase
    // plugins or hot-reload cycles may have created the default app
    // already which would cause a duplicate-app error if initialized
    // again. Checking `Firebase.apps` avoids that.
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        // On web we must pass explicit FirebaseOptions
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        // On Android/iOS the native configuration files (google-services.json
        // / GoogleService-Info.plist) are used; calling without options lets
        // the native SDK pick them up. This avoids failures when placeholders
        // exist in DefaultFirebaseOptions for non-web platforms.
        await Firebase.initializeApp();
      }
    }
    firebaseInitialized = true;
  } catch (e, st) {
    // Don't rethrow — log and continue. Many flows will gracefully handle
    // absent Firebase; others may show specific errors when used.
    debugPrint('Warning: Firebase.initializeApp() failed: $e');
    debugPrint('$st');
    firebaseInitialized = false;
  }

  // Initialize Workmanager and schedule periodic lightweight task
  try {
    await BackgroundTasks.initialize();
    await BackgroundTasks.ensurePeriodicOwnerSync();
  } catch (e) {
    debugPrint('Workmanager init failed: $e');
  }

  runApp(MyApp(firebaseAvailable: firebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool firebaseAvailable;

  const MyApp({super.key, this.firebaseAvailable = false});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(firebaseAvailable: firebaseAvailable),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Builder(
        builder: (context) {
          final theme = Provider.of<ThemeProvider>(context);
          return MaterialApp(
            title: 'BarberApp',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              useMaterial3: false,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
            routes: {
              '/': (_) => const RootRouter(),
              '/auth': (_) => const AuthPage(),
              '/owner_dashboard': (_) => const OwnerDashboard(),
              '/barber_dashboard': (_) => const BarberDashboard(),
              '/customer_dashboard': (_) => const CustomerDashboard(),
            },
            initialRoute: '/auth',
            builder: (context, child) {
              // If Firebase failed to initialize show a small banner at the top so
              // the developer knows why some features may not work.
              if (!firebaseAvailable) {
                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      child: const SafeArea(
                        child: Text(
                          'Firebase not initialized. Some features may be disabled.\nRun `flutterfire configure` and add firebase_options.dart for web.',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                );
              }
              return child ?? const SizedBox.shrink();
            },
          );
        },
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
