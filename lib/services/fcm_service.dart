import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📱 Background message: ${message.notification?.title}');
}

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static String? _currentToken;
  
  static Future<void> initialize() async {
    try {
      print('🔔 Initializing FCM Service...');
      
      // Check if user has disabled push notifications in settings
      final prefs = await SharedPreferences.getInstance();
      final pushEnabled = prefs.getBool('push_notifications') ?? true;
      if (!pushEnabled) {
        print('ℹ️ Push notifications disabled by user, skipping FCM init');
        return;
      }
      
      // Request permission
      await _requestPermission();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        print('📱 FCM Token: $token');
        await _registerToken(token);
      }
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('📱 FCM Token refreshed: $newToken');
        _currentToken = newToken;
        _registerToken(newToken);
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      
      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
      // Check if app was opened from a notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
      
      print('✅ FCM Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing FCM: $e');
    }
  }
  
  static Future<void> _requestPermission() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM Permission granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ FCM Permission provisional');
      } else {
        print('❌ FCM Permission denied');
      }
    } catch (e) {
      print('❌ Error requesting FCM permission: $e');
    }
  }
  
  static Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          print('🔔 Notification tapped: ${details.payload}');
          // TODO: Navigate to relevant screen based on payload
        },
      );
      
      // Create high importance notification channel
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Error initializing local notifications: $e');
    }
  }
  
  static Future<void> _registerToken(String token) async {
    try {
      final response = await ApiService.post('/notifications/fcm/register/', {
        'token': token,
        'device_type': Platform.isAndroid ? 'android' : 'ios',
        'device_name': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      });
      
      if (response['success'] == true) {
        print('✅ FCM token registered successfully');
      } else {
        print('⚠️ FCM token registration response: $response');
      }
    } catch (e) {
      print('❌ Error registering FCM token: $e');
    }
  }
  
  static Future<void> unregisterToken() async {
    if (_currentToken == null) return;
    
    try {
      await ApiService.post('/notifications/fcm/unregister/', {
        'token': _currentToken,
      });
      print('✅ FCM token unregistered');
    } catch (e) {
      print('❌ Error unregistering FCM token: $e');
    }
  }
  
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 Foreground message received');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Data: ${message.data}');
    
    // Show local notification when app is in foreground
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data.toString(),
    );
  }
  
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('🔔 Notification tapped');
    print('   Data: ${message.data}');
    
    // TODO: Navigate to relevant screen based on message.data
    // Example:
    // final type = message.data['type'];
    // if (type == 'announcement') {
    //   final announcementId = message.data['announcement_id'];
    //   // Navigate to announcement detail screen
    // } else if (type == 'leave') {
    //   // Navigate to leave detail screen
    // }
  }
  
  static Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      _currentToken = null;
      print('✅ FCM token deleted');
    } catch (e) {
      print('❌ Error deleting FCM token: $e');
    }
  }
}
