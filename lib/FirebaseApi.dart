import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _configureFirebaseListeners();
  }


  void _configureFirebaseListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        _showNotification(message.notification);
        print('Message also contained a notification: ${message.notification}');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      // Handle the notification that was opened
    });
  }

  void _showNotification(RemoteNotification? notification) {
    if (notification != null) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your_channel_id',
        'your_channel_name',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        showWhen: false,
    );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
      _flutterLocalNotificationsPlugin.show(
        0,
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: 'item x',
      );
    }
  }

  Future<void> saveFCMToken(String uid) async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      // Save the token in the database
      // updateUserToken(uid, token); // Implement this function
    }
  }
}
