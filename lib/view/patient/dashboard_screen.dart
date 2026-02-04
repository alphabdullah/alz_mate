import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/user_model.dart';
import '../../core/models/reminder_model.dart';
import '../../core/models/mood_entry_model.dart';
import '../../core/models/journal_entry_model.dart';
import '../../core/models/game_score_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../widgets/custom_button.dart';
import 'mood_tracking_screen.dart';
import 'journal_screen.dart';
import 'reminder_screen.dart';
import 'brain_games_screen.dart';
import 'sos_button_screen.dart';
import 'emotion_trends_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  UserModel? _currentUser;
  List<ReminderModel> _todayReminders = [];
  List<MoodEntryModel> _recentMoods = [];
  List<JournalEntryModel> _recentJournalEntries = [];
  List<GameScoreModel> _recentGameScores = [];

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Statistics
  int _totalReminders = 0;
  int _completedReminders = 0;
  int _totalJournalEntries = 0;
  int _totalGamesSessions = 0;
  double _averageMoodScore = 0.0;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _loadDashboardData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
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

      final userId = authService.currentUser!.uid;

      // Load user data
      _currentUser = await firestoreService.getUserById(userId);
      await firestoreService.checkAndLogMissedReminders(userId);

      // Load today's reminders
      final allReminders = await firestoreService.getRemindersByUserId(userId);
      final today = DateTime.now();
      _todayReminders = allReminders.where((reminder) {
        return reminder.time.day == today.day &&
            reminder.time.month == today.month &&
            reminder.time.year == today.year;
      }).toList();

      // Load recent mood entries
      final allMoods = await firestoreService.getMoodEntriesByUserId(userId);
      _recentMoods = allMoods.take(5).toList();

      // Load recent journal entries
      final allJournalEntries = await firestoreService
          .getJournalEntriesByUserId(userId);
      _recentJournalEntries = allJournalEntries.take(3).toList();

      // Load recent game scores
      final allGameScores = await firestoreService.getGameScoresByUserId(
        userId,
      );
      _recentGameScores = allGameScores.take(5).toList();

      // Calculate statistics
      await _calculateStatistics(userId, firestoreService);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _calculateStatistics(
    String userId,
    FirestoreService firestoreService,
  ) async {
    try {
      // Reminder statistics
      final allReminders = await firestoreService.getRemindersByUserId(userId);
      _totalReminders = allReminders.length;
      _completedReminders = allReminders.where((r) => r.isCompleted).length;

      // Journal statistics
      final allJournalEntries = await firestoreService
          .getJournalEntriesByUserId(userId);
      _totalJournalEntries = allJournalEntries.length;

      // Game statistics
      final allGameScores = await firestoreService.getGameScoresByUserId(
        userId,
      );
      _totalGamesSessions = allGameScores.length;

      // Mood statistics
      final allMoods = await firestoreService.getMoodEntriesByUserId(userId);
      if (allMoods.isNotEmpty) {
        final totalScore = allMoods.fold<double>(
          0.0,
          (sum, mood) => sum + mood.score,
        );
        _averageMoodScore = totalScore / allMoods.length;
      }

      // Calculate streak (consecutive days with any activity)
      _streakDays = await _calculateActivityStreak(userId, firestoreService);
    } catch (e) {
      // Handle statistics calculation errors silently
      print('Error calculating statistics: $e');
    }
  }

  Future<int> _calculateActivityStreak(
    String userId,
    FirestoreService firestoreService,
  ) async {
    try {
      final now = DateTime.now();
      int streak = 0;

      for (int i = 0; i < 30; i++) {
        // Check last 30 days
        final checkDate = now.subtract(Duration(days: i));

        // Check if user had any activity on this date
        final hasActivity = await _hasActivityOnDate(
          userId,
          checkDate,
          firestoreService,
        );

        if (hasActivity) {
          streak++;
        } else if (i > 0) {
          // Don't break on first day (today)
          break;
        }
      }

      return streak;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> _hasActivityOnDate(
    String userId,
    DateTime date,
    FirestoreService firestoreService,
  ) async {
    try {
      // Check mood entries
      final moods = await firestoreService.getMoodEntriesByUserId(userId);
      final hasMoodEntry = moods.any(
        (mood) =>
            mood.timestamp.day == date.day &&
            mood.timestamp.month == date.month &&
            mood.timestamp.year == date.year,
      );

      if (hasMoodEntry) return true;

      // Check journal entries
      final journalEntries = await firestoreService.getJournalEntriesByUserId(
        userId,
      );
      final hasJournalEntry = journalEntries.any(
        (entry) =>
            entry.timestamp.day == date.day &&
            entry.timestamp.month == date.month &&
            entry.timestamp.year == date.year,
      );

      if (hasJournalEntry) return true;

      // Check game sessions
      final gameScores = await firestoreService.getGameScoresByUserId(userId);
      final hasGameSession = gameScores.any(
        (score) =>
            score.playedAt.day == date.day &&
            score.playedAt.month == date.month &&
            score.playedAt.year == date.year,
      );

      return hasGameSession;
    } catch (e) {
      return false;
    }
  }

  Future<void> _markReminderComplete(String reminderId) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      await firestoreService.updateReminder(reminderId, {
        'isCompleted': true,
        'completedAt': DateTime.now().toIso8601String(),
      });

      // Update local state
      final index = _todayReminders.indexWhere((r) => r.id == reminderId);
      if (index != -1) {
        setState(() {
          _todayReminders[index] = _todayReminders[index].copyWith(
            isCompleted: true,
            updatedAt: DateTime.now(),
          );
          _completedReminders++;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder completed!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating reminder: $e')));
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = _currentUser?.displayNameWithRole ?? 'there';

    if (hour < 12) {
      return 'Good morning, $name!';
    } else if (hour < 17) {
      return 'Good afternoon, $name!';
    } else {
      return 'Good evening, $name!';
    }
  }

  String _getMotivationalMessage() {
    if (_streakDays > 7) {
      return 'Amazing! You\'re on a $_streakDays-day streak! 🔥';
    } else if (_streakDays > 3) {
      return 'Great job! Keep up the momentum! 💪';
    } else if (_completedReminders > 0) {
      return 'You\'re doing great today! 🌟';
    } else {
      return 'Ready to make today amazing? 🚀';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
              ? _buildErrorState()
              : _buildDashboardContent(),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppColors.danger),
            const SizedBox(height: 24),
            Text('Something went wrong', style: AppStyles.titleLarge),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Try Again',
              onPressed: _loadDashboardData,
              width: 200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with greeting
            _buildHeader(),
            const SizedBox(height: 24),

            // Quick stats cards
            _buildQuickStats(),
            const SizedBox(height: 24),

            // Today's reminders
            _buildTodayReminders(),
            const SizedBox(height: 24),

            // Quick actions
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Recent activity
            _buildRecentActivity(),
            const SizedBox(height: 24),

            // Health insights
            _buildHealthInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  _currentUser?.displayNameWithRole
                          .substring(0, 1)
                          .toUpperCase() ??
                      'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMotivationalMessage(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // IconButton(
              //   onPressed: () {
              //     // Navigate to profile or settings
              //   },
              //   icon: const Icon(
              //     Icons.notifications_outlined,
              //     color: Colors.white,
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Streak',
            '$_streakDays days',
            Icons.local_fire_department,
            AppColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Mood Avg',
            '${(_averageMoodScore * 100).round()}%',
            Icons.mood,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            '$_completedReminders/$_totalReminders',
            Icons.check_circle,
            AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.elevatedCard,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayReminders() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Today\'s Reminders', style: AppStyles.titleMedium),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReminderScreen(),
                    ),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_todayReminders.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No reminders for today!',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _todayReminders.take(3).map((reminder) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: reminder.isCompleted
                        ? AppColors.success.withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: reminder.isCompleted
                          ? AppColors.success.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: reminder.isCompleted
                              ? AppColors.success.withOpacity(0.2)
                              : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          reminder.isCompleted
                              ? Icons.check
                              : Icons.notifications_active_rounded,
                          color: reminder.isCompleted
                              ? AppColors.success
                              : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: reminder.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              '${reminder.time.hour}:${reminder.time.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!reminder.isCompleted)
                        IconButton(
                          onPressed: () => _markReminderComplete(reminder.id),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.success,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppStyles.titleMedium),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildActionCard(
              'Log Mood',
              Icons.mood,
              AppColors.primary,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MoodTrackingScreen(),
                ),
              ),
            ),
            _buildActionCard(
              'Emotion Trends',
              Icons.show_chart,
              AppColors.accent,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmotionTrendsScreen(),
                ),
              ),
            ),
            _buildActionCard(
              'Write Journal',
              Icons.edit,
              AppColors.accent,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JournalScreen(),
                ),
              ),
            ),
            _buildActionCard(
              'Brain Games',
              Icons.psychology,
              AppColors.success,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BrainGamesScreen(),
                ),
              ),
            ),
            _buildActionCard(
              'SOS Alert',
              Icons.emergency,
              AppColors.danger,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SosButtonScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: AppStyles.titleMedium),
          const SizedBox(height: 16),
          if (_recentMoods.isEmpty &&
              _recentJournalEntries.isEmpty &&
              _recentGameScores.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.timeline,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No recent activity',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Recent moods
                ..._recentMoods
                    .take(2)
                    .map(
                      (mood) => _buildActivityItem(
                        mood.moodEmoji,
                        'Logged ${mood.moodDisplayName} mood',
                        mood.timestamp,
                        Color(mood.moodColorValue),
                      ),
                    ),

                // Recent journal entries
                ..._recentJournalEntries
                    .take(2)
                    .map(
                      (entry) => _buildActivityItem(
                        '📝',
                        'Wrote journal entry',
                        entry.timestamp,
                        AppColors.accent,
                      ),
                    ),

                // Recent game scores
                ..._recentGameScores
                    .take(1)
                    .map(
                      (score) => _buildActivityItem(
                        '🎮',
                        'Played ${score.gameName}',
                        score.playedAt,
                        AppColors.success,
                      ),
                    ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String emoji,
    String title,
    DateTime timestamp,
    Color color,
  ) {
    final timeAgo = _getTimeAgo(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
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
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInsights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Insights', style: AppStyles.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInsightItem(
                  'Journal Entries',
                  _totalJournalEntries.toString(),
                  Icons.book,
                  AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightItem(
                  'Game Sessions',
                  _totalGamesSessions.toString(),
                  Icons.games,
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
