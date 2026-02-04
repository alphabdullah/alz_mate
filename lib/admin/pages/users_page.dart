import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/user_model.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      // Get all users by querying each role
      final patients = await firestoreService.getUsersByRole('patient');
      final caregivers = await firestoreService.getUsersByRole('caregiver');
      final family = await firestoreService.getUsersByRole('family');
      _users = [...patients, ...caregivers, ...family];
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<UserModel> get _filteredUsers {
    if (_filterRole == 'all') return _users;
    return _users.where((u) => u.role.toLowerCase() == _filterRole).toList();
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(user.name[0].toUpperCase()),
        ),
        title: Text(user.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            Text('Role: ${user.role.toUpperCase()}'),
            if (user.role.toLowerCase() == 'caregiver')
              Text(
                'Status: ${user.caregiverVerificationStatus ?? 'N/A'}',
                style: TextStyle(
                  color: user.caregiverVerificationStatus == 'approved'
                      ? AppColors.success
                      : user.caregiverVerificationStatus == 'rejected'
                          ? AppColors.danger
                          : AppColors.warning,
                ),
              ),
            if (user.caregiverIds != null && user.caregiverIds!.isNotEmpty)
              Text('Caregivers: ${user.caregiverIds!.length}'),
            if (user.patientIds != null && user.patientIds!.isNotEmpty)
              Text('Patients: ${user.patientIds!.length}'),
          ],
        ),
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
                _buildFilterChip('patient', 'Patients'),
                const SizedBox(width: 8),
                _buildFilterChip('caregiver', 'Caregivers'),
                const SizedBox(width: 8),
                _buildFilterChip('family', 'Family'),
              ],
            ),
          ),
        ),
        const Divider(),
        // Users List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Text(
                        'No users found',
                        style: AppStyles.bodyMedium,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          return _buildUserCard(_filteredUsers[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String role, String label) {
    final isSelected = _filterRole == role;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterRole = role);
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }
}

