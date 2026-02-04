import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/data/mcq_questions_data.dart';
import '../../core/models/mcq_question_model.dart';
import '../../core/services/firestore_service.dart';
import '../../widgets/custom_button.dart';
import '../auth/login_screen.dart';

class MCQExamScreen extends StatefulWidget {
  final String userId;

  const MCQExamScreen({super.key, required this.userId});

  @override
  State<MCQExamScreen> createState() => _MCQExamScreenState();
}

class _MCQExamScreenState extends State<MCQExamScreen> {
  final List<MCQQuestionModel> _questions = MCQQuestionsData.getAlzheimersQuestions();
  final Map<int, int?> _answers = {};
  int _currentQuestionIndex = 0;
  bool _examStarted = false;
  bool _examCompleted = false;
  int _timeRemaining = 15 * 60; // 15 minutes in seconds
  Timer? _timer;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startExam() {
    setState(() {
      _examStarted = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        _submitExam();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _answers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitExam() async {
    if (_examCompleted) return;

    _timer?.cancel();

    setState(() {
      _examCompleted = true;
      _isSubmitting = true;
    });

    try {
      // Calculate score
      int correctAnswers = 0;
      final examAnswers = <Map<String, dynamic>>[];

      for (int i = 0; i < _questions.length; i++) {
        final question = _questions[i];
        final selectedAnswer = _answers[i];
        final isCorrect = selectedAnswer == question.correctAnswerIndex;

        if (isCorrect) correctAnswers++;

        examAnswers.add({
          'questionId': question.id,
          'selectedAnswer': selectedAnswer,
          'correctAnswer': question.correctAnswerIndex,
          'isCorrect': isCorrect,
        });
      }

      final score = correctAnswers;
      final percentage = (score / _questions.length) * 100;

      // Update caregiver application with exam results
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);

      await firestoreService.updateCaregiverApplicationExamResults(
        widget.userId,
        score,
        _questions.length,
        percentage,
        examAnswers,
      );

      // Show result dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Exam Completed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Your Score: $score/${_questions.length}'),
                Text('Percentage: ${percentage.toStringAsFixed(1)}%'),
                const SizedBox(height: 16),
                Text(
                  percentage >= 70
                      ? 'Congratulations! You passed the exam.'
                      : 'You did not pass. Please review and try again.',
                  style: TextStyle(
                    color: percentage >= 70
                        ? AppColors.success
                        : AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting exam: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildStartScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Caregiver Qualification Exam',
              style: AppStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'This exam consists of 10 multiple-choice questions about Alzheimer\'s disease and caregiving.',
              style: AppStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Text(
                        'Time Limit: 15 minutes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You must answer all questions within the time limit.',
                    style: AppStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Start Exam',
              onPressed: _startExam,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionScreen() {
    final question = _questions[_currentQuestionIndex];
    final selectedAnswer = _answers[_currentQuestionIndex];

    return Column(
      children: [
        // Timer and Progress
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.primary.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.timer,
                color: _timeRemaining < 300
                    ? AppColors.danger
                    : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(_timeRemaining),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _timeRemaining < 300
                      ? AppColors.danger
                      : AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                style: AppStyles.bodyMedium,
              ),
            ],
          ),
        ),

        // Question
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.question,
                  style: AppStyles.titleMedium,
                ),
                const SizedBox(height: 24),
                ...question.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = selectedAnswer == index;

                  return GestureDetector(
                    onTap: () => _selectAnswer(index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: 2,
                              ),
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.text,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Navigation Buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: CustomButton(
                    text: 'Previous',
                    onPressed: _previousQuestion,
                    backgroundColor: AppColors.textSecondary,
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 16),
              Expanded(
                child: CustomButton(
                  text: _currentQuestionIndex == _questions.length - 1
                      ? 'Submit Exam'
                      : 'Next',
                  onPressed: _currentQuestionIndex == _questions.length - 1
                      ? _submitExam
                      : _nextQuestion,
                  isLoading: _isSubmitting,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Caregiver Exam'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _examStarted ? _buildQuestionScreen() : _buildStartScreen(),
    );
  }
}

