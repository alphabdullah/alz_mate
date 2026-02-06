import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/behavior_analysis_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/mood_entry_model.dart';
import '../../core/models/reminder_model.dart';
import '../../core/models/game_score_model.dart';
import '../../core/models/journal_entry_model.dart';
import '../../core/models/behavior_analysis_model.dart';
import '../../widgets/mood_graph.dart';
import 'behavior_analysis_result_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final UserModel patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();

  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  List<MoodEntryModel> _moodEntries = [];
  List<ReminderModel> _reminders = [];
  List<GameScoreModel> _gameScores = [];
  List<JournalEntryModel> _journalEntries = [];
  List<ReminderModel> _missedNotifications = [];
  List<BehaviorAnalysisModel> _behaviorAnalyses = [];
  bool _runningBehaviorAnalysis = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPatientData();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging &&
        _tabController.index == 3 &&
        mounted) {
      _loadBehaviorAnalyses();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBehaviorAnalyses() async {
    try {
      final list = await BehaviorAnalysisService()
          .getPatientAnalyses(widget.patient.id, limit: 500);
      if (mounted) setState(() => _behaviorAnalyses = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load analyses: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  _loadPatientMissedNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load missed notifications
      _missedNotifications = await _firestoreService.getMissedReminders(
        widget.patient.id,
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPatientData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      await _loadPatientMissedNotifications();
      // Load all patient data in parallel
      final results = await Future.wait([
        _firestoreService.getMoodEntriesByUserId(widget.patient.id),
        _firestoreService.getRemindersByUserId(widget.patient.id),
        _firestoreService.getGameScoresByUserId(widget.patient.id),
        _firestoreService.getJournalEntriesByUserId(widget.patient.id),
        BehaviorAnalysisService().getPatientAnalyses(widget.patient.id, limit: 500),
      ]);

      setState(() {
        _moodEntries = results[0] as List<MoodEntryModel>;
        _reminders = results[1] as List<ReminderModel>;
        _gameScores = results[2] as List<GameScoreModel>;
        _journalEntries = results[3] as List<JournalEntryModel>;
        _behaviorAnalyses = results[4] as List<BehaviorAnalysisModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runBehaviorAnalysis() async {
    if (_runningBehaviorAnalysis) return;
    setState(() => _runningBehaviorAnalysis = true);
    try {
      final analysis = await BehaviorAnalysisService().analyzePatientBehavior(
        widget.patient.id,
        saveToFirebase: true,
      );
      if (mounted) {
        setState(() {
          _behaviorAnalyses = [analysis, ..._behaviorAnalyses];
          _runningBehaviorAnalysis = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Behaviour analysis saved. Overall: ${analysis.overallGrade} (${analysis.overallScore.toStringAsFixed(0)}%)'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BehaviorAnalysisResultScreen(analysis: analysis),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _runningBehaviorAnalysis = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Color _healthStatusColor(String status) {
    switch (status) {
      case 'Excellent':
        return AppColors.success;
      case 'Good':
        return Colors.green;
      case 'Fair':
        return AppColors.warning;
      case 'Needs Attention':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
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
          title: Text(widget.patient.name, style: AppStyles.titleLarge),
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
          title: Text(widget.patient.name, style: AppStyles.titleLarge),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              Text('Error loading patient data', style: AppStyles.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, style: AppStyles.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPatientData,
                child: const Text('Retry'),
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
        title: Text(widget.patient.name, style: AppStyles.titleLarge),
        // actions: [
        //   IconButton(
        //     onPressed: () => _showMoreOptions(),
        //     icon: const Icon(Icons.more_vert, color: AppColors.text),
        //   ),
        // ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatientData,
        child: Column(
          children: [
            // Patient Header
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.elevatedCard,
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: widget.patient.profileImageUrl != null
                            ? NetworkImage(widget.patient.profileImageUrl!)
                            : null,
                        child: widget.patient.profileImageUrl == null
                            ? Text(
                                widget.patient.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: widget.patient.isActive
                                ? AppColors.success
                                : AppColors.textSecondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.patient.name, style: AppStyles.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          widget.patient.email,
                          style: AppStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildStatusChip(
                              widget.patient.isActive ? 'Online' : 'Offline',
                              widget.patient.isActive
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      // IconButton(
                      //   onPressed: () => _initiateCall(),
                      //   // icon: const Icon(Icons.phone, color: AppColors.success),
                      // ),
                      IconButton(
                        onPressed: () => _sendMessage(),
                        icon: const Icon(
                          Icons.message,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: TabBar(
                isScrollable: true, // allows long text to be shown
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                labelStyle: AppStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: AppStyles.bodyMedium,
                indicator: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Health'),
                  Tab(text: 'Activity'),
                  Tab(text: 'Behaviour'),
                  Tab(text: 'Missed Notifications'),
                ],
              ),
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildHealthTab(),
                  _buildActivityTab(),
                  _buildBehaviourTab(),
                  _buildMissedNotificationsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBehaviourTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildBehaviourAnalysisSection(),
    );
  }

  Widget _buildBehaviourAnalysisSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Behaviour Analysis', style: AppStyles.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _runningBehaviorAnalysis ? null : _runBehaviorAnalysis,
              icon: _runningBehaviorAnalysis
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics),
              label: Text(
                _runningBehaviorAnalysis
                    ? 'Running analysis…'
                    : 'Run new analysis',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_behaviorAnalyses.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._buildBehaviorAnalysesByMonth(),
          ],
        ],
      ),
    );
  }

  /// Groups analyses by month (newest first). Each month shows a header and all analyses for that month.
  List<Widget> _buildBehaviorAnalysesByMonth() {
    if (_behaviorAnalyses.isEmpty) return [];

    final Map<String, List<BehaviorAnalysisModel>> byMonth = {};
    for (final a in _behaviorAnalyses) {
      final key =
          '${a.analyzedAt.year}-${a.analyzedAt.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(a);
    }
    for (final list in byMonth.values) {
      list.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
    }
    final keys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    final List<Widget> widgets = [];
    for (final key in keys) {
      final analyses = byMonth[key]!;
      final year = int.parse(key.split('-')[0]);
      final month = int.parse(key.split('-')[1]);
      final monthLabel =
          DateFormat.yMMM().format(DateTime(year, month, 1));

      widgets.add(const SizedBox(height: 4));
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            monthLabel,
            style: AppStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      );
      for (final analysis in analyses) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildBehaviorAnalysisCard(analysis),
        ));
      }
    }
    return widgets;
  }

  Widget _buildBehaviorAnalysisCard(BehaviorAnalysisModel analysis) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                BehaviorAnalysisResultScreen(analysis: analysis),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        analysis.overallScore.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _healthStatusColor(analysis.healthStatus),
                        ),
                      ),
                      Text(
                        '${analysis.overallGrade} · ${analysis.healthStatus}',
                        style: AppStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _healthStatusColor(analysis.healthStatus)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(analysis.analyzedAt),
                    style: AppStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Period: ${DateFormat.yMMMd().format(analysis.periodStart)} – ${DateFormat.yMMMd().format(analysis.periodEnd)}',
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviourRow(
    String label,
    double score,
    IconData icon,
    int count,
    String subtitle,
  ) {
    final color = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.primary
            : score >= 40
                ? AppColors.warning
                : AppColors.danger;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
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
                '$subtitle · ${score.toStringAsFixed(0)}%',
                style: AppStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${score.toStringAsFixed(0)}%',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final todayReminders = _reminders.where((r) {
      final today = DateTime.now();
      return r.time.year == today.year &&
          r.time.month == today.month &&
          r.time.day == today.day;
    }).length;

    final avgMoodScore = _moodEntries.isNotEmpty
        ? _moodEntries.map((e) => e.score).reduce((a, b) => a + b) /
              _moodEntries.length
        : 0.0;

    final gamesPlayedToday = _gameScores.where((g) {
      final today = DateTime.now();
      return g.playedAt.year == today.year &&
          g.playedAt.month == today.month &&
          g.playedAt.day == today.day;
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Reminders Today',
                  todayReminders.toString(),
                  Icons.schedule,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Mood Score',
                  avgMoodScore.toStringAsFixed(1),
                  Icons.mood,
                  AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Games Played',
                  gamesPlayedToday.toString(),
                  Icons.games,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Journal Entries',
                  _journalEntries.length.toString(),
                  Icons.book,
                  AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent Activity
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent Activity', style: AppStyles.titleMedium),
                const SizedBox(height: 16),
                if (_moodEntries.isNotEmpty)
                  _buildActivityItem(
                    'Mood check-in: ${_getMoodText(_moodEntries.first.score)}',
                    _getTimeAgoText(_moodEntries.first.timestamp),
                    Icons.mood,
                    AppColors.accent,
                  ),
                if (_gameScores.isNotEmpty)
                  _buildActivityItem(
                    'Played ${_gameScores.first.gameType}',
                    _getTimeAgoText(_gameScores.first.playedAt),
                    Icons.games,
                    AppColors.primary,
                  ),
                if (_journalEntries.isNotEmpty)
                  _buildActivityItem(
                    'Added journal entry',
                    _getTimeAgoText(_journalEntries.first.createdAt),
                    Icons.book,
                    AppColors.success,
                  ),
                if (_moodEntries.isEmpty &&
                    _gameScores.isEmpty &&
                    _journalEntries.isEmpty)
                  Center(
                    child: Text(
                      'No recent activity',
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health Information
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Information', style: AppStyles.titleMedium),
                const SizedBox(height: 16),
                _buildHealthInfo(
                  'Age',
                  widget.patient.age?.toString() ?? 'N/A',
                ),
                _buildHealthInfo(
                  'Blood Type',
                  widget.patient.bloodType ?? 'N/A',
                ),
                _buildHealthInfo(
                  'Allergies',
                  widget.patient.allergies ?? 'None',
                ),
                _buildHealthInfo(
                  'Emergency Contact',
                  widget.patient.emergencyContact ?? 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Medications
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Medications', style: AppStyles.titleMedium),
                const SizedBox(height: 16),
                Text(
                  widget.patient.medications ?? 'No medications listed',
                  style: AppStyles.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Mood Tracking
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mood Tracking (Last 7 Days)',
                  style: AppStyles.titleMedium,
                ),
                const SizedBox(height: 16),
                if (_moodEntries.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: MoodGraph(
                      moodEntries: _moodEntries.take(7).toList(),
                    ),
                  )
                else
                  Center(
                    child: Text(
                      'No mood data available',
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    final todayReminders = _reminders.where((r) {
      final today = DateTime.now();
      return r.time.year == today.year &&
          r.time.month == today.month &&
          r.time.day == today.day;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today's Schedule
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s Schedule', style: AppStyles.titleMedium),
                const SizedBox(height: 16),
                if (todayReminders.isNotEmpty)
                  ...todayReminders
                      .take(3)
                      .map((reminder) => _buildReminderItem(reminder))
                else
                  Center(
                    child: Text(
                      'No reminders for today',
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Activity Log
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity Log', style: AppStyles.titleMedium),
                const SizedBox(height: 16),
                if (_moodEntries.isNotEmpty ||
                    _gameScores.isNotEmpty ||
                    _journalEntries.isNotEmpty) ...[
                  if (_moodEntries.isNotEmpty)
                    _buildActivityItem(
                      'Latest mood entry: ${_getMoodText(_moodEntries.first.score)}',
                      _formatDateTime(_moodEntries.first.timestamp),
                      Icons.mood,
                      AppColors.accent,
                    ),
                  if (_gameScores.isNotEmpty)
                    _buildActivityItem(
                      'Played ${_gameScores.first.gameType} - Score: ${_gameScores.first.score}',
                      _formatDateTime(_gameScores.first.playedAt),
                      Icons.games,
                      AppColors.primary,
                    ),
                  if (_journalEntries.isNotEmpty)
                    _buildActivityItem(
                      'Journal entry: ${_journalEntries.first.content}',
                      _formatDateTime(_journalEntries.first.createdAt),
                      Icons.book,
                      AppColors.success,
                    ),
                ] else
                  Center(
                    child: Text(
                      'No activity recorded',
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissedNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Missed Notifications List
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Missed Notifications', style: AppStyles.titleMedium),
                const SizedBox(height: 16),
                if (_missedNotifications.isNotEmpty)
                  ..._missedNotifications.map(
                    (reminder) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.danger.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_off,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reminder.title,
                                  style: AppStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _formatDateTime(reminder.time),
                                  style: AppStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Center(
                    child: Text(
                      'No missed notifications 🎉',
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderItem(ReminderModel reminder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatTime(reminder.time),
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String subtitle, bool value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              // Handle setting change
            },
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }

  String _getMoodText(double score) {
    if (score >= 8) return 'Very Happy';
    if (score >= 6) return 'Happy';
    if (score >= 4) return 'Neutral';
    if (score >= 2) return 'Sad';
    return 'Very Sad';
  }

  String _getTimeAgoText(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Patient Info'),
              onTap: () {
                Navigator.pop(context);
                _editPatientInfo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View History'),
              onTap: () {
                Navigator.pop(context);
                _viewHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Report'),
              onTap: () {
                Navigator.pop(context);
                _shareReport();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _initiateCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${widget.patient.name}...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _sendMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening message to ${widget.patient.name}...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _scheduleCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call scheduling feature coming soon!')),
    );
  }

  void _viewReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reports feature coming soon!')),
    );
  }

  void _emergencyContact() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Contacting emergency contact for ${widget.patient.name}...',
        ),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _editPatientInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit patient info feature coming soon!')),
    );
  }

  void _viewHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Patient history feature coming soon!')),
    );
  }

  void _shareReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share report feature coming soon!')),
    );
  }
}
