import 'package:alz_mate/core/models/family_member_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/face_recognition_service.dart';

import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  bool _isIdentifying = false;
  bool _isAddingPerson = false;
  bool _isLoading = false;
  String? _processingMessage;

  final _nameController = TextEditingController();
  File? _capturedImage;
  String? _capturedImageUrl;

  List<FamilyMemberModel> _familyMembers = [];
  Map<String, dynamic>? _identifiedPerson;

  final FaceRecognitionService _faceRecognitionService =
      FaceRecognitionService();

  @override
  void initState() {
    super.initState();
    _initializeFaceRecognition();
    _loadFamilyMembers();
  }

  Future<void> _initializeFaceRecognition() async {
    try {
      await _faceRecognitionService.initialize();
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser != null) {
        await _faceRecognitionService.loadKnownFaces(
          authService.currentUser!.uid,
        );
      }
    } catch (e) {
      print('Error initializing face recognition: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyMembers() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      if (authService.currentUser != null) {
        final members = await firestoreService.getFamilyMembers(
          authService.currentUser!.uid,
        );
        setState(() => _familyMembers = members);
      }
    } catch (e) {
      _showError('Error loading members: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _identifyPerson() async {
    setState(() {
      _isIdentifying = true;
      _identifiedPerson = null;
      _processingMessage = 'Capturing image...';
    });

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      
      if (image == null) {
        setState(() {
          _isIdentifying = false;
          _processingMessage = null;
        });
        return;
      }

      setState(() => _processingMessage = 'Detecting face...');
      final imageFile = File(image.path);

      // First check if face is detected
      final validation = await _faceRecognitionService.validateFaceImage(imageFile);
      final isValid = validation['isValid'] as bool? ?? false;
      if (!isValid) {
        setState(() {
          _isIdentifying = false;
          _processingMessage = null;
        });
        _showError(validation['reason']?.toString() ?? 'No face detected in the image');
        return;
      }

      setState(() => _processingMessage = 'Recognizing person...');
      final recognized = await _faceRecognitionService.recognizeFaces(imageFile);

      setState(() {
        _isIdentifying = false;
        _processingMessage = null;
      });

      if (recognized.isEmpty) {
        _identifiedPerson = null;
        _showError('Person not found');
      } else {
        final match = recognized.first;
        if (match.isEmpty) {
          _identifiedPerson = null;
          _showError('Person not found');
        } else {
          _identifiedPerson = {
            'name': match['name']?.toString() ?? 'Unknown',
            'relationship': match['relationship']?.toString() ?? '',
            'confidence': match['confidence'] ?? 0.0,
            'imageUrl': match['imageUrl']?.toString() ?? '',
          };
          _showSuccess('Person found: ${_identifiedPerson!['name']}');
        }
      }
    } catch (e) {
      setState(() {
        _isIdentifying = false;
        _processingMessage = null;
      });
      _showError('Failed to identify person: ${e.toString()}');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
          _capturedImageUrl = image.path;
        });
      }
    } catch (e) {
      _showError('Failed to capture photo: ${e.toString()}');
    }
  }

  Future<void> _addPerson() async {
    // Validate inputs
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter a name');
      return;
    }

    if (_capturedImage == null) {
      _showError('Please capture a photo');
      return;
    }

    setState(() {
      _isAddingPerson = true;
      _processingMessage = 'Validating image...';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser == null) {
        throw Exception('User not logged in');
      }

      final userId = authService.currentUser!.uid;
      final storageService = Provider.of<StorageService>(
        context,
        listen: false,
      );
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      // Step 1: Validate face image
      setState(() => _processingMessage = 'Detecting face in image...');
      final validation = await _faceRecognitionService.validateFaceImage(
        _capturedImage!,
      );
      
      if (!(validation['isValid'] ?? false)) {
        final reason = validation['reason']?.toString() ?? 'Invalid face image';
        setState(() {
          _isAddingPerson = false;
          _processingMessage = null;
        });
        _showError(reason);
        return;
      }

      // Step 2: Upload image to storage
      setState(() => _processingMessage = 'Uploading image...');
      String? imageUrl;
      try {
        imageUrl = await storageService.uploadFaceRecognitionImage(
          userId,
          _capturedImage!,
        );
      } catch (e) {
        print('Image upload error: $e');
        // Continue even if upload fails - we can still save the face encoding
      }

      // Step 3: Extract and save face embedding
      setState(() => _processingMessage = 'Processing face data...');
      await _faceRecognitionService.addKnownFace(
        imageFile: _capturedImage!,
        name: name,
        relationship: '', // Not required anymore
        userId: userId,
        imageUrl: imageUrl,
      );

      // Step 4: Add to Firestore as family member
      setState(() => _processingMessage = 'Saving to database...');
      final member = FamilyMemberModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        name: name,
        relationship: '', // Not required
        notes: '',
        imageUrl: imageUrl ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestoreService.addFamilyMember(member);
      setState(() => _familyMembers.add(member));

      setState(() {
        _isAddingPerson = false;
        _processingMessage = null;
      });

      _clearForm();
      if (mounted) {
        Navigator.pop(context);
        _showSuccess('Person added successfully!');
      }
    } catch (e) {
      setState(() {
        _isAddingPerson = false;
        _processingMessage = null;
      });
      _showError('Failed to add person: ${e.toString()}');
    }
  }

  Future<void> _deleteFamilyMember(String id) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      
      // Find the member to get face ID
      final member = _familyMembers.firstWhere(
        (m) => m.id == id,
        orElse: () => FamilyMemberModel(
          id: '',
          userId: '',
          name: '',
          relationship: '',
          notes: '',
          imageUrl: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      if (member.id.isEmpty) {
        _showError('Member not found');
        return;
      }
      
      // Remove from face recognition service
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser != null) {
        final knownFaces = _faceRecognitionService.getKnownFaces(
          authService.currentUser!.uid,
        );
        
        // Try to find matching face by name
        final matchingFace = knownFaces.firstWhere(
          (face) => (face['name']?.toString() ?? '') == member.name,
          orElse: () => <String, dynamic>{},
        );
        
        if (matchingFace.isNotEmpty && matchingFace['id'] != null) {
          await _faceRecognitionService.removeKnownFace(
            matchingFace['id'].toString(),
          );
        }
      }
      
      // Remove from Firestore
      await firestoreService.deleteFamilyMember(id);
      setState(() => _familyMembers.removeWhere((m) => m.id == id));
      _showSuccess('Person deleted successfully');
    } catch (e) {
      _showError('Delete failed: ${e.toString()}');
    }
  }

  void _clearForm() {
    _nameController.clear();
    _capturedImage = null;
    _capturedImageUrl = null;
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Person'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_capturedImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: double.maxFinite,
                    height: 150,
                    child: Image.file(
                      File(_capturedImageUrl!),
                    fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton.icon(
                    icon: const Icon(Icons.camera_alt, size: 48),
                    label: const Text('Capture Photo'),
                    onPressed: _capturePhoto,
                  ),
                ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _nameController,
                label: 'Name *',
                hintText: 'Enter person name',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isAddingPerson
                ? null
                : () {
                    _clearForm();
                    Navigator.pop(context);
                  },
            child: const Text('Cancel'),
          ),
          CustomButton(
            text: 'Add Person',
            onPressed: _isAddingPerson
                ? () {}
                : () {
                    _addPerson();
                  },
            isLoading: _isAddingPerson,
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera),
                  label: const Text('Identify Person'),
                  onPressed: _isIdentifying ? null : _identifyPerson,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Person'),
                  onPressed: _showAddDialog,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Processing indicator for identification
          if (_isIdentifying && _processingMessage != null)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _processingMessage!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Processing indicator for adding person
          if (_isAddingPerson && _processingMessage != null)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _processingMessage!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Show identified person
          if (_identifiedPerson != null)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Person Found!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_identifiedPerson!['imageUrl'] != null &&
                            _identifiedPerson!['imageUrl'].toString().isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _identifiedPerson!['imageUrl'].toString(),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.person, size: 40),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person, size: 40),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _identifiedPerson!['name']?.toString() ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_identifiedPerson!['relationship'] != null &&
                                  _identifiedPerson!['relationship'].toString().isNotEmpty)
                                Text(
                                  _identifiedPerson!['relationship'].toString(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Confidence: ${((_identifiedPerson!['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),
          const Text(
            'Saved People',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_familyMembers.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No people added yet. Use "Add Person" to register faces.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ..._familyMembers.map((member) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: (member.imageUrl.isNotEmpty)
                        ? NetworkImage(member.imageUrl)
                        : null,
                    onBackgroundImageError: (exception, stackTrace) {
                      // Handle image load error
                    },
                    child: member.imageUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(member.name.isNotEmpty ? member.name : 'Unknown'),
                  subtitle: member.relationship.isNotEmpty
                      ? Text(member.relationship)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteFamilyMember(member.id),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
