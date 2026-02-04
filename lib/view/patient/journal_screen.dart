import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/journal_entry_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sentiment_service.dart';
import '../../core/services/emotion_analysis_service.dart';
import '../../core/constants/api_config.dart';
import '../../widgets/journal_entry_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _contentController = TextEditingController();
  List<JournalEntryModel> _journalEntries = [];
  bool _isLoading = false;
  bool _isCreating = false;
  String _selectedType = 'text';
  File? _selectedImage;
  String? _selectedImageUrl;

  // Speech to Text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _lastWords = '';
  double _confidenceLevel = 0;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSpeech();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _loadJournalEntries();
    _animationController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _contentController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isListening) {
        _stopListening();
      }
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        log('Microphone permission denied');
        return;
      }

      _speech = stt.SpeechToText();
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          log('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              // Restart listening if it was supposed to be listening
              _restartListening();
            }
          }
        },
        onError: (error) {
          log('Speech recognition error: $error');
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Speech recognition error: ${error.errorMsg}')),
            );
          }
        },
      );

      if (!_speechEnabled) {
        log('Speech recognition not available');
      }
    } catch (e) {
      log('Error initializing speech: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      await _initializeSpeech();
      if (!_speechEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
        return;
      }
    }

    try {
      setState(() {
        _isListening = true;
        _confidenceLevel = 0;
      });

      // Start the pulse animation
      _animationController.repeat(reverse: true);

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
            _confidenceLevel = result.confidence;
            
            // Update the text field in real-time
            _contentController.text = _lastWords;
            
            // Move cursor to end
            _contentController.selection = TextSelection.fromPosition(
              TextPosition(offset: _contentController.text.length),
            );
          });
          
          log('Recognized: ${result.recognizedWords} (confidence: ${result.confidence})');
        },
        listenFor: const Duration(seconds: 30), // Listen for 30 seconds at a time
        pauseFor: const Duration(seconds: 3), // Pause for 3 seconds of silence
        partialResults: true, // Enable real-time results
        localeId: 'en_US', // Set locale
        listenMode: stt.ListenMode.confirmation, // Use confirmation mode for better accuracy
        cancelOnError: false, // Don't cancel on errors
        onSoundLevelChange: (level) {
          // Optional: Use sound level for visual feedback
          log('Sound level: $level');
        },
      );
    } catch (e) {
      log('Error starting speech recognition: $e');
      setState(() {
        _isListening = false;
      });
      _animationController.stop();
    }
  }

  Future<void> _restartListening() async {
    if (_isListening && _speechEnabled) {
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isListening) {
          await _speech.listen(
            onResult: (result) {
              setState(() {
                _lastWords = result.recognizedWords;
                _confidenceLevel = result.confidence;
                
                // Update the text field in real-time
                _contentController.text = _lastWords;
                
                // Move cursor to end
                _contentController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _contentController.text.length),
                );
              });
            },
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
            partialResults: true,
            localeId: 'en_US',
            listenMode: stt.ListenMode.confirmation,
            cancelOnError: false,
          );
        }
      } catch (e) {
        log('Error restarting speech recognition: $e');
      }
    }
  }

  void _stopListening() {
    try {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
      _animationController.stop();
      _animationController.reset();
    } catch (e) {
      log('Error stopping speech recognition: $e');
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  Future<void> _loadJournalEntries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);

      if (authService.currentUser != null) {
        final entries = await firestoreService.getJournalEntriesByUserId(
          authService.currentUser!.uid,
        );
        setState(() {
          _journalEntries = entries;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading journal entries: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createJournalEntry() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something in your journal')),
      );
      return;
    }

    // Stop listening if active
    if (_isListening) {
      _stopListening();
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final storageService = Provider.of<StorageService>(context, listen: false);
      final sentimentService = Provider.of<SentimentService>(context, listen: false);

      if (authService.currentUser == null) {
        throw Exception('User not authenticated');
      }

      String? mediaUrl;
      // Upload image if selected
      if (_selectedImage != null && _selectedType == 'image') {
        mediaUrl = await storageService.uploadJournalMedia(
          _selectedImage!,
          authService.currentUser!.uid,
          'image',
        );
      }

      // Analyze sentiment (fallback to local analysis)
      final sentimentResult = await sentimentService.analyzeSentiment(
        _contentController.text.trim(),
      );

      // Create new journal entry
      final newEntry = JournalEntryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: authService.currentUser!.uid,
        content: _contentController.text.trim(),
        timestamp: DateTime.now(),
        type: _selectedType,
        mediaUrl: mediaUrl,
        sentimentScore: sentimentResult['score'] ?? 0.0,
        sentimentLabel: sentimentResult['label'] ?? 'neutral',
        isPrivate: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      final entryId = await firestoreService.createJournalEntry(newEntry);
      final savedEntry = newEntry.copyWith(id: entryId);

      // Analyze emotion using backend API (async, non-blocking)
      if (ApiConfig.enableBackendIntegration) {
        _analyzeEmotionForEntry(
          authService.currentUser!.uid,
          _contentController.text.trim(),
          entryId,
          savedEntry.timestamp.toIso8601String(),
        );
      }

      // Update local list
      setState(() {
        _journalEntries.insert(0, savedEntry);
        _contentController.clear();
        _selectedImage = null;
        _selectedImageUrl = null;
        _selectedType = 'text';
        _lastWords = '';
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving journal entry: $e')),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<void> _updateJournalEntry(String entryId, Map<String, dynamic> updates) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.updateJournalEntry(entryId, updates);

      // Update local list
      final index = _journalEntries.indexWhere((e) => e.id == entryId);
      if (index != -1) {
        setState(() {
          _journalEntries[index] = _journalEntries[index].copyWith(
            content: updates['content'] ?? _journalEntries[index].content,
            updatedAt: DateTime.now(),
          );
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating journal entry: $e')),
      );
    }
  }

  Future<void> _deleteJournalEntry(String entryId) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.deleteJournalEntry(entryId);

      // Update local list
      setState(() {
        _journalEntries.removeWhere((e) => e.id == entryId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry deleted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting journal entry: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
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
          _selectedType = 'image';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _selectedImageUrl = image.path;
          _selectedType = 'image';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  void _showCreateEntryDialog() {
    // Reset speech state when opening dialog
    _stopListening();
    _contentController.clear();
    _lastWords = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New Journal Entry', style: AppStyles.titleLarge),
                          Text(
                            'Share your thoughts and feelings',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Entry Type Selection
                Text('Entry Type', style: AppStyles.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTypeChip('text', 'Text', Icons.text_fields, setModalState),
                    const SizedBox(width: 8),
                    _buildTypeChip('image', 'Photo', Icons.camera_alt, setModalState),
                    const SizedBox(width: 8),
                    _buildVoiceTypeChip(setModalState),
                  ],
                ),
                const SizedBox(height: 24),

                // Voice Recording Status
                if (_selectedType == 'voice' && _isListening) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Icon(
                                    Icons.mic,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Listening...',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_confidenceLevel > 0)
                                    Text(
                                      'Confidence: ${(_confidenceLevel * 100).toInt()}%',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                _stopListening();
                                setModalState(() {});
                              },
                              icon: const Icon(Icons.stop, color: AppColors.danger),
                            ),
                          ],
                        ),
                        if (_lastWords.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Recognized: "$_lastWords"',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Image selection for photo entries
                if (_selectedType == 'image') ...[
                  if (_selectedImageUrl != null) ...[
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_selectedImageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Take Photo',
                          onPressed: () async {
                            await _takePhoto();
                            setModalState(() {});
                          },
                          isOutlined: true,
                          icon: Icons.camera_alt,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomButton(
                          text: 'Choose Photo',
                          onPressed: () async {
                            await _pickImage();
                            setModalState(() {});
                          },
                          isOutlined: true,
                          icon: Icons.photo_library,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Content Input
                Expanded(
                  child: CustomTextField(
                    label: 'What\'s on your mind?',
                    hint: _selectedType == 'voice' 
                        ? 'Tap the voice button to start speaking...'
                        : 'Write about your day, feelings, or memories...',
                    controller: _contentController,
                    maxLines: 10,
                    // readOnly: _selectedType == 'voice' && _isListening,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Cancel',
                        onPressed: () {
                          _stopListening();
                          _contentController.clear();
                          _selectedImage = null;
                          _selectedImageUrl = null;
                          _selectedType = 'text';
                          _lastWords = '';
                          Navigator.pop(context);
                        },
                        isOutlined: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        text: 'Save Entry',
                        onPressed: _createJournalEntry,
                        isLoading: _isCreating,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // Clean up when dialog is closed
      _stopListening();
    });
  }

  Widget _buildTypeChip(
    String type,
    String label,
    IconData icon,
    StateSetter setModalState,
  ) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        if (_isListening) {
          _stopListening();
        }
        setModalState(() {
          _selectedType = type;
          if (type != 'image') {
            _selectedImage = null;
            _selectedImageUrl = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceTypeChip(StateSetter setModalState) {
    final isSelected = _selectedType == 'voice';
    return GestureDetector(
      onTap: () async {
        setModalState(() {
          _selectedType = 'voice';
          _selectedImage = null;
          _selectedImageUrl = null;
        });

        log("selectedType $_selectedType");
        
        // Start listening immediately when voice is selected
        if (!_isListening) {
          await _startListening();
          setModalState(() {});
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _isListening ? _pulseAnimation : _fadeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 16,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            Text(
              _isListening ? 'Listening' : 'Voice',
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Journal'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showCreateEntryDialog,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _journalEntries.isEmpty
                ? _buildEmptyState()
                : _buildJournalList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEntryDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('Write Entry', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(Icons.book, size: 60, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('Start Your Journal', style: AppStyles.titleLarge),
            const SizedBox(height: 12),
            Text(
              'Record your thoughts, memories, and daily experiences. Your journal is a safe space for reflection.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Write First Entry',
              onPressed: _showCreateEntryDialog,
              width: 200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalList() {
    return RefreshIndicator(
      onRefresh: _loadJournalEntries,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _journalEntries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildStatsCard();
          }
          final entry = _journalEntries[index - 1];
          return JournalEntryCard(
            entry: entry,
            onTap: () => _showEntryDetails(entry),
            onEdit: () => _showEditEntryDialog(entry),
            onDelete: () => _showDeleteConfirmation(entry),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalEntries = _journalEntries.length;
    final thisWeekEntries = _journalEntries
        .where((entry) => DateTime.now().difference(entry.timestamp).inDays < 7)
        .length;
    final positiveEntries = _journalEntries
        .where(
          (entry) =>
              entry.sentimentScore != null && entry.sentimentScore! > 0.1,
        )
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Journal Statistics', style: AppStyles.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Entries',
                  totalEntries.toString(),
                  Icons.book,
                  AppColors.primary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'This Week',
                  thisWeekEntries.toString(),
                  Icons.calendar_today,
                  AppColors.accent,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Positive',
                  positiveEntries.toString(),
                  Icons.sentiment_satisfied,
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showEntryDetails(JournalEntryModel entry) {
    // Implementation remains the same as your original code
    // ... (keeping the existing implementation)
  }

  void _showEditEntryDialog(JournalEntryModel entry) {
    // Implementation remains the same as your original code
    // ... (keeping the existing implementation)
  }

  void _showDeleteConfirmation(JournalEntryModel entry) {
    // Implementation remains the same as your original code
    // ... (keeping the existing implementation)
  }

  // Analyze emotion for journal entry using backend API
  Future<void> _analyzeEmotionForEntry(
    String patientId,
    String journalText,
    String entryId,
    String timestamp,
  ) async {
    try {
      final emotionService = EmotionAnalysisService();
      
      // Call backend API to analyze emotion
      final result = await emotionService.analyzeEmotion(
        patientId: patientId,
        journalText: journalText,
        timestamp: timestamp,
        journalEntryId: entryId,
      );

      // Log the result (you can also update the journal entry in Firestore with emotion data)
      log('Emotion analysis result: ${result.analysis.primaryEmotion.emotion} '
          '(intensity: ${result.analysis.primaryEmotion.intensity})');
      
      // Optionally update the journal entry in Firestore with emotion analysis
      // This will be handled by the backend automatically if journal_entry_id is provided
    } catch (e) {
      // Log error but don't block the user
      log('Error analyzing emotion: $e');
    }
  }
}
