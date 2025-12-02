// Consolidated Firebase options file.
// This file was cleaned up to provide a single DefaultFirebaseOptions class
// and to map web to the available web-like config present in the repo.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
      default:
        return android;
    }
  }

  // Web (uses the web-style values present earlier)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCbQvOAwJjvYnGYO2B1YLUjfvT9HKhbTeA',
    authDomain: 'trimease-1a9be.firebaseapp.com',
    projectId: 'trimease-1a9be',
    storageBucket: 'trimease-1a9be.firebasestorage.app',
    messagingSenderId: '258916185007',
    appId: '1:258916185007:web:1ea9b2f23f64797ce3b55a',
    measurementId: 'G-7BCDLCMYWH',
  );

  // Android placeholder (you can replace with real android options)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: '258916185007',
    projectId: 'trimease-1a9be',
  );

  // iOS placeholder
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '258916185007',
    projectId: 'trimease-1a9be',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBdWVllOfA7nO2gaIQkEX2hXVhH3tWKxac',
    appId: '1:258916185007:ios:3d59346a17ab670de3b55a',
    messagingSenderId: '258916185007',
    projectId: 'trimease-1a9be',
    storageBucket: 'trimease-1a9be.firebasestorage.app',
    iosBundleId: 'com.example.barberapp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCbQvOAwJjvYnGYO2B1YLUjfvT9HKhbTeA',
    appId: '1:258916185007:web:1ea9b2f23f64797ce3b55a',
    messagingSenderId: '258916185007',
    projectId: 'trimease-1a9be',
    authDomain: 'trimease-1a9be.firebaseapp.com',
    storageBucket: 'trimease-1a9be.firebasestorage.app',
    measurementId: 'G-7BCDLCMYWH',
  );
}
