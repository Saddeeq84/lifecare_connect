// Firebase configuration for LifeCare Connect
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
    apiKey: 'AIzaSyAAJqnlBCZJUQ6bGdfbiuVJHVflW4SuHhg',
    appId: '1:815876091951:web:fd346056ca8453611616da',
    messagingSenderId: '815876091951',
    projectId: 'lifecare-connect',
    authDomain: 'lifecare-connect.firebaseapp.com',
    storageBucket: 'lifecare-connect.firebasestorage.app',
    measurementId: 'G-XXXXXXXXXX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAAJqnlBCZJUQ6bGdfbiuVJHVflW4SuHhg',
    appId: '1:815876091951:android:fd346056ca8453611616da',
    messagingSenderId: '815876091951',
    projectId: 'lifecare-connect',
    storageBucket: 'lifecare-connect.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAJqnlBCZJUQ6bGdfbiuVJHVflW4SuHhg',
    appId: '1:815876091951:ios:fd346056ca8453611616da',
    messagingSenderId: '815876091951',
    projectId: 'lifecare-connect',
    storageBucket: 'lifecare-connect.appspot.com',
    iosClientId: '815876091951-0s9vb4h4euc6sq2s5dnlcn5leflu39uo.apps.googleusercontent.com',
    iosBundleId: 'com.rhemn.lifecare_connect',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAAJqnlBCZJUQ6bGdfbiuVJHVflW4SuHhg',
    appId: '1:815876091951:macos:fd346056ca8453611616da',
    messagingSenderId: '815876091951',
    projectId: 'lifecare-connect',
    storageBucket: 'lifecare-connect.appspot.com',
    iosClientId: '815876091951-0s9vb4h4euc6sq2s5dnlcn5leflu39uo.apps.googleusercontent.com',
    iosBundleId: 'com.rhemn.lifecare_connect',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAAJqnlBCZJUQ6bGdfbiuVJHVflW4SuHhg',
    appId: '1:815876091951:windows:fd346056ca8453611616da',
    messagingSenderId: '815876091951',
    projectId: 'lifecare-connect',
    authDomain: 'lifecare-connect.firebaseapp.com',
    storageBucket: 'lifecare-connect.appspot.com',
    measurementId: 'G-XXXXXXXXXX',
  );
}
