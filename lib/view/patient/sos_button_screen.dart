import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/sos_alert_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/custom_button.dart';

class SosButtonScreen extends StatefulWidget {
  const SosButtonScreen({super.key});

  @override
  State<SosButtonScreen> createState() => _SosButtonScreenState();
}

class _SosButtonScreenState extends State<SosButtonScreen>
    with TickerProviderStateMixin {
  bool _isEmergencyActive = false;
  bool _isSendingAlert = false;
  int _countdown = 0;
  List<SOSAlertModel> _recentAlerts = [];
  bool _isLoading = false;

  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _loadRecentAlerts();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentAlerts() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      if (authService.currentUser != null) {
        final alerts = await firestoreService.getSosAlertsByUserId(
          authService.currentUser!.uid,
        );
        setState(() => _recentAlerts = alerts.take(5).toList());
      }
    } catch (e) {
      _showSnackBar('Error loading alerts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _activateEmergency() async {
    if (_isEmergencyActive || _isSendingAlert) return;

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }

    setState(() {
      _isEmergencyActive = true;
      _countdown = 5;
    });

    _pulseController.repeat(reverse: true);
    _scaleController.forward();

    for (int i = 5; i > 0; i--) {
      if (!_isEmergencyActive) break;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (_isEmergencyActive) await _sendSosAlert();
  }

  void _cancelEmergency() {
    setState(() {
      _isEmergencyActive = false;
      _countdown = 0;
    });
    _pulseController.stop();
    _scaleController.reverse();
  }

  Future<void> _sendSosAlert() async {
    setState(() => _isSendingAlert = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final locationService = Provider.of<LocationService>(
        context,
        listen: false,
      );
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );

      final user = authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final location = await locationService.getCurrentLocation();

      final sosAlert = SOSAlertModel(
        id: '',
        userId: user.uid,
        timestamp: DateTime.now(),
        latitude: location.latitude,
        longitude: location.longitude,
        address: '',
        isResolved: false,
        priority: 'high',
        createdAt: DateTime.now(),
      );

      final alertId = await firestoreService.createSosAlert(sosAlert);
      final savedAlert = sosAlert.copyWith(id: alertId);

      await notificationService.sendEmergencyNotifications(savedAlert);

      setState(() {
        _recentAlerts.insert(0, savedAlert);
        _isEmergencyActive = false;
        _countdown = 0;
      });

      _pulseController.stop();
      _scaleController.reverse();

      _showSnackBar('Emergency alert sent successfully!', success: true);
      _showAlertSentDialog();
    } catch (e) {
      _cancelEmergency();
      _showSnackBar('Error sending alert: $e');
    } finally {
      setState(() => _isSendingAlert = false);
    }
  }

  Future<void> _resolveAlert(String alertId) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      await firestoreService.updateSosAlert(alertId, {
        'isResolved': true,
        'resolvedAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });

      final index = _recentAlerts.indexWhere((alert) => alert.id == alertId);
      if (index != -1) {
        setState(() {
          _recentAlerts[index] = _recentAlerts[index].copyWith(
            isResolved: true,
            resolvedAt: DateTime.now(),
          );
        });
      }

      _showSnackBar('Alert resolved successfully!', success: true);
    } catch (e) {
      _showSnackBar('Error resolving alert: $e');
    }
  }

  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ),
    );
  }

  void _showAlertSentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Alert Sent'),
        content: const Text(
          'Your emergency alert has been sent to contacts. Help is on the way.',
        ),
        actions: [
          CustomButton(
            text: 'OK',
            onPressed: () => Navigator.pop(context),
            width: 100,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSosButtonSection(),
            const SizedBox(height: 24),
            _buildInstructionSection(),
            const SizedBox(height: 24),
            _buildRecentAlertsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSosButtonSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AppStyles.elevatedCard,
      child: Column(
        children: [
          if (_isEmergencyActive) ...[
            const Text(
              'Emergency Alert Activating',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sending alert in $_countdown seconds',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
          ] else ...[
            const Text(
              'Emergency SOS Button',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Press and hold for 5 seconds to send an emergency alert',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
          ],
          _buildAnimatedSosButton(),
          const SizedBox(height: 32),
          if (_isEmergencyActive)
            CustomButton(
              text: 'Cancel Alert',
              onPressed: _cancelEmergency,
              backgroundColor: AppColors.textSecondary,
              width: 150,
            ),
          if (_isSendingAlert) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Sending emergency alert...'),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedSosButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isEmergencyActive
                  ? _pulseAnimation.value * _scaleAnimation.value
                  : _scaleAnimation.value,
              child: GestureDetector(
                onTapDown: (_) => _scaleController.forward(),
                onTapUp: (_) => _scaleController.reverse(),
                onTapCancel: () => _scaleController.reverse(),
                onLongPress: _activateEmergency,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.danger.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: _isEmergencyActive ? 10 : 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emergency,
                        size: 60,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isEmergencyActive)
                        Text(
                          '$_countdown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInstructionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to Use Emergency SOS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildInstructionItem(
            'Press and hold the SOS button for 5 seconds',
            Icons.touch_app,
          ),
          _buildInstructionItem(
            'A countdown will start - you can cancel anytime',
            Icons.timer,
          ),
          _buildInstructionItem(
            'After countdown, alert is sent to emergency contacts',
            Icons.send,
          ),
          _buildInstructionItem(
            'Your location will be shared with the alert',
            Icons.location_on,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Alerts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_recentAlerts.isEmpty)
            const Center(
              child: Text(
                'No emergency alerts sent',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentAlerts.length,
              itemBuilder: (context, index) {
                final alert = _recentAlerts[index];
                return _buildAlertCard(alert);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(SOSAlertModel alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alert.isResolved
            ? AppColors.success.withOpacity(0.05)
            : AppColors.danger.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isResolved
              ? AppColors.success.withOpacity(0.2)
              : AppColors.danger.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: alert.isResolved
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  alert.isResolved ? Icons.check_circle : Icons.emergency,
                  color: alert.isResolved
                      ? AppColors.success
                      : AppColors.danger,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.priorityDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      alert.statusText,
                      style: TextStyle(
                        color: alert.isResolved
                            ? AppColors.success
                            : AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!alert.isResolved)
                TextButton(
                  onPressed: () => _resolveAlert(alert.id),
                  child: const Text('Resolve'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.notes ?? 'Emergency alert',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                alert.timeAgoText,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.location_on,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                alert.locationString,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
