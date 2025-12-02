# TrimEase — Flutter & Dart Cheatsheet (Detailed)

This document is a comprehensive, exam-ready cheatsheet for the TrimEase barber app. It focuses on Dart and Flutter concepts used in the project, code examples, file references and short viva-style answers you can memorize.

---

## Quick repo map (where to look during viva)
- App entry: `lib/main.dart`
- Auth provider: `lib/features/auth/provider/auth_provider.dart`
- Customer chatbot & booking flow: `lib/features/customer/customer_chatbot.dart`
- Owner dashboard: `lib/features/owner/owner_dashboard.dart`
- Theme provider: `lib/utils/theme_provider.dart`
- Firebase helper: `lib/utils/firebase_helper.dart`
- Cloudinary upload: `lib/utils/cloudinary_service.dart`
- Payment UI & helper: `lib/payment/checkout.dart`, `lib/payment/payment_helper.dart`
- Dependencies: `pubspec.yaml`

---

## Dependencies (from `pubspec.yaml`) — mention these
- `flutter` (SDK)
- `firebase_core`, `firebase_auth`, `cloud_firestore` — Firebase integration
- `provider` — state management via `ChangeNotifier`
- `shared_preferences` — lightweight local persistence
- `dio`, `http` — HTTP & file upload
- `image_picker` — picking images from device
- `flutter_dotenv` — environment variables
- `url_launcher` — open external URLs
- Payment SDKs: `bkash`, `uddoktapay`, `flutter_sslcommerz`, `flutter_stripe` (stripe present but not widely used in code)

---

## App startup & Firebase initialization
Key points:
- `WidgetsFlutterBinding.ensureInitialized()` ensures platform channels are ready before async initialization.
- Check `Firebase.apps.isEmpty` to avoid duplicate initialization.
- Use `kIsWeb` to provide `FirebaseOptions` (from `firebase_options.dart`) for web.
- Catch exceptions to allow degraded mode (app still runs without Firebase).

Example (from `lib/main.dart`):

```dart
WidgetsFlutterBinding.ensureInitialized();
if (Firebase.apps.isEmpty) {
  if (kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } else {
    await Firebase.initializeApp();
  }
}
```

Viva tip: "We check `Firebase.apps` before calling `initializeApp()` and handle web differently because web requires explicit FirebaseOptions."

---

## Routing & Navigation
- Named routes configured in `MaterialApp.routes` and `initialRoute`.
- Use `Navigator.of(context).push`, `pushReplacementNamed`, and `MaterialPageRoute` for ad-hoc navigation and passing data.
- Getting results from pages: `final ok = await Navigator.push<bool>(...);` and `Navigator.pop(true)` from the pushed page.

Example: pushing checkout and awaiting result (from `customer_chatbot.dart`):

```dart
final ok = await Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) => PaymentCheckout(...),
  ),
);
if (ok == true) { /* proceed */ }
```

Viva tip: "Use `push` when you want to retrieve a result on return; use `pushReplacementNamed` to replace the current route."

---

## Widgets & State
- `StatelessWidget`: immutable UI (example: small widgets like `PaymentMethodTile` could be stateless).
- `StatefulWidget`: UI that changes over time (state stored in `State`). Example: `CustomerChatbot`, `OwnerDashboard`, `PaymentCheckout`.
- Update UI using `setState(() { ... })` — ensure you check `mounted` after async calls.

Code snippet (chat message list):

```dart
ListView.builder(
  reverse: true,
  itemCount: _messages.length,
  itemBuilder: (context, i) {
    final m = _messages[i];
    return Row(...);
  },
)
```

Viva tip: "Use `reverse: true` to show newest chat messages on top."

---

## Provider & ChangeNotifier
- `Provider` is used for app-wide state: `AuthProvider` and `ThemeProvider` provided at root in `main.dart` via `MultiProvider`.
- `ChangeNotifier` notifies listeners through `notifyListeners()`; widgets read via `Provider.of<T>(context)` or `Consumer<T>`.

Example (main):

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider(firebaseAvailable: firebaseInitialized)),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
  ],
  child: MaterialApp(...),
)
```

Viva tip: "Provider is a simple DI + state system ideal for small to medium apps. Explain `listen: false` when reading provider methods without rebuild."

---

## Theming & Persistence
- `ThemeProvider` reads/writes `SharedPreferences` to persist `isDark`.
- `MaterialApp` uses `themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light`.

Code (theme toggle):

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('isDarkMode', _isDark);
```

Viva tip: "SharedPreferences is synchronous for read/write via `getInstance()` + async methods; it’s not for large data."

---

## Async / Futures / Streams
- Use `async/await` plus `try/catch` for error handling.
- Use `Future.delayed` for simulated delays.
- `StreamBuilder` to subscribe to Firestore snapshots.
- Always check `mounted` before `setState` after `await`.

Example (StreamBuilder in `owner_dashboard.dart`):

```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance.collection('shop').doc(_uid).snapshots(),
  builder: (context, snap) {
    if (snap.connectionState == ConnectionState.waiting) return CircularProgressIndicator();
    final data = snap.data!.data() as Map<String, dynamic>;
    return Text(data['shopName']);
  }
)
```

Viva tip: "Explain difference between `FutureBuilder` and `StreamBuilder`: Future runs once, Stream updates repeatedly."

---

## Firestore patterns (reads, writes, transactions)
- Documents/collections: `.collection('shop').doc(shopId).collection('services')`.
- Use `FieldValue.serverTimestamp()` to record server time.
- Use `Timestamp.fromDate(datetime)` for queries on stored timestamps.
- `runTransaction` to atomically check for slot conflicts and insert booking documents across multiple locations (shop bookings, user bookings, and top-level chatbot bookings).

Critical example (booking transaction in `customer_chatbot.dart`):

```dart
await FirebaseFirestore.instance.runTransaction((tx) async {
  final conflictQuery = await bookingsRef
    .where('scheduledAt', isEqualTo: Timestamp.fromDate(scheduled))
    .get();
  if (conflictQuery.docs.isNotEmpty) throw 'slot_conflict';

  final bookingData = { ... };
  final newBookingRef = bookingsRef.doc();
  tx.set(newBookingRef, bookingData);
  tx.set(userBookingRef, bookingData);
  tx.set(chatbotBookingRef, chatbotData);
});
```

Viva tip: "Transactions prevent race conditions when multiple clients try to book the same slot."

---

## FirebaseAuth
- Signup: `createUserWithEmailAndPassword`, then `sendEmailVerification` and sign out until verified.
- Login: `signInWithEmailAndPassword`, check `user.emailVerified`.
- Access current user: `FirebaseAuth.instance.currentUser`.

Example (auth provider):

```dart
final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
await cred.user?.sendEmailVerification();
await auth.signOut();
```

Viva tip: "Explain security flow: verifying email reduces abuse; you still need server-side checks for sensitive ops."

---

## Chatbot — simple NLU & command parsing
- Uses `RegExp` to parse commands like `book <shopId> <serviceId> YYYY-MM-DD HH:MM`.
- Maintains intermediate state for multi-step booking (`_selectedShopId`, `_lastShopDocs`, `_selectedDate`, `_selectedTime`).
- Can forward to an external chatbot API using `http.post`, or fallback to local logic.

Example snippet (command regex):

```dart
final bookRegex = RegExp(r'book\s+(\S+)\s+(\S+)\s+(\d{4}-\d{2}-\d{2})\s+(\d{1,2}:\d{2})', caseSensitive: false);
final m = bookRegex.firstMatch(text);
```

Viva tip: "For production, use proper NLU services; regex is fine for demo use."

---

## HTTP & File Uploads
- `http.post` for simple JSON APIs.
- `dio` for multipart uploads and progress callbacks.
- `CloudinaryService.uploadXFile` uses `FormData.fromMap` + `MultipartFile.fromBytes(bytes, filename: ...)`.

Example (Cloudinary upload):

```dart
final formData = FormData.fromMap({
  'file': MultipartFile.fromBytes(bytes, filename: fileName),
  'upload_preset': preset,
  'resource_type': 'image',
});
final resp = await dio.post(uri, data: formData, onSendProgress: onProgress);
```

Viva tip: "Use Dio when you need multipart form/upload progress."

---

## Platform checks & plugin availability
- Use `kIsWeb` to branch web vs native behavior.
- Catch `MissingPluginException` to handle missing native plugin at runtime (useful when running on web or during tests).

Example (payment helper):

```dart
if (kIsWeb && (key == 'bkash' || key == 'sslcommerz')) {
  _showSnack(context, 'Selected gateway is not supported on Web.');
  return false;
}
```

Viva tip: "Always guard native plugin calls when your app also targets web."

---

## Payment integration patterns
- Native plugin flows: use the plugin API and check result objects (e.g., `Bkash`, `Sslcommerz`, `UddoktaPay`).
- Web flow: open external checkout with `url_launcher` and confirm with the user via a dialog.
- Confirmations and UX: use `showDialog` for confirmation and `ScaffoldMessenger` for SnackBars.

Viva tip: "Explain why payment flows differ by platform and how to handle user confirmation."

---

## UI & UX patterns used
- Chat bubbles: `Container` styling + `Row` to align left/right depending on sender.
- Loading indicators: `CircularProgressIndicator`, `LinearProgressIndicator`.
- Dialogs: `AlertDialog` for confirmation and `showDialog` returns `Future<bool?>`.
- Selection tiles: `ListTile` with leading image and trailing check icon.

---

## Best practices shown in repo
- Defensive Firebase initialization and feature degradation when Firebase unavailable.
- Using transactions for multi-document writes to ensure atomicity.
- Using `mounted` checks before `setState` after async await.
- Catching `MissingPluginException` for platform safety.
- Persisting user preferences with `SharedPreferences`.

---

## Common viva questions & short answers (memorize these)
- Q: How do you prevent double-initializing Firebase?
  - A: Check `Firebase.apps.isEmpty` before `initializeApp()`.
- Q: Why use Firestore transactions for bookings?
  - A: To atomically check for conflicts and write multiple docs, preventing race conditions.
- Q: What’s the difference between `FutureBuilder` and `StreamBuilder`?
  - A: `FutureBuilder` handles a single asynchronous result; `StreamBuilder` listens to a stream and rebuilds on every event.
- Q: Why check `mounted` after await?
  - A: The widget might be disposed while awaiting; calling `setState` on disposed widget causes errors.
- Q: When to use Provider vs other state managers?
  - A: Provider is lightweight and suitable for many apps; use more advanced solutions (Bloc/Redux/Riverpod) for complex state/side effects.

---

## Exam checklist (two-minute drill)
- Open `lib/main.dart`: explain app startup and routing.
- Open `lib/features/auth/provider/auth_provider.dart`: show signup and login flow, email verification.
- Open `lib/features/customer/customer_chatbot.dart`: explain chat command parsing and booking transaction flow.
- Open `lib/payment/payment_helper.dart`: explain platform-specific payment flow and `MissingPluginException` handling.
- Explain `Provider` usage and `ThemeProvider` persistence.

---

## How to convert this cheatsheet to PDF locally
If you want a PDF file on your machine, use `pandoc` (recommended) or VS Code print-to-PDF:

Install pandoc (Debian/Ubuntu):

```bash
sudo apt update
sudo apt install -y pandoc texlive-xetex # xetex optional for better fonts
```

Convert:

```bash
pandoc cheatsheet_flutter_dart.md -o cheatsheet_flutter_dart.pdf
```

If pandoc is not available, open this Markdown in VS Code and use `File → Print` to save as PDF.

---

## Where to find quick code examples in repo
- App startup: `lib/main.dart`
- Auth flows: `lib/features/auth/provider/auth_provider.dart`
- Chat + booking + transactions: `lib/features/customer/customer_chatbot.dart`
- Firestore streams: `lib/features/owner/owner_dashboard.dart`
- Theme + SharedPreferences: `lib/utils/theme_provider.dart`
- Cloudinary image upload: `lib/utils/cloudinary_service.dart`
- Payments: `lib/payment/payment_helper.dart`

---

Good luck with your exam — let me know if you want this converted to PDF now, or if you want a shorter one-page summary printable as A4.
