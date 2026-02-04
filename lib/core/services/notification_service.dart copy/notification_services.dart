import 'dart:convert';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class NotificationServices {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  void firebaseInit(BuildContext context) {
    FirebaseMessaging.onMessage.listen((message) {
      print('Message: ${message.notification!.title}');
      initLocalNotification(context, message);
      showNotification(message);
    });
  }

  void initLocalNotification(
      BuildContext context, RemoteMessage message) async {
    var androidIntializationSetting =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    var iosIntializationSetting = const DarwinInitializationSettings();

    var initializationSettings = InitializationSettings(
      android: androidIntializationSetting,
      iOS: iosIntializationSetting,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
      
        print('Notification Received: $details');
      },
    );
  }

  Future<void> showNotification(RemoteMessage message) async {
    try {
      AndroidNotificationChannel channel = AndroidNotificationChannel(
        Random.secure().nextInt(100000).toString(),
        'High Importance Notifications',
        importance: Importance.max,
      );

      AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: 'This channel is used for important notifications',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );

      DarwinNotificationDetails iosNotificationDetails =
          const DarwinNotificationDetails();

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        message.notification?.title ?? 'No Title',
        message.notification?.body ?? 'No Body',
        notificationDetails,
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  Future<String> getAccessToken() async {
    // String serviceAccountPath = '/assets/notification.json';
    // Load service account credentials from file
    final jsonString =
        await rootBundle.loadString('assets/service_key/service_key.json');
    final serviceAccountCredentials = jsonDecode(jsonString);

    // Define the scopes you need (adjust as needed for your Google services)
    final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

    // Get credentials
    var accountCredentials =
        ServiceAccountCredentials.fromJson(serviceAccountCredentials);

    // Use the AuthClient to authenticate the service account and get the token
    var client = http.Client();
    var authClient = await clientViaServiceAccount(accountCredentials, scopes,
        baseClient: client); // baseClient is a named argument

    // Get access token
    var credentials = authClient.credentials;
    var accessToken = credentials.accessToken.data;

    // Close the client after use
    authClient.close();

    print('Access token: $accessToken');
    return accessToken;
  }

  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission: ${settings.authorizationStatus}');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print(
          'User granted provisional permission: ${settings.authorizationStatus}');
    } else {
      AppSettings.openAppSettings();
      print('User did not grant permission: ${settings.authorizationStatus}');
    }
  }

  Future<String?> getNotificationToken() async {
    String? token = await messaging.getToken();
    print('Token: $token');
    return token;
  }

  void isTokenRefresh() {
    messaging.onTokenRefresh.listen((event) {
      print('Token Refreshed: $event');
    });
  }



  void setupInteractMessage(BuildContext context) async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
  
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
    
    });
  }

  Future<void> sendNotification(
    String value,
    String bearerToken,
    String message,
    String title,
  ) async {
    try {
      var headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      };

      var request = http.Request(
        'POST',
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/alzmate-8c68b/messages:send',
        ),
      );

      request.body = json.encode({
        "message": {
          "token": value,
          "notification": {"body": message, "title": title},
        },
      });

      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        print("Notification sent successfully!");
      } else {
        print("Failed to send notification: ${response.reasonPhrase}");
      }
    } catch (e) {
      print("Error occurred while sending notification: $e");
    }
  }
}
