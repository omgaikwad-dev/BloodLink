// File generated & maintained manually for BloodLink AI
// Supports: Android, Web
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS – '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Web configuration — uses the same project as Android
  /// NOTE: Register a Web App in Firebase Console to get the correct appId
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDXPRpuWsEQyoLKu7Gsev8SNDPhQpT3PHo',
    authDomain: 'bloodlink-ai-a2724.firebaseapp.com',
    databaseURL: 'https://bloodlink-ai-a2724-default-rtdb.firebaseio.com',
    projectId: 'bloodlink-ai-a2724',
    storageBucket: 'bloodlink-ai-a2724.firebasestorage.app',
    messagingSenderId: '775881883324',
    appId: '1:775881883324:web:000000000000000000000000',
  );

  /// Android configuration — matches google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDXPRpuWsEQyoLKu7Gsev8SNDPhQpT3PHo',
    authDomain: 'bloodlink-ai-a2724.firebaseapp.com',
    databaseURL: 'https://bloodlink-ai-a2724-default-rtdb.firebaseio.com',
    projectId: 'bloodlink-ai-a2724',
    storageBucket: 'bloodlink-ai-a2724.firebasestorage.app',
    messagingSenderId: '775881883324',
    appId: '1:775881883324:android:bce61a8232ef334ccddab9',
  );
}
