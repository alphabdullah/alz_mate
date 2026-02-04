import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/mood_entry_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/mood_graph.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class MoodTrackingScreen extends StatefulWidget {
  const MoodTrackingScreen({super.key});

  @override
  State<MoodTrackingScreen> createState() => _MoodTrackingScreenState();
}

class _MoodTrackingScreenState extends State<MoodTrackingScreen>
    with SingleTickerProviderStateMixin {
  final _notesController = TextEditingController();

  List<MoodEntryModel> _moodEntries = [];
  bool _isLoading = false;
  bool _isLogging = false;
  String? _selectedMood;
  double _selectedScore = 0.5;
  final List<String> _selectedTriggers = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> moodOptions = [
    {'mood': 'very_happy', 'emoji': '😄', 'score': 1.0, 'color': 0xFF10B981},
    {'mood': 'happy', 'emoji': '😊', 'score': 0.8, 'color': 0xFF34D399},
    {'mood': 'neutral', 'emoji': '😐', 'score': 0.5, 'color': 0xFF6B7280},
    {'mood': 'sad', 'emoji': '😢', 'score': 0.3, 'color': 0xFFF59E0B},
    {'mood': 'very_sad', 'emoji': '😭', 'score': 0.1, 'color': 0xFFEF4444},
    {'mood': 'angry', 'emoji': '😠', 'score': 0.2, 'color': 0xFFDC2626},
  ];

  final List<String> _availableTriggers = [
    'Family time',
    'Exercise',
    'Medication',
    'Weather',
    'Sleep',
    'Food',
    'Social interaction',
    'Memory issues',
    'Physical discomfort',
    'Loneliness',
    'Routine change',
    'Music',
    'Nature',
    'Games',
    'Reading',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _loadMoodEntries();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMoodEntries() async {
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
        final entries = await firestoreService.getMoodEntriesByUserId(
          authService.currentUser!.uid,
        );
        setState(() {
          _moodEntries = entries;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading mood entries: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logMood() async {
    if (_selectedMood == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a mood')));
      return;
    }

    setState(() {
      _isLogging = true;
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

      final newEntry = MoodEntryModel(
        id: '', // Will be set by Firestore
        userId: authService.currentUser!.uid,
        mood: _selectedMood!,
        score: _selectedScore,
        timestamp: DateTime.now(),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        triggers: _selectedTriggers.isNotEmpty ? _selectedTriggers : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      final entryId = await firestoreService.createMoodEntry(newEntry);
      final savedEntry = newEntry.copyWith(id: entryId);

      // Update local list
      setState(() {
        _moodEntries.insert(0, savedEntry);
        _selectedMood = null;
        _selectedScore = 0.5;
        _selectedTriggers.clear();
        _notesController.clear();
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mood logged successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging mood: $e')));
    } finally {
      setState(() {
        _isLogging = false;
      });
    }
  }

  Future<void> _deleteMoodEntry(String entryId) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      await firestoreService.deleteMoodEntry(entryId);

      setState(() {
        _moodEntries.removeWhere((e) => e.id == entryId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mood entry deleted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting mood entry: $e')));
    }
  }

  Map<String, dynamic> _getMoodStatistics() {
    if (_moodEntries.isEmpty) {
      return {
        'total_entries': 0,
        'average_score': 0.0,
        'most_common_mood': 'neutral',
      };
    }

    final weekEntries = _moodEntries
        .where((entry) => DateTime.now().difference(entry.timestamp).inDays < 7)
        .toList();

    final totalScore = weekEntries.fold<double>(
      0.0,
      (sum, entry) => sum + entry.score,
    );
    final averageScore = weekEntries.isNotEmpty
        ? totalScore / weekEntries.length
        : 0.0;

    // Find most common mood
    final moodCounts = <String, int>{};
    for (final entry in weekEntries) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    }

    String mostCommonMood = 'neutral';
    int maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonMood = mood;
      }
    });

    return {
      'total_entries': weekEntries.length,
      'average_score': averageScore,
      'most_common_mood': mostCommonMood,
    };
  }

  void _showMoodLogger() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
                Text('How are you feeling?', style: AppStyles.titleLarge),
                const SizedBox(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mood Selection
                        Text('Select your mood', style: AppStyles.labelLarge),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.0,
                              ),
                          itemCount: moodOptions.length,
                          itemBuilder: (context, index) {
                            final mood = moodOptions[index];
                            final isSelected = _selectedMood == mood['mood'];

                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  _selectedMood = mood['mood'];
                                  _selectedScore = mood['score'];
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(mood['color']).withOpacity(0.1)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? Color(mood['color'])
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      mood['emoji'],
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      mood['mood']
                                              .toString()
                                              .substring(0, 1)
                                              .toUpperCase() +
                                          mood['mood']
                                              .toString()
                                              .substring(1)
                                              .replaceAll('_', ' '),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Color(mood['color'])
                                            : AppColors.textSecondary,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Intensity Slider
                        if (_selectedMood != null) ...[
                          Text('Intensity Level', style: AppStyles.labelLarge),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Low',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'High',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: _selectedScore,
                                  onChanged: (value) {
                                    setModalState(() {
                                      _selectedScore = value;
                                    });
                                  },
                                  activeColor: AppColors.primary,
                                  min: 0.1,
                                  max: 1.0,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Triggers
                        Text(
                          'What might have influenced your mood? (Optional)',
                          style: AppStyles.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableTriggers.map((trigger) {
                            final isSelected = _selectedTriggers.contains(
                              trigger,
                            );
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    _selectedTriggers.remove(trigger);
                                  } else {
                                    _selectedTriggers.add(trigger);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  trigger,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Notes
                        CustomTextField(
                          label: 'Additional Notes (Optional)',
                          hint: 'Describe what happened or how you feel...',
                          controller: _notesController,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                        isOutlined: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        text: 'Log Mood',
                        onPressed: _logMood,
                        isLoading: _isLogging,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mood Tracker'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showMoodLogger,
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
            : _moodEntries.isEmpty
            ? _buildEmptyState()
            : _buildMoodContent(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMoodLogger,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.mood, color: Colors.white),
        label: const Text('Log Mood', style: TextStyle(color: Colors.white)),
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
              child: const Icon(Icons.mood, size: 60, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('Start Tracking Your Mood', style: AppStyles.titleLarge),
            const SizedBox(height: 12),
            Text(
              'Understanding your emotions helps improve your wellbeing. Log your first mood entry to begin tracking patterns.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Log First Mood',
              onPressed: _showMoodLogger,
              width: 200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodContent() {
    return RefreshIndicator(
      onRefresh: _loadMoodEntries,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mood Graph
            MoodGraph(moodEntries: _moodEntries.take(7).toList()),
            const SizedBox(height: 20),

            // Statistics Card
            _buildStatisticsCard(),
            const SizedBox(height: 20),

            // Recent Entries
            Text('Recent Mood Entries', style: AppStyles.titleMedium),
            const SizedBox(height: 16),

            ..._moodEntries.take(10).map((entry) => _buildMoodEntryCard(entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = _getMoodStatistics();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week\'s Summary', style: AppStyles.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Entries',
                  stats['total_entries'].toString(),
                  Icons.edit,
                  AppColors.primary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Average',
                  '${(stats['average_score'] * 100).round()}%',
                  Icons.trending_up,
                  AppColors.success,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Most Common',
                  stats['most_common_mood']
                          .toString()
                          .substring(0, 1)
                          .toUpperCase() +
                      stats['most_common_mood']
                          .toString()
                          .substring(1)
                          .replaceAll('_', ' '),
                  Icons.mood,
                  AppColors.accent,
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
            fontSize: 18,
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

  Widget _buildMoodEntryCard(MoodEntryModel entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.elevatedCard,
      child: Row(
        children: [
          // Mood Emoji
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(entry.moodColorValue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                entry.moodEmoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.moodDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      entry.intensityText,
                      style: TextStyle(
                        color: Color(entry.moodColorValue),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.timestamp.day}/${entry.timestamp.month} at ${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (entry.notes != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.notes!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (entry.hasTriggers) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: entry.triggers!.take(3).map((trigger) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          trigger,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Delete button
          IconButton(
            onPressed: () => _showDeleteConfirmation(entry),
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.danger,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(MoodEntryModel entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mood Entry'),
        content: const Text('Are you sure you want to delete this mood entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMoodEntry(entry.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
