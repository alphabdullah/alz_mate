import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../shared/settings_screen.dart';
import 'dashboard_screen.dart';
import 'patient_profile_screen.dart';
import 'mood_tracking_screen.dart';
import 'journal_screen.dart';
import 'brain_games_screen.dart';
import 'qr_code_screen.dart';
import 'face_recognition_screen.dart';
import 'sos_button_screen.dart';
import 'chat_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const PatientToolsScreen(),
    const ChatScreen(),
    const PatientProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Tools'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class PatientToolsScreen extends StatelessWidget {
  const PatientToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Tools'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings, color: AppColors.text),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Health & Wellness', style: AppStyles.titleMedium),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.15,
              children: [
                _buildToolCard(
                  context,
                  'Mood Tracking',
                  Icons.mood,
                  AppColors.primary,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MoodTrackingScreen(),
                    ),
                  ),
                ),
                _buildToolCard(
                  context,
                  'Journal',
                  Icons.book,
                  AppColors.accent,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JournalScreen()),
                  ),
                ),
                _buildToolCard(
                  context,
                  'Brain Games',
                  Icons.psychology,
                  AppColors.success,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BrainGamesScreen()),
                  ),
                ),
                _buildToolCard(
                  context,
                  'SOS Alert',
                  Icons.emergency,
                  AppColors.danger,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SosButtonScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Memory Aids', style: AppStyles.titleMedium),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.15,
              children: [
                _buildToolCard(
                  context,
                  'QR Codes',
                  Icons.qr_code,
                  AppColors.warning,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrCodeScreen()),
                  ),
                ),
                _buildToolCard(
                  context,
                  'Face Recognition',
                  Icons.face,
                  AppColors.info,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FaceRecognitionScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppStyles.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
