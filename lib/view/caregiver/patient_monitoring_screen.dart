import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/mood_entry_model.dart';
import '../../core/models/sos_alert_model.dart';
import 'patient_detail_screen.dart';

class PatientMonitoringScreen extends StatefulWidget {
  const PatientMonitoringScreen({super.key});

  @override
  State<PatientMonitoringScreen> createState() =>
      _PatientMonitoringScreenState();
}

class _PatientMonitoringScreenState extends State<PatientMonitoringScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  String? _error;
  List<UserModel> _patients = [];
  List<SOSAlertModel> _todayAlerts = [];
  Map<String, List<MoodEntryModel>> _patientMoods = {};
  String _selectedTimeframe = 'Today';

  @override
  void initState() {
    super.initState();
    _loadMonitoringData();
  }

  getMissedNotifications(String patientId) async {
    try {} catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMonitoringData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Load patients assigned to this caregiver
      final patients = await _firestoreService.getCaregiverPatients(
        currentUser.uid,
      );

      // Load today's alerts for all patients
      final todayAlerts = <SOSAlertModel>[];
      final patientMoods = <String, List<MoodEntryModel>>{};

      for (final patient in patients) {
        // Get today's alerts
        final alerts = await _firestoreService.getActiveSosAlerts(patient.id);
        todayAlerts.addAll(alerts);

        // Get recent mood entries
        final moods = await _firestoreService.getRecentMoodEntries(
          patient.id,
          7,
        );

        patientMoods[patient.id] = moods;
      }

      setState(() {
        _patients = patients;
        _todayAlerts = todayAlerts;
        _patientMoods = patientMoods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Patient Monitoring', style: AppStyles.titleLarge),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Patient Monitoring', style: AppStyles.titleLarge),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                'Error loading monitoring data',
                style: AppStyles.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_error!, style: AppStyles.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMonitoringData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final activePatients = _patients.where((p) => p.isActive).length;
    final avgMoodScore = _calculateAverageMoodScore();
    final completedTasks = _calculateCompletedTasksPercentage();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Patient Monitoring', style: AppStyles.titleLarge),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _selectedTimeframe = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Today', child: Text('Today')),
              const PopupMenuItem(value: 'This Week', child: Text('This Week')),
              const PopupMenuItem(
                value: 'This Month',
                child: Text('This Month'),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedTimeframe,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMonitoringData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Active Patients',
                      activePatients.toString(),
                      Icons.people,
                      AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Alerts Today',
                      _todayAlerts.length.toString(),
                      Icons.warning,
                      AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Avg Mood Score',
                      avgMoodScore.toStringAsFixed(1),
                      Icons.mood,
                      AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Completed Tasks',
                      '${completedTasks.toStringAsFixed(0)}%',
                      Icons.check_circle,
                      AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Real-time Status
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppStyles.elevatedCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Real-time Status', style: AppStyles.titleMedium),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live',
                          style: AppStyles.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_patients.isNotEmpty)
                      ..._patients.map(
                        (patient) => _buildPatientStatusCard(patient),
                      )
                    else
                      Center(
                        child: Text(
                          'No patients assigned',
                          style: AppStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Activity Timeline
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppStyles.elevatedCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Activity', style: AppStyles.titleMedium),
                    const SizedBox(height: 16),
                    ..._buildRecentActivityItems(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Critical Alerts
              if (_todayAlerts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.elevatedCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Critical Alerts', style: AppStyles.titleMedium),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_todayAlerts.where((a) => !a.isResolved).length} Active',
                              style: AppStyles.bodySmall.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._todayAlerts
                          .take(3)
                          .map((alert) => _buildAlertCard(alert)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientStatusCard(UserModel patient) {
    final patientMoods = _patientMoods[patient.id] ?? [];
    final moodScore = patientMoods.isNotEmpty ? patientMoods.first.score : 5.0;
    final lastActivity = patient.isActive
        ? 'Active now'
        : _getLastSeenText(patient.lastActive);
    final hasAlert = _todayAlerts.any(
      (alert) => alert.userId == patient.id && !alert.isResolved,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientDetailScreen(patient: patient),
            ),
          );
        },
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: patient.profileImageUrl != null
                      ? NetworkImage(patient.profileImageUrl!)
                      : null,
                  child: patient.profileImageUrl == null
                      ? Text(
                          patient.name[0].toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: patient.isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: AppStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    lastActivity,
                    style: AppStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mood,
                      size: 16,
                      color: _getMoodColor(moodScore.toInt()),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      moodScore.toStringAsFixed(1),
                      style: TextStyle(
                        color: _getMoodColor(moodScore.toInt()),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (hasAlert)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Alert',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
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

  List<Widget> _buildRecentActivityItems() {
    final activities = <Widget>[];

    // Add mood entries
    for (final patient in _patients) {
      final moods = _patientMoods[patient.id] ?? [];
      if (moods.isNotEmpty) {
        final latestMood = moods.first;
        activities.add(
          _buildTimelineItem(
            '${patient.name} logged mood: ${_getMoodText(latestMood.score)}',
            _getTimeAgoText(latestMood.timestamp),
            Icons.mood,
            AppColors.accent,
          ),
        );
      }
    }

    // Add alerts
    for (final alert in _todayAlerts.take(2)) {
      final patient = _patients.firstWhere(
        (p) => p.id == alert.userId,
        orElse: () => UserModel(
          id: alert.userId,
          name: 'Unknown Patient',
          email: '',
          role: 'patient',

          createdAt: DateTime.now(),
        ),
      );

      activities.add(
        _buildTimelineItem(
          '${patient.name} - ${alert.priority.toUpperCase()} alert',
          _getTimeAgoText(alert.timestamp),
          Icons.warning,
          _getPriorityColor(alert.priority),
        ),
      );
    }

    if (activities.isEmpty) {
      activities.add(
        Center(
          child: Text(
            'No recent activity',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return activities.take(5).toList();
  }

  Widget _buildTimelineItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(SOSAlertModel alert) {
    final patient = _patients.firstWhere(
      (p) => p.id == alert.userId,
      orElse: () => UserModel(
        id: alert.userId,
        name: 'Unknown Patient',
        email: '',
        role: 'patient',

        createdAt: DateTime.now(),
      ),
    );

    final color = _getPriorityColor(alert.priority);
    final isActive = !alert.isResolved;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.warning : Icons.info_outline,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${alert.priority.toUpperCase()} Alert',
                      style: AppStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Patient: ${patient.name}',
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTimeAgoText(alert.timestamp),
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            ElevatedButton(
              onPressed: () => _resolveAlert(alert),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size(60, 32),
              ),
              child: const Text('Resolve', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  double _calculateAverageMoodScore() {
    final allMoods = _patientMoods.values.expand((moods) => moods).toList();
    if (allMoods.isEmpty) return 0.0;

    final sum = allMoods.map((mood) => mood.score).reduce((a, b) => a + b);
    return sum / allMoods.length;
  }

  double _calculateCompletedTasksPercentage() {
    // This would be calculated based on actual task completion data
    // For now, return a placeholder value
    return 85.0;
  }

  Color _getMoodColor(int moodScore) {
    if (moodScore >= 8) return AppColors.success;
    if (moodScore >= 6) return AppColors.accent;
    if (moodScore >= 4) return AppColors.warning;
    return AppColors.danger;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.green;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getMoodText(double score) {
    if (score >= 8) return 'Very Happy';
    if (score >= 6) return 'Happy';
    if (score >= 4) return 'Neutral';
    if (score >= 2) return 'Sad';
    return 'Very Sad';
  }

  String _getLastSeenText(DateTime? lastActive) {
    if (lastActive == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours}h ago';
    } else {
      return 'Last seen ${difference.inDays}d ago';
    }
  }

  String _getTimeAgoText(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _resolveAlert(SOSAlertModel alert) async {
    try {
      await _firestoreService.resolveSOSAlert(alert.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Alert resolved successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      // Reload monitoring data
      _loadMonitoringData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resolving alert: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
