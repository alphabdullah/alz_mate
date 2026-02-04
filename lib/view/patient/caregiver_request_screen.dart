import 'package:alz_mate/core/services/notification_service.dart%20copy/notification_services.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/user_model.dart';
import '../../core/models/caregiver_request_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class CaregiverRequestScreen extends StatefulWidget {
  const CaregiverRequestScreen({super.key});

  @override
  State<CaregiverRequestScreen> createState() => _CaregiverRequestScreenState();
}

class _CaregiverRequestScreenState extends State<CaregiverRequestScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<UserModel> _availableCaregivers = [];
  List<UserModel> _filteredCaregivers = [];
  List<CaregiverRequestModel> _pendingRequests = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final futures = await Future.wait([
        _firestoreService.getAvailableCaregivers(currentUser.uid),
        _firestoreService.getCaregiverRequestsForPatient(currentUser.uid),
      ]);

      setState(() {
        _availableCaregivers = futures[0] as List<UserModel>;
        _filteredCaregivers = _availableCaregivers;
        _pendingRequests = futures[1] as List<CaregiverRequestModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterCaregivers() {
    setState(() {
      _filteredCaregivers = _availableCaregivers.where((caregiver) {
        final matchesSearch =
            caregiver.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            caregiver.specialization?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ==
                true ||
            caregiver.hospitalClinic?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ==
                true;
        return matchesSearch;
      }).toList();
    });
  }

  Future<void> _sendCaregiverRequest(UserModel caregiver) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final currentUserData = await _firestoreService.getUserById(
        currentUser.uid,
      );
      if (currentUserData == null) return;

      final request = CaregiverRequestModel(
        id: '',
        patientId: currentUser.uid,
        caregiverId: caregiver.id,
        patientName: currentUserData.name,
        caregiverName: caregiver.name,
        patientEmail: currentUserData.email,
        caregiverEmail: caregiver.email,
        status: 'pending',
        message: _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createCaregiverRequest(request);
      final bearerToken = await NotificationServices().getAccessToken();
      await NotificationServices().sendNotification(
        caregiver.fcmToken ?? '',
        bearerToken,
        '${currentUser.displayName} has sent you a caregiver request. Please review and respond.',
        'New Caregiver Request',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request sent to ${caregiver.name}'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
        _loadData(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showRequestDialog(UserModel caregiver) {
    _messageController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request ${caregiver.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a request to ${caregiver.name} to become your caregiver.',
              style: AppStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _messageController,
              label: 'Message (Optional)',
              hint: 'Add a personal message...',
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
            text: 'Send Request',
            onPressed: () {
              Navigator.pop(context);
              _sendCaregiverRequest(caregiver);
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
        title: const Text('Request Caregiver'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppStyles.softShadow,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _filterCaregivers();
                },
                decoration: const InputDecoration(
                  hintText: 'Search caregivers...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
          ),

          // Pending Requests Section
          if (_pendingRequests.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
      //               onTap: () async{
      //                   final bearerToken = await NotificationServices().getAccessToken();
      // await NotificationServices().sendNotification(
      //  'fbDXTV13SReK9dP7rsSHYD:APA91bEYjxMDQnhN-aUNwTTJqe-WyXaSujha9bzHjWSBljE6x6n-NYg_ZkO6UINm8NaTdWNzBUrMxCPC8APAdYhOzHJO4xpC2SQEyfd8ydBknsGjXeB8_Tk',
      //   bearerToken,
      //   ' has sent you a caregiver request. Please review and respond.',
      //   'New Caregiver Request',
      // );
      //               },
                    child: Text('Pending Requests', style: AppStyles.titleMedium)),
                  const SizedBox(height: 12),
                  ...(_pendingRequests.map(
                    (request) => _buildPendingRequestCard(request),
                  )),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],

          // Available Caregivers
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorState()
                : _filteredCaregivers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredCaregivers.length,
                    itemBuilder: (context, index) {
                      final caregiver = _filteredCaregivers[index];
                      return _buildCaregiverCard(caregiver);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestCard(CaregiverRequestModel request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hourglass_empty, color: AppColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request to ${request.caregiverName}',
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Sent ${_formatDate(request.createdAt)}',
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Pending',
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverCard(UserModel caregiver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppStyles.elevatedCard,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.success.withOpacity(0.1),
          backgroundImage: caregiver.profileImageUrl != null
              ? NetworkImage(caregiver.profileImageUrl!)
              : null,
          child: caregiver.profileImageUrl == null
              ? Text(
                  caregiver.name[0].toUpperCase(),
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        title: Text(
          caregiver.name,
          style: AppStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (caregiver.specialization != null) ...[
              const SizedBox(height: 4),
              Text(
                caregiver.specialization!,
                style: AppStyles.bodyMedium.copyWith(color: AppColors.success),
              ),
            ],
            if (caregiver.hospitalClinic != null) ...[
              const SizedBox(height: 2),
              Text(
                caregiver.hospitalClinic!,
                style: AppStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (caregiver.yearsOfExperience != null) ...[
              const SizedBox(height: 2),
              Text(
                '${caregiver.yearsOfExperience} years experience',
                style: AppStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _showRequestDialog(caregiver),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Request'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No available caregivers',
            style: AppStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All caregivers are either already assigned or have pending requests',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
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
          Text('Error loading caregivers', style: AppStyles.titleMedium),
          const SizedBox(height: 8),
          Text(_error!, style: AppStyles.bodyMedium),
          const SizedBox(height: 16),
          CustomButton(text: 'Retry', onPressed: _loadData),
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
