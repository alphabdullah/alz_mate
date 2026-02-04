import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/caregiver_application_model.dart';
import '../../widgets/custom_button.dart';
import '../auth/caregiver_detailed_registration_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CaregiverVerificationStatusScreen extends StatefulWidget {
  final String userId;
  final String verificationStatus;

  const CaregiverVerificationStatusScreen({
    super.key,
    required this.userId,
    required this.verificationStatus,
  });

  @override
  State<CaregiverVerificationStatusScreen> createState() =>
      _CaregiverVerificationStatusScreenState();
}

class _CaregiverVerificationStatusScreenState
    extends State<CaregiverVerificationStatusScreen> {
  CaregiverApplicationModel? _application;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplication();
  }

  Future<void> _loadApplication() async {
    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      _application =
          await firestoreService.getCaregiverApplicationByUserId(widget.userId);
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resubmitApplication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Navigate to registration screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CaregiverDetailedRegistrationScreen(
            email: user.email ?? '',
            password: '', // Will need to handle this differently
            name: user.displayName ?? '',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 80,
              color: AppColors.warning,
            ),
            const SizedBox(height: 24),
            Text(
              'Verification Pending',
              style: AppStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please wait while we are verifying your details.',
              style: AppStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (_application != null && _application!.hasCompletedExam) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Exam Completed',
                      style: AppStyles.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Score: ${_application!.examScore}/${_application!.examTotalQuestions} (${_application!.examPercentage?.toStringAsFixed(1)}%)',
                      style: AppStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cancel,
              size: 80,
              color: AppColors.danger,
            ),
            const SizedBox(height: 24),
            Text(
              'Application Rejected',
              style: AppStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your application for caregiver is rejected. Please update your profile and resubmit your details.',
              style: AppStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (_application?.rejectionReason != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejection Reason:',
                      style: AppStyles.titleSmall.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _application!.rejectionReason!,
                      style: AppStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            CustomButton(
              text: 'Resubmit Application',
              onPressed: _resubmitApplication,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verification Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: widget.verificationStatus == 'pending'
          ? _buildPendingView()
          : _buildRejectedView(),
    );
  }
}

