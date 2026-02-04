import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import '../firebase_options.dart';
import '../core/models/user_model.dart';
import '../core/services/auth_service.dart';
import '../core/services/firestore_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/location_service.dart';
import '../core/services/sentiment_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/sos_service.dart';
import 'admin_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(const AdminBootstrap());
}

class AdminBootstrap extends StatelessWidget {
  const AdminBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<UserModel?>(
          create: (_) => AuthService().userModelStream,
          initialData: null,
        ),
        Provider<AuthService>.value(value: AuthService()),
        Provider<FirestoreService>.value(value: FirestoreService()),
        Provider<NotificationService>.value(value: NotificationService()),
        Provider<SentimentService>.value(value: SentimentService()),
        Provider<StorageService>.value(value: StorageService()),
        Provider<LocationService>.value(value: LocationService()),
        Provider<SosService>.value(value: SosService()),
      ],
      child: const AdminApp(),
    );
  }
}

