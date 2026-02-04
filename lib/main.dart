import 'package:alz_mate/core/models/user_model.dart';
import 'package:alz_mate/core/services/sentiment_service.dart';
import 'package:alz_mate/core/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as t;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';

import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/location_service.dart';
import 'core/services/sos_service.dart';

import 'core/constants/app_colors.dart';
import 'view/shared/splash_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize timezone data
  t.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Karachi')); // 🔥 Add this line

  // Initialize core services (e.g., Firestore, Location, Notifications, SOS)
  await _initializeServices();

  // Initialize default admin user if it doesn't exist
  await _initializeDefaultAdmin();

  runApp(const AlzMateApp());
}


@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.notification!.title}');
  await Firebase.initializeApp();
}

Future<void> _initializeServices() async {
  try {
    await FirestoreService().init();
    await NotificationService().init();
    await LocationService().init();
    await SosService().init();
    print('All services initialized successfully');
  } catch (e) {
    print('Error initializing services: $e');
  }
}

Future<void> _initializeDefaultAdmin() async {
  try {
    await AuthService().initializeDefaultAdmin();
  } catch (e) {
    print('Error initializing default admin: $e');
  }
}

class AlzMateApp extends StatelessWidget {
  const AlzMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        /// ✅ Auth state mapped to UserModel
        StreamProvider<UserModel?>(
          create: (_) => AuthService().userModelStream,
          initialData: null,
        ),

        /// ✅ Singleton service providers
        Provider<AuthService>.value(value: AuthService()),
        Provider<FirestoreService>.value(value: FirestoreService()),
        Provider<NotificationService>.value(value: NotificationService()),
        Provider<SentimentService>.value(value: SentimentService()),
        Provider<StorageService>.value(value: StorageService()),
        Provider<LocationService>.value(value: LocationService()),
        Provider<SosService>.value(value: SosService()),
      ],
      child: MaterialApp(
        title: 'AlzMate',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Inter',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.text,
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
