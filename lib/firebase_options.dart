import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for Android. Please configure them via the Firebase CLI.',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for iOS. Please configure them via the Firebase CLI.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for macOS. Please configure them via the Firebase CLI.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for Windows. Please configure them via the Firebase CLI.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for Linux. Please configure them via the Firebase CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCbEIQF1xmD2K9VUqF-QFZjYTMH8x5VF2Y',
    authDomain: 'bankrulek-95bb5.firebaseapp.com',
    projectId: 'bankrulek-95bb5',
    storageBucket: 'bankrulek-95bb5.firebasestorage.app',
    messagingSenderId: '406579098743',
    appId: '1:406579098743:web:3df334acf3466f5e8562',
    measurementId: 'G-XN8YHOLCDN6',
  );
}
