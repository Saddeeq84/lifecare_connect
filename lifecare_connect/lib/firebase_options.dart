// This file contains Firebase configuration for LifeCare Connect
// DO NOT commit real API keys to version control
// Use environment variables or secure configuration management

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCbkMhD-AYiXzNwdNig3p1COux92PuvZT8', // New secure browser key
    appId: '1:815876091951:web:fd346056ca8453611616da',  // From previous config
    messagingSenderId: '815876091951', // From previous config
    projectId: 'lifecare-connect',
    authDomain: 'lifecare-connect.firebaseapp.com',
    storageBucket: 'lifecare-connect.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBe60Mz6UiP9YTS534vZCTchRN5OwiQPU4', // New secure Android key
    appId: '1:815876091951:android:4d8c9b5c1616da',   // Android app ID
    messagingSenderId: '815876091951',
    projectId: 'lifecare-connect',
    storageBucket: 'lifecare-connect.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDidpqMudfCErWqGIoAG0J2fnoWXbCeXqA', // New secure iOS key
    appId: '1:815876091951:ios:fd346056ca8453611616da',   // iOS app ID
    messagingSenderId: '815876091951',
    projectId: 'lifecare-connect',
    iosBundleId: 'com.lifecare.connect',
    storageBucket: 'lifecare-connect.appspot.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY_HERE', // Replace with environment variable
    appId: 'YOUR_MACOS_APP_ID_HERE',   // Replace with environment variable
    messagingSenderId: 'YOUR_SENDER_ID_HERE', // Replace with environment variable
    projectId: 'lifecare-connect',
    storageBucket: 'lifecare-connect.appspot.com',
    iosBundleId: 'com.lifecare.connect',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_WINDOWS_API_KEY_HERE', // Replace with environment variable
    appId: 'YOUR_WINDOWS_APP_ID_HERE',   // Replace with environment variable
    messagingSenderId: 'YOUR_SENDER_ID_HERE', // Replace with environment variable
    projectId: 'lifecare-connect',
    storageBucket: 'lifecare-connect.appspot.com',
  );
}