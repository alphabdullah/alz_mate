import 'package:alz_mate/core/models/family_member_model.dart';
import 'package:alz_mate/view/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../widgets/custom_button.dart';
import '../shared/profile_screen.dart';
import 'caregiver_request_screen.dart';
import 'add_family_member_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  UserModel? _currentUser;
  List<UserModel> _caregivers = [];
  List<FamilyMemberModel> _familyMembers = [];
  bool _isLoading = true;
  String? _error;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadPatientProfile();
  }

  Future<void> _loadPatientProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      if (authService.currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Load current user
      _currentUser = await firestoreService.getUserById(
        authService.currentUser!.uid,
      );

      if (_currentUser == null) {
        throw Exception('User profile not found');
      }

      // Load assigned caregivers
      _caregivers = await firestoreService.getPatientCaregivers(
        _currentUser!.id,
      );

      // Load family members
      _familyMembers = await firestoreService.getFamilyMembers(
        _currentUser!.id,
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
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
          title: const Text('My Profile'),
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
          title: const Text('My Profile'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              Text('Error loading profile', style: AppStyles.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, style: AppStyles.bodyMedium),
              const SizedBox(height: 16),
              CustomButton(text: 'Retry', onPressed: _loadPatientProfile),
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
        title: const Text('My Profile'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.edit, color: AppColors.primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatientProfile,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildHealthSummary(),
              const SizedBox(height: 24),
              _buildCaregivers(),
              const SizedBox(height: 24),
              _buildFamilyMembers(),
              const SizedBox(height: 24),
              _buildEmergencyContacts(),
              const SizedBox(height: 24),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: _currentUser?.profileImageUrl != null
                    ? NetworkImage(_currentUser!.profileImageUrl!)
                    : null,
                child: _currentUser?.profileImageUrl == null
                    ? Text(
                        _currentUser?.name.isNotEmpty == true
                            ? _currentUser!.name[0].toUpperCase()
                            : 'P',
                        style: AppStyles.headlineLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (_currentUser?.isVerified == true)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentUser?.name ?? 'Unknown User',
            style: AppStyles.headlineSmall.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _currentUser?.email ?? '',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'PATIENT',
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_currentUser?.age != null) ...[
            const SizedBox(height: 8),
            Text(
              'Age: ${_currentUser!.age} years',
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Summary', style: AppStyles.titleMedium),
          const SizedBox(height: 16),
          if (_currentUser?.medicalConditions != null) ...[
            _buildHealthInfo(
              'Medical Conditions',
              _currentUser!.medicalConditions!,
            ),
            const SizedBox(height: 12),
          ],
          if (_currentUser?.medications != null) ...[
            _buildHealthInfo('Current Medications', _currentUser!.medications!),
            const SizedBox(height: 12),
          ],
          if (_currentUser?.allergies != null) ...[
            _buildHealthInfo('Allergies', _currentUser!.allergies!),
            const SizedBox(height: 12),
          ],
          if (_currentUser?.bloodType != null) ...[
            _buildHealthInfo('Blood Type', _currentUser!.bloodType!),
            const SizedBox(height: 12),
          ],
          if (_currentUser?.primaryPhysician != null) ...[
            _buildHealthInfo(
              'Primary Physician',
              _currentUser!.primaryPhysician!,
            ),
          ],
          if (_currentUser?.medicalConditions == null &&
              _currentUser?.medications == null &&
              _currentUser?.allergies == null &&
              _currentUser?.bloodType == null &&
              _currentUser?.primaryPhysician == null)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.medical_information_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No health information available',
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    child: const Text('Add Health Information'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCaregivers() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Caregivers', style: AppStyles.titleMedium),
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CaregiverRequestScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadPatientProfile(); // Refresh data
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Request'),
                style: TextButton.styleFrom(foregroundColor: AppColors.success),
              ),
            ],
          ),
          if (_caregivers.isNotEmpty)
            Text(
              '${_caregivers.length} assigned',
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 16),
          if (_caregivers.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No caregivers assigned yet',
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CaregiverRequestScreen(),
                        ),
                      );
                      if (result == true) {
                        _loadPatientProfile();
                      }
                    },
                    child: const Text('Request a Caregiver'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _caregivers
                  .map((caregiver) => _buildCaregiverCard(caregiver))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCaregiverCard(UserModel caregiver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
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
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caregiver.name,
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (caregiver.specialization != null)
                  Text(
                    caregiver.specialization!,
                    style: AppStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (caregiver.hospitalClinic != null)
                  Text(
                    caregiver.hospitalClinic!,
                    style: AppStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => _contactCaregiver(caregiver),
                icon: const Icon(
                  Icons.message,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              if (caregiver.phone != null)
                IconButton(
                  onPressed: () => _callCaregiver(caregiver),
                  icon: const Icon(
                    Icons.phone,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMembers() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Family Members', style: AppStyles.titleMedium),
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddFamilyMemberScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadFamilyMembers(); // Refresh family members
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              ),
            ],
          ),
          if (_familyMembers.isNotEmpty)
            Text(
              '${_familyMembers.length} connected',
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 16),
          if (_familyMembers.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.family_restroom,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No family members added yet',
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddFamilyMemberScreen(),
                        ),
                      );
                      if (result == true) {
                        _loadFamilyMembers();
                      }
                    },
                    child: const Text('Add Family Member'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _familyMembers
                  .map((family) => _buildFamilyCard(family))
                  .toList(),
            ),
        ],
      ),
    );
  }

  // Add this method to load family members separately
  Future<void> _loadFamilyMembers() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final familyMembers = await _firestoreService.getFamilyMembers(
        currentUser.uid,
      );

      setState(() {
        _familyMembers = familyMembers;
      });
    } catch (e) {
      print('Error loading family members: $e');
    }
  }

  Widget _buildFamilyCard(FamilyMemberModel family) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.accent.withOpacity(0.1),
            backgroundImage: NetworkImage(family.imageUrl),
            child: null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.name,
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  family.relationship,
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (family.isPrimaryContact == true)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Primary Contact',
                      style: AppStyles.bodySmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              // IconButton(
              //   onPressed: () => _contactFamily(family),
              //   icon: const Icon(
              //     Icons.message,
              //     color: AppColors.accent,
              //     size: 20,
              //   ),
              // ),
              if (family.phone != null)
                IconButton(
                  onPressed: () => _callFamily(family),
                  icon: const Icon(
                    Icons.phone,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Account', style: AppStyles.titleMedium),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Log Out',
            backgroundColor: AppColors.danger,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      child: const Text('Log Out'),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await _authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Emergency Contacts', style: AppStyles.titleMedium),
          const SizedBox(height: 16),
          if (_currentUser?.emergencyContact != null) ...[
            _buildEmergencyContactItem(
              'Primary Emergency Contact',
              _currentUser!.emergencyContact!,
              Icons.emergency,
              AppColors.danger,
            ),
            const SizedBox(height: 12),
          ],
          _buildEmergencyContactItem(
            'Emergency Services',
            '1122',
            Icons.local_hospital,
            AppColors.danger,
          ),
          // const SizedBox(height: 12),
          // _buildEmergencyContactItem(
          //   'Poison Control',
          //   '1-800-222-1222',
          //   Icons.warning,
          //   AppColors.warning,
          // ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactItem(
    String label,
    String contact,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  contact,
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _makeEmergencyCall(contact),
            icon: Icon(Icons.phone, color: color, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInfo(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppStyles.bodyMedium.copyWith(color: AppColors.text),
          ),
        ),
      ],
    );
  }

  void _contactCaregiver(UserModel caregiver) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening chat with ${caregiver.name}...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _callCaregiver(UserModel caregiver) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${caregiver.name}...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // void _contactFamily(FamilyMemberModel family) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text('Opening chat with ${family.name}...'),
  //       backgroundColor: AppColors.accent,
  //     ),
  //   );
  // }

  void _callFamily(FamilyMemberModel family) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${family.name}...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _makeEmergencyCall(String contact) {
    _launchUrl(contact);
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text('Calling $contact...'),
    //     backgroundColor: AppColors.danger,
    //   ),
    // );
  }

  Future<void> _launchUrl(String number) async {
    if (!await launchUrl(
      Uri.parse('tel:$number'),
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $number');
    }
  }
}
