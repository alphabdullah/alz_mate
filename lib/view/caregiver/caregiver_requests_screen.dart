import 'package:alz_mate/core/services/notification_service.dart%20copy/notification_services.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/caregiver_request_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class CaregiverRequestsScreen extends StatefulWidget {
  const CaregiverRequestsScreen({super.key});

  @override
  State<CaregiverRequestsScreen> createState() =>
      _CaregiverRequestsScreenState();
}

class _CaregiverRequestsScreenState extends State<CaregiverRequestsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _responseController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<CaregiverRequestModel> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final requests = await _firestoreService.getCaregiverRequestsForCaregiver(
        currentUser.uid,
      );

      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _respondToRequest(
    CaregiverRequestModel request,
    String status,
    String? responseMessage,
  ) async {
    try {
      await _firestoreService.updateCaregiverRequestStatus(
        request.id,
        status,
        responseMessage,
      );

      if (mounted) {
        final user = await _firestoreService.getUserById(request.patientId);
        final token = await NotificationServices().getAccessToken();
        if (status.toLowerCase() == 'accepted') {
          await NotificationServices().sendNotification(
            user!.fcmToken!,
            token,
            '${request.caregiverName} has accepted your request',
            'Request Accepted',
          );
        } else {
          await NotificationServices().sendNotification(
            user!.fcmToken!,
            token,
            '${request.caregiverName} has rejected your request',
            'Request Rejected',
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted'
                  ? 'Request accepted! ${request.patientName} is now your patient.'
                  : 'Request declined.',
            ),
            backgroundColor: status == 'accepted'
                ? AppColors.success
                : AppColors.warning,
          ),
        );
        _loadRequests(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to respond to request: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showResponseDialog(CaregiverRequestModel request, String action) {
    _responseController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action == 'accept' ? 'Accept' : 'Decline'} Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${action == 'accept' ? 'Accept' : 'Decline'} request from ${request.patientName}?',
              style: AppStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _responseController,
              label: 'Response Message (Optional)',
              hint: 'Add a message to the patient...',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CustomButton(
            text: action == 'accept' ? 'Accept' : 'Decline',
            onPressed: () {
              Navigator.pop(context);
              _respondToRequest(
                request,
                action == 'accept' ? 'accepted' : 'declined',
                _responseController.text.trim().isNotEmpty
                    ? _responseController.text.trim()
                    : null,
              );
            },
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Patient Requests'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : _requests.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  return _buildRequestCard(request);
                },
              ),
      ),
    );
  }

  Widget _buildRequestCard(CaregiverRequestModel request) {
    Color statusColor;
    String statusText;
    Widget? actionButtons;

    switch (request.status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'Pending';
        actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _showResponseDialog(request, 'decline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Decline'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _showResponseDialog(request, 'accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Accept'),
            ),
          ],
        );
        break;
      case 'accepted':
        statusColor = AppColors.success;
        statusText = 'Accepted';
        break;
      case 'declined':
        statusColor = AppColors.danger;
        statusText = 'Declined';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppStyles.elevatedCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    request.patientName[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.patientName,
                        style: AppStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        request.patientEmail,
                        style: AppStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: AppStyles.bodySmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Requested ${_formatDate(request.createdAt)}',
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            if (request.message != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(request.message!, style: AppStyles.bodyMedium),
              ),
            ],

            if (request.respondedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Responded ${_formatDate(request.respondedAt!)}',
                style: AppStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (request.responseMessage != null) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    'Your response: ${request.responseMessage!}',
                    style: AppStyles.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],

            if (actionButtons != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [actionButtons],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No patient requests',
            style: AppStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Patient requests will appear here',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.danger),
          const SizedBox(height: 16),
          Text('Error loading requests', style: AppStyles.titleMedium),
          const SizedBox(height: 8),
          Text(_error!, style: AppStyles.bodyMedium),
          const SizedBox(height: 16),
          CustomButton(text: 'Retry', onPressed: _loadRequests),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
