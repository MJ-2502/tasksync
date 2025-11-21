
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';
import 'notification_service.dart';
import 'in_app_notification_service.dart';

class AppInitializer {
  static bool offlineMode = false;

  static Future<void> initialize() async {
    final connectivity = await Connectivity().checkConnectivity();
    offlineMode = connectivity == ConnectivityResult.none;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      if (!offlineMode) {
        await NotificationService().initialize();
        await InAppNotificationService().initialize();
      } else {
        developer.log('Starting TaskSync in offline mode');
      }

      await Future.delayed(const Duration(milliseconds: 500)); // stabilize init
    } on FirebaseException catch (e) {
      if (offlineMode) {
        developer.log('Firebase init deferred (offline)', error: e);
      } else {
        rethrow; // Allow UI to catch and show error if not offline fallback
      }
    } catch (e, stack) {
      if (offlineMode) {
        developer.log('Initialization fallback due to offline state', error: e, stackTrace: stack);
      } else {
        rethrow;
      }
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
