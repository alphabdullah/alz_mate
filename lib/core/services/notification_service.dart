import 'dart:developer';

import 'package:alz_mate/core/services/notification_service.dart%20copy/notification_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder_model.dart';
import '../models/sos_alert_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirestoreService _firestoreService = FirestoreService();

  bool _isInitialized = false;
  Future<void> init() async {
    await initialize(); // calls your existing initialize() method
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request notification permission on Android 13+
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    // Initialize Firebase messaging
    await _initializeFirebaseMessaging();

    _isInitialized = true;
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Request permission for iOS
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined or has not accepted permission');
    }

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Handling foreground message: ${message.messageId}');

    // Show local notification for foreground messages
    _showLocalNotification(
      title: message.notification?.title ?? 'AlzMate',
      body: message.notification?.body ?? 'You have a new notification',
      payload: message.data.toString(),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');
    // Handle navigation based on message data
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
    // Handle navigation based on payload
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'alzmate_channel',
      'AlzMate Notifications',
      channelDescription: 'Notifications for AlzMate app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> scheduleReminderNotification(ReminderModel reminder) async {
    if (!_isInitialized) await initialize();

    // Schedule local notification at the exact time the user chose (use their local wall-clock time)
    try {
      // Build TZDateTime from reminder's date/time in device local timezone so it fires at the set time
      final t = reminder.time;
      final scheduledDate = tz.TZDateTime(
        tz.local,
        t.year,
        t.month,
        t.day,
        t.hour,
        t.minute,
        0,
      );
      final now = tz.TZDateTime.now(tz.local);
      print('🕐 Reminder scheduled at: $scheduledDate (now: $now)');

      if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
        print('⚠️ Reminder time is in the past, skipping schedule');
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'reminder_channel',
        'Reminders',
        channelDescription: 'Medication and appointment reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = reminder.id.hashCode & 0x7FFFFFFF;
      await _localNotifications.zonedSchedule(
        notificationId,
        reminder.title,
        reminder.description ?? 'Time for your reminder',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: reminder.repeatDaily
            ? DateTimeComponents.time
            : DateTimeComponents.dateAndTime,
        payload: 'reminder:${reminder.id}',
      );
      print('✅ Local reminder scheduled for: $scheduledDate');

      if (reminder.repeatDaily) {
        await _scheduleRepeatingReminder(reminder);
      }
    } catch (e) {
      print('❌ Error scheduling reminder notification: $e');
      rethrow;
    }

    // Notify caregivers via FCM (do not block or fail the flow)
    try {
      final currentUserId = reminder.userId;
      final currentUser = AuthService().currentUser;
      final caregivers = await _firestoreService.getPatientCaregivers(currentUserId);
      final token = await NotificationServices().getAccessToken();
      for (final UserModel c in caregivers) {
        if (c.fcmToken != null && c.fcmToken!.isNotEmpty) {
          await NotificationServices().sendNotification(
            c.fcmToken!,
            token,
            '${currentUser?.displayName ?? "Patient"} has set a reminder for ${reminder.type} at ${reminder.time}',
            'Reminder Set by Patient',
          );
        }
      }
    } catch (e) {
      print('⚠️ Caregiver notify failed (reminder still scheduled): $e');
    }
  }


  Future<void> _scheduleRepeatingReminder(ReminderModel reminder) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'daily_reminder_channel',
        'Daily Reminders',
        channelDescription: 'Daily repeating reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        reminder.time.hour,
        reminder.time.minute,
        0,
      );

      if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      print('🔁 Scheduling daily reminder at: $scheduledDate');

      final notificationId = (reminder.id.hashCode & 0x7FFFFFFF) + 1000;
      await _localNotifications.zonedSchedule(
        notificationId,
        reminder.title,
        reminder.description ?? 'Daily reminder',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_reminder:${reminder.id}',
      );
    } catch (e) {
      print('❌ Error scheduling repeating reminder: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: payload,
      id: id,
    );
  }

  Future<void> sendSosAlertNotification(
    SOSAlertModel alert,
    List<UserModel> contacts,
  ) async {
    for (final contact in contacts) {
      // await _sendPushNotificationToUser(
      //   contact.id,
      //   'EMERGENCY ALERT',
      //   'Emergency alert from ${alert.userId} at ${alert.locationString ?? "Unknown"}',
      //   {
      //     'type': 'sos_alert',
      //     'alertId': alert.id,
      //     'location': alert.locationString ?? '',
      //     'userId': alert.userId,
      //   },
      // );
      final token = await NotificationServices().getAccessToken();
      await NotificationServices().sendNotification(token, contact.fcmToken!, 'Emergency alert from ${alert.userId} at ${alert.locationString ?? "Unknown"}', 'EMERGENCY ALERT');
    }
  }

  Future<void> cancelReminderNotification(String reminderId) async {
    try {
      final id = reminderId.hashCode & 0x7FFFFFFF;
      await _localNotifications.cancel(id);
      await _localNotifications.cancel(id + 1000);
    } catch (e) {
      print('Error canceling reminder notification: $e');
    }
  }

  Future<void> sendEmergencyNotifications(SOSAlertModel alert) async {
    try {
      // Get user data to find emergency contacts
      final user = await _firestoreService.getUserById(alert.userId);
      if (user == null) return;

      // Send local notification immediately
      // await _showLocalNotification(
      //   title: 'EMERGENCY ALERT',
      //   body: 'Emergency alert from ${user.name}',
      //   payload: 'emergency:${alert.id}',
      //   id: 999, // High priority ID
      // );
      final token = await NotificationServices().getAccessToken();

      // Get caregivers for this patient
      if (user.caregiverIds != null && user.caregiverIds!.isNotEmpty) {
        for (final caregiverId in user.caregiverIds!) {

          final u = await _firestoreService.getUserById(caregiverId);

          log("CareGover: ${u?.toJson()}");
          
          await NotificationServices().sendNotification(u!.fcmToken!, token, 'Emergency alert from ${user.name} at ${alert.locationString ?? "unknown location"}','EMERGENCY ALERT' );
          // await _sendPushNotificationToUser(
          //   caregiverId,
          //   'EMERGENCY ALERT',
          //   'Emergency alert from ${user.name} at ${alert.locationString ?? "unknown location"}',
          //   {
          //     'type': 'emergency',
          //     'alertId': alert.id,
          //     'userId': alert.userId,
          //     'location': alert.locationString ?? '',
          //   },
          // );
        }
      }

      // Send SMS to emergency contact if available
      if (user.emergencyContact != null) {
        await _sendEmergencySMS(user.emergencyContact!, user.name, alert);
      }
    } catch (e) {
      print('Error sending emergency notifications: $e');
    }
  }

 

  Future<void> _sendEmergencySMS(
    String phoneNumber,
    String userName,
    SOSAlertModel alert,
  ) async {
    try {
      // In a real implementation, you would integrate with SMS service like Twilio
      print('Sending emergency SMS to $phoneNumber for $userName');

      // Example SMS content
      final message =
          'EMERGENCY: $userName has activated an emergency alert. '
          'Location: ${alert.locationString ?? "Unknown"}. '
          'Time: ${alert.timestamp.toString()}. '
          'Please check on them immediately.';

      print('SMS Content: $message');

      // You would integrate with SMS service here
      // Example with Twilio:
      /*
      final response = await http.post(
        Uri.parse('https://api.twilio.com/2010-04-01/Accounts/YOUR_ACCOUNT_SID/Messages.json'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': 'YOUR_TWILIO_NUMBER',
          'To': phoneNumber,
          'Body': message,
        },
      );
      */
    } catch (e) {
      print('Error sending emergency SMS: $e');
    }
  }

  Future<void> sendMedicationReminder(
    ReminderModel reminder,
    UserModel user,
  ) async {
    await _showLocalNotification(
      title: 'Medication Reminder',
      body: '${user.name}, it\'s time for: ${reminder.title}',
      payload: 'medication:${reminder.id}',
    );
  }

  Future<void> sendAppointmentReminder(
    ReminderModel reminder,
    UserModel user,
  ) async {
    await _showLocalNotification(
      title: 'Appointment Reminder',
      body: '${user.name}, you have an appointment: ${reminder.title}',
      payload: 'appointment:${reminder.id}',
    );
  }

  Future<void> sendDailyCheckIn(String userId) async {
    try {
      final user = await _firestoreService.getUserById(userId);
      if (user == null) return;

      await _showLocalNotification(
        title: 'Daily Check-in',
        body: 'Hi ${user.name}! How are you feeling today?',
        payload: 'daily_checkin:$userId',
      );
    } catch (e) {
      print('Error sending daily check-in: $e');
    }
  }

  Future<void> sendCaregiverAlert(
    String caregiverId,
    String patientName,
    String alertType,
  ) async {
    await _showLocalNotification(
      title: 'Patient Alert',
      body: '$patientName needs attention: $alertType',
      payload: 'caregiver_alert:$caregiverId',
    );
  }

  Future<void> sendMoodTrackingReminder(String userId) async {
    try {
      final user = await _firestoreService.getUserById(userId);
      if (user == null) return;

      await _showLocalNotification(
        title: 'Mood Check',
        body: 'Hi ${user.name}! Don\'t forget to log your mood today.',
        payload: 'mood_reminder:$userId',
      );
    } catch (e) {
      print('Error sending mood tracking reminder: $e');
    }
  }

  Future<void> scheduleWeeklyReport(String userId) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'weekly_report_channel',
        'Weekly Reports',
        channelDescription: 'Weekly health and activity reports',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule for every Sunday at 9 AM
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        9,
      );

      // Find next Sunday
      while (scheduledDate.weekday != DateTime.sunday) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // If it's already past 9 AM on Sunday, schedule for next Sunday
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      }

      await _localNotifications.zonedSchedule(
        'weekly_report_$userId'.hashCode,
        'Weekly Health Report',
        'Your weekly health summary is ready!',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'weekly_report:$userId',
      );
    } catch (e) {
      print('Error scheduling weekly report: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  // Update FCM token in Firestore
  Future<void> updateFCMToken(String userId) async {
    try {
      final token = await getFCMToken();
      if (token != null) {
        await _firestoreService.updateUser(userId, {
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Future<void> sendCustomNotification({
  //   required String userId,
  //   required String title,
  //   required String body,
  //   Map<String, String>? data,
  // }) async {
  //   await _sendPushNotificationToUser(userId, title, body, data ?? {});
  // }
}
