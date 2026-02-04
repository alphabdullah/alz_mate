import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/local_storage_service.dart';
import '../../widgets/custom_button.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalStorageService _storageService = LocalStorageService();

  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = true;
  bool _emergencyAlertsEnabled = true;
  String _selectedLanguage = 'English';
  String _selectedTheme = 'Light';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load settings from local storage
    // final notifications =
    //     await _storageService.getBool('notifications_enabled') ?? true;
    // final locationSharing =
    //     await _storageService.getBool('location_sharing_enabled') ?? true;
    // final emergencyAlerts =
    //     await _storageService.getBool('emergency_alerts_enabled') ?? true;
    // final language =
    //     await _storageService.getString('selected_language') ?? 'English';
    // final theme = await _storageService.getString('selected_theme') ?? 'Light';

    // setState(() {
    //   _notificationsEnabled = notifications;
    //   _locationSharingEnabled = locationSharing;
    //   _emergencyAlertsEnabled = emergencyAlerts;
    //   _selectedLanguage = language;
    //   _selectedTheme = theme;
    // });
  }

  Future<void> _saveSettings() async {
    // await _storageService.setBool(
    //   'notifications_enabled',
    //   _notificationsEnabled,
    // );
    // await _storageService.setBool(
    //   'location_sharing_enabled',
    //   _locationSharingEnabled,
    // );
    // await _storageService.setBool(
    //   'emergency_alerts_enabled',
    //   _emergencyAlertsEnabled,
    // );
    // await _storageService.setString('selected_language', _selectedLanguage);
    // await _storageService.setString('selected_theme', _selectedTheme);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: AppStyles.headlineLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Notifications', [
              _buildSwitchTile(
                'Push Notifications',
                'Receive notifications for reminders and alerts',
                _notificationsEnabled,
                (value) {
                  setState(() => _notificationsEnabled = value);
                  _saveSettings();
                },
              ),
              _buildSwitchTile(
                'Emergency Alerts',
                'Receive emergency SOS alerts',
                _emergencyAlertsEnabled,
                (value) {
                  setState(() => _emergencyAlertsEnabled = value);
                  _saveSettings();
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Privacy', [
              _buildSwitchTile(
                'Location Sharing',
                'Share location for emergency services',
                _locationSharingEnabled,
                (value) {
                  setState(() => _locationSharingEnabled = value);
                  _saveSettings();
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Preferences', [
              _buildDropdownTile(
                'Language',
                _selectedLanguage,
                ['English', 'Urdu', 'Arabic'],
                (value) {
                  setState(() => _selectedLanguage = value!);
                  _saveSettings();
                },
              ),
              _buildDropdownTile(
                'Theme',
                _selectedTheme,
                ['Light', 'Dark', 'System'],
                (value) {
                  setState(() => _selectedTheme = value!);
                  _saveSettings();
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Account', [
              _buildActionTile(
                'Change Password',
                'Update your account password',
                Icons.lock,
                () => _showChangePasswordDialog(),
              ),
              _buildActionTile(
                'Export Data',
                'Download your personal data',
                Icons.download,
                () => _exportData(),
              ),
              _buildActionTile(
                'Delete Account',
                'Permanently delete your account',
                Icons.delete_forever,
                () => _showDeleteAccountDialog(),
                isDestructive: true,
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection('Support', [
              _buildActionTile(
                'Help Center',
                'Get help and support',
                Icons.help,
                () => _openHelpCenter(),
              ),
              _buildActionTile(
                'Contact Us',
                'Send feedback or report issues',
                Icons.contact_support,
                () => _contactSupport(),
              ),
              _buildActionTile(
                'Privacy Policy',
                'Read our privacy policy',
                Icons.privacy_tip,
                () => _openPrivacyPolicy(),
              ),
            ]),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Sign Out',
                onPressed: () => _showSignOutDialog(),
                backgroundColor: AppColors.error,
                icon: Icons.logout,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Version 1.0.0',
                style: AppStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppStyles.titleMedium.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppStyles.bodyMedium.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
            underline: Container(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.text;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: AppStyles.bodyMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text(
          'This feature will be implemented in a future update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Data export feature coming soon'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Account deletion feature coming soon'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openHelpCenter() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Opening help center...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _contactSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Opening contact support...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _openPrivacyPolicy() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Opening privacy policy...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
