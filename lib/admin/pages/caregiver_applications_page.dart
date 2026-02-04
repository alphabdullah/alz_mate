import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/caregiver_application_model.dart';
import 'caregiver_application_detail_page.dart';

class CaregiverApplicationsPage extends StatefulWidget {
  const CaregiverApplicationsPage({super.key});

  @override
  State<CaregiverApplicationsPage> createState() =>
      _CaregiverApplicationsPageState();
}

class _CaregiverApplicationsPageState extends State<CaregiverApplicationsPage> {
  List<CaregiverApplicationModel> _applications = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'pending', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      _applications = await firestoreService.getAllCaregiverApplications();
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<CaregiverApplicationModel> get _filteredApplications {
    if (_filterStatus == 'all') return _applications;
    return _applications
        .where((app) => app.status == _filterStatus)
        .toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildApplicationCard(CaregiverApplicationModel application) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(application.status).withOpacity(0.1),
          child: Icon(
            application.status == 'pending'
                ? Icons.pending
                : application.status == 'approved'
                    ? Icons.check_circle
                    : Icons.cancel,
            color: _getStatusColor(application.status),
          ),
        ),
        title: Text(
          application.fullName,
          style: AppStyles.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(application.email),
            if (application.hasCompletedExam)
              Text(
                'Exam: ${application.examScore}/${application.examTotalQuestions} (${application.examPercentage?.toStringAsFixed(1)}%)',
                style: AppStyles.bodySmall,
              ),
            Text(
              'Status: ${application.status.toUpperCase()}',
              style: TextStyle(
                color: _getStatusColor(application.status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CaregiverApplicationDetailPage(
                application: application,
                onStatusChanged: _loadApplications,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Tabs - Mobile optimized with wrapping
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'Pending'),
                const SizedBox(width: 8),
                _buildFilterChip('approved', 'Approved'),
                const SizedBox(width: 8),
                _buildFilterChip('rejected', 'Rejected'),
              ],
            ),
          ),
        ),
        const Divider(),
        // Applications List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredApplications.isEmpty
                  ? Center(
                      child: Text(
                        'No applications found',
                        style: AppStyles.bodyMedium,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadApplications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredApplications.length,
                        itemBuilder: (context, index) {
                          return _buildApplicationCard(
                            _filteredApplications[index],
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = status);
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }
}

