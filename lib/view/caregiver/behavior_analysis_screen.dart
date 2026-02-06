import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/behavior_analysis_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/behavior_analysis_model.dart';
import 'behavior_analysis_result_screen.dart';

class BehaviorAnalysisScreen extends StatefulWidget {
  const BehaviorAnalysisScreen({super.key});

  @override
  State<BehaviorAnalysisScreen> createState() => _BehaviorAnalysisScreenState();
}

class _BehaviorAnalysisScreenState extends State<BehaviorAnalysisScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final BehaviorAnalysisService _behaviorService = BehaviorAnalysisService();

  bool _isLoading = true;
  String? _error;
  List<UserModel> _patients = [];
  Map<String, BehaviorAnalysisModel> _latestAnalyses = {};
  String? _runningPatientId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Not authenticated');
      }
      final patients =
          await _firestoreService.getCaregiverPatients(user.uid);
      final analyses =
          await _behaviorService.getCaregiverPatientsAnalyses(user.uid);
      setState(() {
        _patients = patients;
        _latestAnalyses = analyses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runAnalysis(UserModel patient) async {
    setState(() => _runningPatientId = patient.id);
    try {
      final analysis = await _behaviorService.analyzePatientBehavior(
        patient.id,
        saveToFirebase: true,
      );
      if (!mounted) return;
      setState(() {
        _latestAnalyses[patient.id] = analysis;
        _runningPatientId = null;
      });
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BehaviorAnalysisResultScreen(analysis: analysis),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _runningPatientId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _viewResult(BehaviorAnalysisModel analysis) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BehaviorAnalysisResultScreen(analysis: analysis),
      ),
    );
  }

  Color _gradeColor(String grade) {
    if (grade.startsWith('A')) return AppColors.success;
    if (grade.startsWith('B')) return AppColors.primary;
    if (grade.startsWith('C')) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Behaviour Analysis', style: AppStyles.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: AppColors.danger),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading data',
                          style: AppStyles.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: AppStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _patients.isEmpty
                  ? Center(
                      child: Text(
                        'No patients assigned',
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _patients.length,
                        itemBuilder: (context, index) {
                          final patient = _patients[index];
                          final latest = _latestAnalyses[patient.id];
                          final isRunning = _runningPatientId == patient.id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: AppStyles.elevatedCard,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          AppColors.primary.withOpacity(0.1),
                                      backgroundImage:
                                          patient.profileImageUrl != null
                                              ? NetworkImage(
                                                  patient.profileImageUrl!)
                                              : null,
                                      child: patient.profileImageUrl == null
                                          ? Text(
                                              patient.name[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            patient.name,
                                            style: AppStyles.bodyMedium
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight.w600),
                                          ),
                                          if (latest != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _gradeColor(
                                                              latest
                                                                  .overallGrade)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(6),
                                                    ),
                                                    child: Text(
                                                      '${latest.overallGrade} · ${latest.overallScore.toStringAsFixed(0)}%',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: _gradeColor(
                                                            latest.overallGrade),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    latest.healthStatus,
                                                    style: AppStyles.bodySmall
                                                        .copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4),
                                              child: Text(
                                                'No analysis yet',
                                                style: AppStyles.bodySmall
                                                    .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (latest != null)
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: isRunning
                                              ? null
                                              : () =>
                                                  _viewResult(latest),
                                          icon: const Icon(
                                            Icons.visibility,
                                            size: 18,
                                          ),
                                          label: const Text('View result'),
                                        ),
                                      ),
                                    if (latest != null) const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: isRunning
                                            ? null
                                            : () => _runAnalysis(patient),
                                        icon: isRunning
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.analytics,
                                                size: 18),
                                        label: Text(
                                          isRunning
                                              ? 'Running…'
                                              : latest != null
                                                  ? 'Run new'
                                                  : 'Run analysis',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
