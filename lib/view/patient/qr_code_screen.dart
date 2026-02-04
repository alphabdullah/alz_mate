import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScreenshotController _screenshotController = ScreenshotController();

  // Add QR Code form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedImage;
  String? _selectedImageUrl;
  bool _isGenerating = false;
  String? _generatedQrCodeId;
  Map<String, dynamic>? _generatedQrData;

  // Scan QR Code
  bool _isScanning = false;
  Map<String, dynamic>? _scannedQrData;
  MobileScannerController? _scannerController;

  // Saved QR Codes
  List<Map<String, dynamic>> _savedQrCodes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedQrCodes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadSavedQrCodes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      if (authService.currentUser != null) {
        final qrCodes = await firestoreService.getQrCodes(
          authService.currentUser!.uid,
        );
        setState(() {
          _savedQrCodes = qrCodes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading QR codes: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _selectedImageUrl = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
    }
  }

  Future<void> _generateQrCode() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final storageService = Provider.of<StorageService>(
        context,
        listen: false,
      );

      if (authService.currentUser == null) {
        throw Exception('User not authenticated');
      }

      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await storageService.uploadQrCodeImage(
          authService.currentUser!.uid,
          _selectedImage!,
        );
      }

      // Create QR code data
      final qrCodeData = {
        'userId': authService.currentUser!.uid,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Save to Firestore and get the ID
      final qrCodeId = await firestoreService.createQrCode(qrCodeData);

      setState(() {
        _generatedQrCodeId = qrCodeId;
        _generatedQrData = {...qrCodeData, 'id': qrCodeId};
        _savedQrCodes.insert(0, _generatedQrData!);
        _titleController.clear();
        _descriptionController.clear();
        _selectedImage = null;
        _selectedImageUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code generated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating QR code: $e')));
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _saveQrCodeToGallery() async {
    if (_generatedQrCodeId == null) return;

    try {
      // Capture the QR code as image
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes != null) {
        // Save to temporary directory
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/qr_code_$_generatedQrCodeId.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(imageBytes);

        // Save to gallery
        final result = await GallerySaver.saveImage(imagePath);

        if (result == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR Code saved to gallery successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          throw Exception('Failed to save to gallery');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving QR code: $e')));
    }
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _scannedQrData = null;
    });
    _scannerController = MobileScannerController();
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
    _scannerController?.dispose();
    _scannerController = null;
  }

  Future<void> _onQrCodeDetected(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;

    if (barcodes.isNotEmpty) {
      final String? qrCodeId = barcodes.first.rawValue;

      if (qrCodeId != null) {
        _stopScanning();
        await _fetchQrCodeData(qrCodeId);
      }
    }
  }

  Future<void> _fetchQrCodeData(String qrCodeId) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final qrData = await firestoreService.getQrCodeById(qrCodeId);

      if (qrData != null) {
        setState(() {
          _scannedQrData = qrData;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code scanned successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code not found in database')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching QR code data: $e')),
      );
    }
  }

  Future<void> _deleteQrCode(String qrCodeId) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      await firestoreService.deleteQrCode(qrCodeId);

      setState(() {
        _savedQrCodes.removeWhere((qr) => qr['id'] == qrCodeId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code deleted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting QR code: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Add QR Code', icon: Icon(Icons.add_box)),
            Tab(text: 'Scan QR Code', icon: Icon(Icons.qr_code_scanner)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAddQrCodeTab(), _buildScanQrCodeTab()],
      ),
    );
  }

  Widget _buildAddQrCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Create New QR Code Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create New QR Code',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _titleController,
                  label: 'Title',
                  hint: 'e.g., Kitchen Medicine Cabinet',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Add detailed instructions or information...',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                // Image attachment section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedImageUrl != null
                      ? Column(
                          children: [
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_selectedImageUrl!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _selectImage,
                              child: const Text('Change Image'),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Picture (Optional)',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _selectImage,
                              child: const Text('Select Image'),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: _isGenerating ? 'Generating...' : 'Generate QR Code',
                  onPressed: _generateQrCode,
                  isLoading: _isGenerating,
                ),
              ],
            ),
          ),

          // Generated QR Code Display
          if (_generatedQrData != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.elevatedCard,
              child: Column(
                children: [
                  const Text(
                    'QR Code Generated Successfully!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: QrImageView(
                        data: _generatedQrCodeId!,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Title: ${_generatedQrData!['title']}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Save to Gallery',
                          onPressed: _saveQrCodeToGallery,
                          backgroundColor: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Print',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Printing QR Code...'),
                              ),
                            );
                          },
                          backgroundColor: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Saved QR Codes List
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved QR Codes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_savedQrCodes.isEmpty)
                  const Center(
                    child: Text(
                      'No QR codes saved yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _savedQrCodes.length,
                    itemBuilder: (context, index) {
                      final qrCode = _savedQrCodes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(
                            Icons.qr_code,
                            color: AppColors.primary,
                          ),
                          title: Text(qrCode['title']),
                          subtitle: Text(
                            qrCode['description'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: AppColors.danger,
                            ),
                            onPressed: () => _showDeleteConfirmation(qrCode),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanQrCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scan QR Code Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              children: [
                if (_isScanning) ...[
                  Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: _onQrCodeDetected,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Stop Scanning',
                    onPressed: _stopScanning,
                    backgroundColor: AppColors.danger,
                  ),
                ] else ...[
                  Icon(
                    Icons.qr_code_scanner,
                    size: 80,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Point your camera at a QR code to scan it',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Start Scanning',
                    onPressed: _startScanning,
                  ),
                ],
              ],
            ),
          ),

          // Scanned QR Code Result
          if (_scannedQrData != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.elevatedCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 8),
                      Text(
                        'QR Code Found!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _scannedQrData!['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _scannedQrData!['description'],
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  if (_scannedQrData!['imageUrl'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _scannedQrData!['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.image,
                                size: 60,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Created: ${DateTime.parse(_scannedQrData!['createdAt']).toString().split('.')[0]}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],

          // Instructions
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to Use QR Codes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildInstructionItem(
                  '1. Create QR codes with important information',
                  Icons.create,
                ),
                _buildInstructionItem(
                  '2. Print and place them around your home',
                  Icons.print,
                ),
                _buildInstructionItem(
                  '3. Scan them anytime to get the information',
                  Icons.qr_code_scanner,
                ),
                _buildInstructionItem(
                  '4. Perfect for medication instructions, emergency contacts, etc.',
                  Icons.info,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> qrCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete QR Code'),
        content: Text('Are you sure you want to delete "${qrCode['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteQrCode(qrCode['id']);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
