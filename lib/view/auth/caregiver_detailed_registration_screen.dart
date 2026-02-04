import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/caregiver_application_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/utils/validators.dart';
import '../caregiver/mcq_exam_screen.dart';

class CaregiverDetailedRegistrationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String name;

  const CaregiverDetailedRegistrationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.name,
  });

  @override
  State<CaregiverDetailedRegistrationScreen> createState() =>
      _CaregiverDetailedRegistrationScreenState();
}

class _CaregiverDetailedRegistrationScreenState
    extends State<CaregiverDetailedRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;

  // Controllers
  final _fullNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();

  // File pickers
  File? _matriculationCertificate;
  File? _intermediateCertificate;
  File? _graduationDegree;
  File? _workExperienceDocuments;
  File? _caregivingCertificates;

  bool _isLoading = false;
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.name;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _dateOfBirthController.dispose();
    _fullAddressController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dateOfBirthController.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _pickFile(String documentType) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          final file = File(result.files.single.path!);
          switch (documentType) {
            case 'matriculation':
              _matriculationCertificate = file;
              break;
            case 'intermediate':
              _intermediateCertificate = file;
              break;
            case 'graduation':
              _graduationDegree = file;
              break;
            case 'work':
              _workExperienceDocuments = file;
              break;
            case 'caregiving':
              _caregivingCertificates = file;
              break;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }


  Widget _buildFilePicker(
    String label,
    String documentType,
    File? selectedFile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppStyles.labelLarge),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickFile(documentType),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedFile?.path.split('/').last ?? 'Upload PDF or Image',
                    style: TextStyle(
                      color: selectedFile != null
                          ? AppColors.text
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (selectedFile != null)
                  Icon(Icons.check_circle, color: AppColors.success),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final storageService = Provider.of<StorageService>(context, listen: false);
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);

      // Create user account
      final userCredential = await authService.signUpWithEmailAndPassword(
        name: _fullNameController.text.trim(),
        email: widget.email,
        password: widget.password,
        role: 'caregiver',
      );

      if (userCredential.user == null) {
        throw Exception('Failed to create user account');
      }

      // Upload documents
      String? matricUrl, interUrl, gradUrl, workUrl, careUrl;

      if (_matriculationCertificate != null) {
        matricUrl = await storageService.uploadImage(
          _matriculationCertificate!,
          folder: 'caregiver_documents/${userCredential.user!.uid}',
        );
      }
      if (_intermediateCertificate != null) {
        interUrl = await storageService.uploadImage(
          _intermediateCertificate!,
          folder: 'caregiver_documents/${userCredential.user!.uid}',
        );
      }
      if (_graduationDegree != null) {
        gradUrl = await storageService.uploadImage(
          _graduationDegree!,
          folder: 'caregiver_documents/${userCredential.user!.uid}',
        );
      }
      if (_workExperienceDocuments != null) {
        workUrl = await storageService.uploadImage(
          _workExperienceDocuments!,
          folder: 'caregiver_documents/${userCredential.user!.uid}',
        );
      }
      if (_caregivingCertificates != null) {
        careUrl = await storageService.uploadImage(
          _caregivingCertificates!,
          folder: 'caregiver_documents/${userCredential.user!.uid}',
        );
      }

      // Create caregiver application
      final application = CaregiverApplicationModel(
        id: '',
        userId: userCredential.user!.uid,
        fullName: _fullNameController.text.trim(),
        dateOfBirth: _selectedDateOfBirth!,
        email: widget.email,
        fullAddress: _fullAddressController.text.trim(),
        province: _provinceController.text.trim(),
        city: _cityController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        matriculationCertificateUrl: matricUrl,
        intermediateCertificateUrl: interUrl,
        graduationDegreeUrl: gradUrl,
        workExperienceDocumentsUrl: workUrl,
        caregivingCertificatesUrl: careUrl,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Save application to Firestore
      await firestoreService.createCaregiverApplication(application);

      // Update user with verification status
      await firestoreService.updateUser(userCredential.user!.uid, {
        'caregiverVerificationStatus': 'pending',
      });

      // Navigate to exam screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MCQExamScreen(
              userId: userCredential.user!.uid,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Information', style: AppStyles.titleLarge),
            const SizedBox(height: 24),
            CustomTextField(
              label: 'Full Name',
              controller: _fullNameController,
              prefixIcon: Icons.person_outline,
              validator: Validators.validateName,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickDateOfBirth,
              child: CustomTextField(
                label: 'Date of Birth',
                controller: _dateOfBirthController,
                prefixIcon: Icons.calendar_today,
                enabled: false,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select date of birth';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Email',
              controller: TextEditingController(text: widget.email),
              prefixIcon: Icons.email_outlined,
              enabled: false,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Full Address',
              controller: _fullAddressController,
              prefixIcon: Icons.home_outlined,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Province',
              controller: _provinceController,
              prefixIcon: Icons.location_city,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your province';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'City',
              controller: _cityController,
              prefixIcon: Icons.location_city,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your city';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Phone Number',
              controller: _phoneController,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: Validators.validatePhone,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Next: Upload Documents',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Documents', style: AppStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Please upload images or PDF files of your certificates and documents',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _buildFilePicker(
            'Matriculation Certificate',
            'matriculation',
            _matriculationCertificate,
          ),
          const SizedBox(height: 20),
          _buildFilePicker(
            'Intermediate Certificate',
            'intermediate',
            _intermediateCertificate,
          ),
          const SizedBox(height: 20),
          _buildFilePicker(
            'Graduation Degree',
            'graduation',
            _graduationDegree,
          ),
          const SizedBox(height: 20),
          _buildFilePicker(
            'Work Experience Documents',
            'work',
            _workExperienceDocuments,
          ),
          const SizedBox(height: 20),
          _buildFilePicker(
            'Caregiving/Medical Certificates',
            'caregiving',
            _caregivingCertificates,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Back',
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  backgroundColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomButton(
                  text: 'Submit & Start Exam',
                  onPressed: _submitForm,
                  isLoading: _isLoading,
                ),
              ),
            ],
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
        title: Text('Caregiver Registration (${_currentStep + 1}/2)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentStep = index),
        children: [
          _buildPersonalInfoStep(),
          _buildDocumentsStep(),
        ],
      ),
    );
  }
}

