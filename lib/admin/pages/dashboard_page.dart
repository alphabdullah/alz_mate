import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/firestore_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);

      // Get all users by querying each role
      final allPatients = await firestoreService.getUsersByRole('patient');
      final allCaregivers = await firestoreService.getUsersByRole('caregiver');
      debugPrint(allPatients.length.toString());
      debugPrint(allCaregivers.length.toString());
      // Filter out admin users from patients (in case any exist)
      final patientsCount = allPatients.length;
      final caregiversCount = allCaregivers.length;
      final approvedCaregivers = allCaregivers.where((u) => u.caregiverVerificationStatus == 'approved').toList();
      
      // Count linked/unlinked
      int linkedPatients = 0;
      int unlinkedPatients = 0;
      int linkedCaregivers = 0;
      int unlinkedCaregivers = 0;

      for (final patient in allPatients) {
        if (patient.caregiverIds != null && patient.caregiverIds!.isNotEmpty) {
          linkedPatients++;
        } else {
          unlinkedPatients++;
        }
      }

      for (final caregiver in approvedCaregivers) {
        if (caregiver.patientIds != null && caregiver.patientIds!.isNotEmpty) {
          linkedCaregivers++;
        } else {
          unlinkedCaregivers++;
        }
      }

      // Get pending applications
      final pendingApplications = await firestoreService.getPendingCaregiverApplications();

      print('Dashboard Stats:');
      print('Total Patients: $patientsCount');
      print('Approved Caregivers: ${approvedCaregivers.length}');
      print('Pending Applications: ${pendingApplications.length}');

      setState(() {
        _stats = {
          'totalPatients': patientsCount,
          'totalCaregivers': approvedCaregivers.length,
          'linkedPatients': linkedPatients,
          'unlinkedPatients': unlinkedPatients,
          'linkedCaregivers': linkedCaregivers,
          'unlinkedCaregivers': unlinkedCaregivers,
          'pendingApplications': pendingApplications.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard stats: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Flexible(
                child: Text(
                  value.toString(),
                  style: AppStyles.titleLarge.copyWith(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              title,
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _stats ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: AppStyles.titleLarge,
          ),
          const SizedBox(height: 24),
          // Stats Grid - Mobile optimized (2 columns)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard(
                'Total Patients',
                stats['totalPatients'] ?? 0,
                Icons.elderly,
                AppColors.primary,
              ),
              _buildStatCard(
                'Approved Caregivers',
                stats['totalCaregivers'] ?? 0,
                Icons.medical_services,
                AppColors.success,
              ),
              _buildStatCard(
                'Pending Applications',
                stats['pendingApplications'] ?? 0,
                Icons.pending_actions,
                AppColors.warning,
              ),
              _buildStatCard(
                'Linked Patients',
                stats['linkedPatients'] ?? 0,
                Icons.link,
                AppColors.info,
              ),
              _buildStatCard(
                'Unlinked Patients',
                stats['unlinkedPatients'] ?? 0,
                Icons.link_off,
                AppColors.danger,
              ),
              _buildStatCard(
                'Unlinked Caregivers',
                stats['unlinkedCaregivers'] ?? 0,
                Icons.person_off,
                AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


