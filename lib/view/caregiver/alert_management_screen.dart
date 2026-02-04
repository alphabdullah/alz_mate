import 'dart:developer';

import 'package:alz_mate/core/services/notification_service.dart%20copy/notification_services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/sos_alert_model.dart';
import '../../core/models/user_model.dart';

class AlertManagementScreen extends StatefulWidget {
  const AlertManagementScreen({super.key});

  @override
  State<AlertManagementScreen> createState() => _AlertManagementScreenState();
}

class _AlertManagementScreenState extends State<AlertManagementScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<SOSAlertModel> _allAlerts = [];
  List<SOSAlertModel> _activeAlerts = [];
  List<SOSAlertModel> _resolvedAlerts = [];
  List<UserModel> _patients = [];
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
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

      // Load all alerts for all patients
      final allAlerts = <SOSAlertModel>[];
      for (final patient in patients) {
        final patientAlerts = await _firestoreService.getSOSAlerts(patient.id);
        allAlerts.addAll(patientAlerts);
      }

      // Sort alerts by timestamp (newest first)
      allAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final activeAlerts = allAlerts
          .where((alert) => !alert.isResolved)
          .toList();
      final resolvedAlerts = allAlerts
          .where((alert) => alert.isResolved)
          .toList();

      setState(() {
        _patients = patients;
        _allAlerts = allAlerts;
        _activeAlerts = activeAlerts;
        _resolvedAlerts = resolvedAlerts;
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
          title: Text('Alert Management', style: AppStyles.titleLarge),
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
          title: Text('Alert Management', style: AppStyles.titleLarge),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              Text('Error loading alerts', style: AppStyles.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, style: AppStyles.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAlerts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Alert Management', style: AppStyles.titleLarge),
        actions: [
          IconButton(
            onPressed: _showFilterOptions,
            icon: const Icon(Icons.filter_list, color: AppColors.text),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: Column(
          children: [
            _buildSummaryCard(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAlertList(_activeAlerts),
                  _buildAlertList(_resolvedAlerts),
                  _buildAlertList(_allAlerts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final todayResolved = _resolvedAlerts.where((alert) {
      final today = DateTime.now();
      final alertDate = alert.resolvedAt ?? alert.timestamp;
      return alertDate.year == today.year &&
          alertDate.month == today.month &&
          alertDate.day == today.day;
    }).length;

    // Calculate average response time
    final resolvedWithTime = _resolvedAlerts.where(
      (alert) => alert.resolvedAt != null,
    );
    double avgResponseTime = 0;
    if (resolvedWithTime.isNotEmpty) {
      final totalMinutes = resolvedWithTime.fold<int>(0, (sum, alert) {
        final diff = alert.resolvedAt!.difference(alert.timestamp);
        return sum + diff.inMinutes;
      });
      avgResponseTime = totalMinutes / resolvedWithTime.length;
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Row(
        children: [
          _buildSummaryItem(
            'Active Alerts',
            _activeAlerts.length.toString(),
            AppColors.danger,
            Icons.warning,
          ),
          _divider(),
          _buildSummaryItem(
            'Resolved Today',
            todayResolved.toString(),
            AppColors.success,
            Icons.check_circle,
          ),
          _divider(),
          _buildSummaryItem(
            'Response Time',
            '${avgResponseTime.toStringAsFixed(1)} min',
            AppColors.primary,
            Icons.timer,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: AppStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: AppColors.border);

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppStyles.softShadow,
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.danger,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          color: AppColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Active'),
                if (_activeAlerts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.danger,
                      child: Text(
                        _activeAlerts.length.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Tab(text: 'Resolved'),
          const Tab(text: 'All'),
        ],
      ),
    );
  }

  Widget _buildAlertList(List<SOSAlertModel> alerts) {
    if (alerts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: alerts.length,
      itemBuilder: (_, index) => _buildAlertCard(alerts[index]),
    );
  }

  Widget _buildAlertCard(SOSAlertModel alert) {
    final isActive = !alert.isResolved;
    final color = _getPriorityColor(alert.priority);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppStyles.elevatedCard,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  child: Icon(Icons.warning, color: color),
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
                            style: AppStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.danger
                                  : AppColors.success,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'ACTIVE' : 'RESOLVED',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient: ${patient.name}',
                        style: AppStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        alert.locationString ?? 'Unknown location',
                        style: AppStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _getTimeAgoText(alert.timestamp),
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (alert.notes != null && alert.notes!.isNotEmpty) ...[
                  Text(
                    'Notes:',
                    style: AppStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(alert.notes!, style: AppStyles.bodyMedium),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reported: ${_formatDateTime(alert.timestamp)}',
                      style: AppStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (alert.resolvedAt != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Resolved: ${_formatDateTime(alert.resolvedAt!)}',
                        style: AppStyles.bodySmall.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (isActive)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _resolveAlert(alert),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Resolve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                        ),
                      ),
                    if (isActive) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewDetails(alert, patient),
                        icon: const Icon(Icons.info, size: 16),
                        label: const Text('Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_none,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Alerts Found',
            style: AppStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are currently no alerts to show.',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveAlert(SOSAlertModel alert) async {
    log("Alert Id: ${alert.id}");


    try {
      final token =  await NotificationServices().getAccessToken();
      final u = await _firestoreService.getUserById(alert.userId);      
      await _firestoreService.resolveSOSAlert(alert.id);
      await NotificationServices().sendNotification(u!.fcmToken!, token, '${u.name} alert has been resolved!', 'Alert Resolved');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${alert.priority.toUpperCase()} alert marked as resolved.',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      // Reload alerts
      _loadAlerts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resolving alert: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _viewDetails(SOSAlertModel alert, UserModel patient) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${alert.priority.toUpperCase()} Alert Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${patient.name}'),
            const SizedBox(height: 8),
            Text('Location: ${alert.locationString ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Reported At: ${_formatDateTime(alert.timestamp)}'),
            if (alert.notes != null && alert.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${alert.notes}'),
            ],
            if (alert.resolvedAt != null) ...[
              const SizedBox(height: 8),
              Text('Resolved At: ${_formatDateTime(alert.resolvedAt!)}'),
            ],
          ],
        ),
        actions: [
            TextButton(
            onPressed: () {
              openGoogleMaps(alert.latitude, alert.longitude);
            },
            child: const Text('View Location'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void openGoogleMaps(double lat, double lng) async {
  final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch Google Maps';
  }
}

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Alerts', style: AppStyles.titleMedium),
            const SizedBox(height: 16),
            for (var filter in ['All', 'Low', 'Medium', 'High', 'Critical'])
              ListTile(
                title: Text(filter),
                leading: Radio<String>(
                  value: filter,
                  groupValue: _selectedFilter,
                  onChanged: (value) {
                    setState(() => _selectedFilter = value!);
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
