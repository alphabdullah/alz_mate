import 'package:alz_mate/view/auth/login_screen.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();

  // Patient-specific controllers
  final TextEditingController _medicalConditionsController =
      TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();
  final TextEditingController _insuranceProviderController =
      TextEditingController();
  final TextEditingController _insuranceNumberController =
      TextEditingController();
  final TextEditingController _primaryPhysicianController =
      TextEditingController();

  // Caregiver-specific controllers
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _hospitalClinicController =
      TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _yearsOfExperienceController =
      TextEditingController();

  // Family-specific controllers
  final TextEditingController _relationshipController = TextEditingController();

  UserModel? _currentUser;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  DateTime? _selectedDateOfBirth;
  File? _selectedImage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _medicalConditionsController.dispose();
    _medicationsController.dispose();
    _allergiesController.dispose();
    _bloodTypeController.dispose();
    _insuranceProviderController.dispose();
    _insuranceNumberController.dispose();
    _primaryPhysicianController.dispose();
    _specializationController.dispose();
    _licenseNumberController.dispose();
    _hospitalClinicController.dispose();
    _departmentController.dispose();
    _yearsOfExperienceController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final userData = await _firestoreService.getUserById(currentUser.uid);
      if (userData == null) {
        throw Exception('User profile not found');
      }

      _currentUser = userData;
      _populateControllers();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading profile: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _populateControllers() {
    if (_currentUser == null) return;

    _nameController.text = _currentUser!.name;
    _emailController.text = _currentUser!.email;
    _phoneController.text = _currentUser!.phone ?? '';
    _addressController.text = _currentUser!.address ?? '';
    _emergencyContactController.text = _currentUser!.emergencyContact ?? '';
    _selectedDateOfBirth = _currentUser!.dateOfBirth;

    // Patient-specific fields
    if (_currentUser!.isPatient) {
      _medicalConditionsController.text = _currentUser!.medicalConditions ?? '';
      _medicationsController.text = _currentUser!.medications ?? '';
      _allergiesController.text = _currentUser!.allergies ?? '';
      _bloodTypeController.text = _currentUser!.bloodType ?? '';
      _insuranceProviderController.text = _currentUser!.insuranceProvider ?? '';
      _insuranceNumberController.text = _currentUser!.insuranceNumber ?? '';
      _primaryPhysicianController.text = _currentUser!.primaryPhysician ?? '';
    }

    // Caregiver-specific fields
    if (_currentUser!.isCaregiver) {
      _specializationController.text = _currentUser!.specialization ?? '';
      _licenseNumberController.text = _currentUser!.licenseNumber ?? '';
      _hospitalClinicController.text = _currentUser!.hospitalClinic ?? '';
      _departmentController.text = _currentUser!.department ?? '';
      _yearsOfExperienceController.text =
          _currentUser!.yearsOfExperience?.toString() ?? '';
    }

    // Family-specific fields
    if (_currentUser!.isFamily) {
      _relationshipController.text = _currentUser!.relationshipToPatient ?? '';
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Name is required');
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Email is required');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? profileImageUrl = _currentUser!.profileImageUrl;

      // Upload new profile image if selected
      if (_selectedImage != null) {
        setState(() => _isUploadingImage = true);
        profileImageUrl = await _storageService.uploadProfileImage(
          _selectedImage!,
          _currentUser!.id,
        );
        setState(() => _isUploadingImage = false);
      }

      // Create updated user with new information
      final updatedUser = _currentUser!.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        emergencyContact: _emergencyContactController.text.trim().isEmpty
            ? null
            : _emergencyContactController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        profileImageUrl: profileImageUrl,
        updatedAt: DateTime.now(),

        // Patient-specific updates
        medicalConditions: _currentUser!.isPatient
            ? (_medicalConditionsController.text.trim().isEmpty
                  ? null
                  : _medicalConditionsController.text.trim())
            : _currentUser!.medicalConditions,
        medications: _currentUser!.isPatient
            ? (_medicationsController.text.trim().isEmpty
                  ? null
                  : _medicationsController.text.trim())
            : _currentUser!.medications,
        allergies: _currentUser!.isPatient
            ? (_allergiesController.text.trim().isEmpty
                  ? null
                  : _allergiesController.text.trim())
            : _currentUser!.allergies,
        bloodType: _currentUser!.isPatient
            ? (_bloodTypeController.text.trim().isEmpty
                  ? null
                  : _bloodTypeController.text.trim())
            : _currentUser!.bloodType,
        insuranceProvider: _currentUser!.isPatient
            ? (_insuranceProviderController.text.trim().isEmpty
                  ? null
                  : _insuranceProviderController.text.trim())
            : _currentUser!.insuranceProvider,
        insuranceNumber: _currentUser!.isPatient
            ? (_insuranceNumberController.text.trim().isEmpty
                  ? null
                  : _insuranceNumberController.text.trim())
            : _currentUser!.insuranceNumber,
        primaryPhysician: _currentUser!.isPatient
            ? (_primaryPhysicianController.text.trim().isEmpty
                  ? null
                  : _primaryPhysicianController.text.trim())
            : _currentUser!.primaryPhysician,

        // Caregiver-specific updates
        specialization: _currentUser!.isCaregiver
            ? (_specializationController.text.trim().isEmpty
                  ? null
                  : _specializationController.text.trim())
            : _currentUser!.specialization,
        licenseNumber: _currentUser!.isCaregiver
            ? (_licenseNumberController.text.trim().isEmpty
                  ? null
                  : _licenseNumberController.text.trim())
            : _currentUser!.licenseNumber,
        hospitalClinic: _currentUser!.isCaregiver
            ? (_hospitalClinicController.text.trim().isEmpty
                  ? null
                  : _hospitalClinicController.text.trim())
            : _currentUser!.hospitalClinic,
        department: _currentUser!.isCaregiver
            ? (_departmentController.text.trim().isEmpty
                  ? null
                  : _departmentController.text.trim())
            : _currentUser!.department,
        yearsOfExperience:
            _currentUser!.isCaregiver &&
                _yearsOfExperienceController.text.trim().isNotEmpty
            ? int.tryParse(_yearsOfExperienceController.text.trim())
            : _currentUser!.yearsOfExperience,

        // Family-specific updates
        relationshipToPatient: _currentUser!.isFamily
            ? (_relationshipController.text.trim().isEmpty
                  ? null
                  : _relationshipController.text.trim())
            : _currentUser!.relationshipToPatient,
      );

      // Update user in Firestore
      await _firestoreService.updateUser(
        _currentUser!.id,
        updatedUser.toJson(),
      );

      // Update email in Firebase Auth if changed
      if (updatedUser.email != _currentUser!.email) {
        await _authService.updateEmail(updatedUser.email);
      }

      setState(() {
        _currentUser = updatedUser;
        _isEditing = false;
        _selectedImage = null;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
        _isUploadingImage = false;
      });

      _showErrorSnackBar('Error saving profile: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: ${e.toString()}');
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
          title: const Text('Profile', style: AppStyles.headlineLarge),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading Profile...',
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Profile', style: AppStyles.headlineLarge),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load profile',
                style: AppStyles.titleMedium.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Retry',
                onPressed: _loadUserProfile,
                backgroundColor: AppColors.primary,
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
        title: const Text('Profile', style: AppStyles.headlineLarge),
        actions: [
          if (!_isEditing && !_isSaving)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: Icon(Icons.edit, color: AppColors.primary),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildProfileCompletionCard(),
            const SizedBox(height: 24),
            _buildPersonalInformationForm(),
            const SizedBox(height: 24),
            if (_currentUser?.isPatient == true) _buildPatientInformation(),
            if (_currentUser?.isCaregiver == true) _buildCaregiverInformation(),
            if (_currentUser?.isFamily == true) _buildFamilyInformation(),
            const SizedBox(height: 24),
            // _buildAccountSettings(),
            // const SizedBox(height: 32),
            if (_isEditing) _buildActionButtons(),
            const SizedBox(height: 24),
            _buildLogoutButton(),
          ],
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
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : (_currentUser?.profileImageUrl != null
                              ? NetworkImage(_currentUser!.profileImageUrl!)
                              : null)
                          as ImageProvider?,
                child:
                    _selectedImage == null &&
                        _currentUser?.profileImageUrl == null
                    ? Text(
                        _currentUser?.name.isNotEmpty == true
                            ? _currentUser!.name[0].toUpperCase()
                            : 'U',
                        style: AppStyles.headlineLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (_isUploadingImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              if (_isEditing && !_isUploadingImage)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _showImagePicker(),
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                ),
              if (_currentUser?.isVerified == true)
                Positioned(
                  top: 0,
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
            _currentUser?.displayNameWithRole ?? 'Unknown User',
            style: AppStyles.headlineSmall.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getRoleColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentUser?.role.toUpperCase() ?? 'USER',
              style: AppStyles.bodySmall.copyWith(
                color: _getRoleColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Member since ${_formatDate(_currentUser?.createdAt)}',
            style: AppStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          if (_currentUser?.lastActive != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentUser!.isActive
                        ? AppColors.success
                        : AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentUser!.isActive
                      ? 'Active'
                      : 'Last seen ${_formatDate(_currentUser!.lastActive)}',
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCompletionCard() {
    final completionPercentage = _currentUser?.profileCompletionPercentage ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion',
                style: AppStyles.titleMedium.copyWith(color: AppColors.text),
              ),
              Text(
                '${completionPercentage.toInt()}%',
                style: AppStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: completionPercentage / 100,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            completionPercentage < 100
                ? 'Complete your profile to unlock all features'
                : 'Your profile is complete!',
            style: AppStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInformationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: AppStyles.titleMedium.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _nameController,
            label: 'Full Name',
            enabled: _isEditing,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _emailController,
            label: 'Email Address',
            enabled: _isEditing,
            keyboardType: TextInputType.emailAddress,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Email is required' : null,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _phoneController,
            label: 'Phone Number',
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _addressController,
            label: 'Address',
            enabled: _isEditing,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _emergencyContactController,
            label: 'Emergency Contact',
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildDateOfBirthField(),
        ],
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    return InkWell(
      onTap: _isEditing ? _selectDateOfBirth : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
          color: _isEditing ? Colors.white : AppColors.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date of Birth',
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedDateOfBirth != null
                      ? _formatDate(_selectedDateOfBirth)
                      : 'Not specified',
                  style: AppStyles.bodyMedium.copyWith(color: AppColors.text),
                ),
                if (_currentUser?.age != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Age: ${_currentUser!.age} years',
                    style: AppStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (_isEditing)
              Icon(Icons.calendar_today, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInformation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medical Information',
            style: AppStyles.titleMedium.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _bloodTypeController,
            label: 'Blood Type',
            enabled: _isEditing,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _medicalConditionsController,
            label: 'Medical Conditions',
            enabled: _isEditing,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _allergiesController,
            label: 'Allergies',
            enabled: _isEditing,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _medicationsController,
            label: 'Current Medications',
            enabled: _isEditing,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCaregiverInformation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Professional Information',
            style: AppStyles.titleMedium.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _specializationController,
            label: 'Specialization',
            enabled: _isEditing,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _licenseNumberController,
            label: 'License Number',
            enabled: _isEditing,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _yearsOfExperienceController,
            label: 'Years of Experience',
            enabled: _isEditing,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _hospitalClinicController,
            label: 'Hospital/Clinic',
            enabled: _isEditing,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _departmentController,
            label: 'Department',
            enabled: _isEditing,
          ),
          if (_currentUser?.rating != null) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              'Rating',
              '${_currentUser!.rating!.toStringAsFixed(1)}/5.0',
            ),
          ],
          if (_currentUser?.totalPatientsServed != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Total Patients Served',
              '${_currentUser!.totalPatientsServed}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFamilyInformation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Family Information',
            style: AppStyles.titleMedium.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _relationshipController,
            label: 'Relationship to Patient',
            enabled: _isEditing,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Primary Contact',
            _currentUser?.isPrimaryContact == true ? 'Yes' : 'No',
          ),
          if (_currentUser?.patientId != null) ...[
            const SizedBox(height: 8),
            FutureBuilder<UserModel?>(
              future: _firestoreService.getUserById(_currentUser!.patientId!),
              builder: (context, snapshot) {
                return _buildInfoRow(
                  'Patient',
                  snapshot.data?.name ?? 'Loading...',
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Settings',
            style: AppStyles.titleMedium.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Account Status',
            _currentUser?.isVerified == true ? 'Verified' : 'Unverified',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Preferred Language',
            _currentUser?.preferredLanguage ?? 'English',
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Timezone', _currentUser?.timezone ?? 'UTC'),
          if (_currentUser?.needsPasswordUpdate == true) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your password is over 90 days old. Consider updating it for security.',
                      style: AppStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppStyles.bodySmall.copyWith(color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Cancel',
            onPressed: () {
              if (_isSaving) {
                null;
              } else {
                setState(() {
                  _isEditing = false;
                  _selectedImage = null;
                });
                _populateControllers(); // Reset form
              }
            },
            isOutlined: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CustomButton(
            text: _isSaving ? 'Saving...' : 'Save Changes',
            onPressed: () async {
              if (_isSaving) {
                null;
              } else {
                await _saveProfile(); // <- this is valid here
              }
            },
            backgroundColor: AppColors.primary,
            isLoading: _isSaving,
          ),
        ),
      ],
    );
  }

  Color _getRoleColor() {
    switch (_currentUser?.role) {
      case 'patient':
        return AppColors.primary;
      case 'caregiver':
        return AppColors.success;
      case 'family':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change Profile Picture',
              style: AppStyles.titleMedium.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Camera',
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                    icon: Icons.camera_alt,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Gallery',
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                    icon: Icons.photo_library,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
