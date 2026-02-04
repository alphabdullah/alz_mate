import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/caregiver_application_model.dart';
import '../../core/models/user_model.dart';
import '../../widgets/custom_button.dart';

class CaregiverApplicationDetailPage extends StatefulWidget {
  final CaregiverApplicationModel application;
  final VoidCallback onStatusChanged;

  const CaregiverApplicationDetailPage({
    super.key,
    required this.application,
    required this.onStatusChanged,
  });

  @override
  State<CaregiverApplicationDetailPage> createState() =>
      _CaregiverApplicationDetailPageState();
}

class _CaregiverApplicationDetailPageState
    extends State<CaregiverApplicationDetailPage> {
  bool _isProcessing = false;
  final _rejectionReasonController = TextEditingController();

  Future<void> _approveApplication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Application'),
        content: const Text(
          'Are you sure you want to approve this caregiver application?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      final currentUser = Provider.of<UserModel?>(context, listen: false);

      await firestoreService.approveCaregiverApplication(
        widget.application.id,
        currentUser?.id ?? 'admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application approved successfully')),
        );
        widget.onStatusChanged();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _rejectApplication() async {
    if (_rejectionReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rejection reason')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: const Text(
          'Are you sure you want to reject this caregiver application?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      final currentUser = Provider.of<UserModel?>(context, listen: false);

      await firestoreService.rejectCaregiverApplication(
        widget.application.id,
        currentUser?.id ?? 'admin',
        _rejectionReasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application rejected')),
        );
        widget.onStatusChanged();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _openDocument(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildDocumentTile(String title, String? url) {
    return ListTile(
      leading: const Icon(Icons.description),
      title: Text(title),
      trailing: url != null
          ? IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openDocument(url),
            )
          : const Text('Not uploaded', style: TextStyle(color: Colors.grey)),
      enabled: url != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;

    return Scaffold(
      appBar: AppBar(
        title: Text('Application: ${app.fullName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personal Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personal Information', style: AppStyles.titleMedium),
                    const SizedBox(height: 16),
                    _buildInfoRow('Full Name', app.fullName),
                    _buildInfoRow('Email', app.email),
                    _buildInfoRow('Phone', app.phoneNumber),
                    _buildInfoRow('Date of Birth',
                        '${app.dateOfBirth.day}/${app.dateOfBirth.month}/${app.dateOfBirth.year}'),
                    _buildInfoRow('Address', app.fullAddress),
                    _buildInfoRow('City', app.city),
                    _buildInfoRow('Province', app.province),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Exam Results
            if (app.hasCompletedExam)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Exam Results', style: AppStyles.titleMedium),
                      const SizedBox(height: 16),
                      _buildInfoRow('Score',
                          '${app.examScore}/${app.examTotalQuestions}'),
                      _buildInfoRow('Percentage',
                          '${app.examPercentage?.toStringAsFixed(1)}%'),
                      _buildInfoRow('Completed At',
                          app.examCompletedAt?.toString() ?? 'N/A'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Documents
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Documents', style: AppStyles.titleMedium),
                  ),
                  const Divider(),
                  _buildDocumentTile(
                    'Matriculation Certificate',
                    app.matriculationCertificateUrl,
                  ),
                  _buildDocumentTile(
                    'Intermediate Certificate',
                    app.intermediateCertificateUrl,
                  ),
                  _buildDocumentTile(
                    'Graduation Degree',
                    app.graduationDegreeUrl,
                  ),
                  _buildDocumentTile(
                    'Work Experience',
                    app.workExperienceDocumentsUrl,
                  ),
                  _buildDocumentTile(
                    'Caregiving Certificates',
                    app.caregivingCertificatesUrl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status and Actions
            if (app.isPending) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _rejectionReasonController,
                        decoration: const InputDecoration(
                          labelText: 'Rejection Reason (if rejecting)',
                          hintText: 'Enter reason for rejection',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      // Mobile-friendly vertical button layout
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          text: 'Approve Application',
                          onPressed: _approveApplication,
                          backgroundColor: AppColors.success,
                          isLoading: _isProcessing,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          text: 'Reject Application',
                          onPressed: _rejectApplication,
                          backgroundColor: AppColors.danger,
                          isLoading: _isProcessing,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${app.status.toUpperCase()}',
                          style: AppStyles.titleMedium),
                      if (app.reviewedAt != null)
                        _buildInfoRow('Reviewed At', app.reviewedAt.toString()),
                      if (app.rejectionReason != null)
                        _buildInfoRow('Rejection Reason', app.rejectionReason!),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }
}

