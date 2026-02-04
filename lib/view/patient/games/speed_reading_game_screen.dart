import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/game_score_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'game_result_screen.dart';

class SpeedReadingGameScreen extends StatefulWidget {
  const SpeedReadingGameScreen({super.key});

  @override
  State<SpeedReadingGameScreen> createState() => _SpeedReadingGameScreenState();
}

class _SpeedReadingGameScreenState extends State<SpeedReadingGameScreen> {
  final List<Map<String, dynamic>> _passages = [
    {
      'text':
          'Memory is the ability to store and retrieve information. It plays a crucial role in learning and daily life. There are different types of memory including short-term and long-term memory.',
      'questions': [
        {
          'question': 'What is memory?',
          'options': [
            'Ability to store and retrieve information',
            'Ability to forget things',
            'Ability to think fast',
            'Ability to read quickly',
          ],
          'correct': 0,
        },
        {
          'question': 'What are the types of memory mentioned?',
          'options': [
            'Short-term and long-term',
            'Fast and slow',
            'Good and bad',
            'Old and new',
          ],
          'correct': 0,
        },
      ],
    },
    {
      'text':
          'Exercise is important for brain health. Regular physical activity improves memory, focus, and cognitive function. Even simple activities like walking can benefit your brain significantly.',
      'questions': [
        {
          'question': 'What does exercise improve?',
          'options': [
            'Memory, focus, and cognitive function',
            'Only physical strength',
            'Only appearance',
            'Nothing',
          ],
          'correct': 0,
        },
        {
          'question': 'What simple activity is mentioned?',
          'options': ['Walking', 'Running', 'Swimming', 'Cycling'],
          'correct': 0,
        },
      ],
    },
    {
      'text':
          'Sleep is essential for memory consolidation. During sleep, your brain processes and stores information from the day. Getting enough quality sleep helps improve learning and memory retention.',
      'questions': [
        {
          'question': 'What happens during sleep?',
          'options': [
            'Brain processes and stores information',
            'Brain stops working',
            'Brain forgets everything',
            'Nothing important',
          ],
          'correct': 0,
        },
        {
          'question': 'What does quality sleep help improve?',
          'options': [
            'Learning and memory retention',
            'Only physical health',
            'Only appearance',
            'Nothing',
          ],
          'correct': 0,
        },
      ],
    },
  ];

  Map<String, dynamic>? _currentPassage;
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  int _correctAnswers = 0;
  int _level = 1;
  int _highestLevel = 1;
  int _resumeLevel = 1;
  int _score = 0;
  bool _readingPhase = true;
  bool _gameOver = false;
  bool _showMenu = true;
  String? _userId;
  Timer? _readingTimer;
  Timer? _gameTimer;
  int _secondsElapsed = 0;
  int _readingTime = 0;
  final LocalStorageService _storageService = LocalStorageService();
  DateTime? _gameStartTime;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _initUser() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    _userId = auth.currentUser?.uid ?? 'guest';
    await _loadProgress();
    if (mounted) setState(() {});
  }

  Future<void> _loadProgress() async {
    final data = await _storageService.getJson(
      'speed_reading_progress_${_userId ?? "guest"}',
    );
    if (data != null) {
      _resumeLevel = data['currentLevel'] ?? 1;
      _highestLevel = data['highestLevel'] ?? 1;
      _score = data['score'] ?? 0;
    }
  }

  Future<void> _saveProgress() async {
    await _storageService.setJson(
      'speed_reading_progress_${_userId ?? "guest"}',
      {'currentLevel': _level, 'highestLevel': _highestLevel, 'score': _score},
    );
  }

  void _startGame() {
    _gameOver = false;
    _readingPhase = true;
    _currentQuestionIndex = 0;
    _selectedAnswer = null;
    _correctAnswers = 0;
    _readingTime = 0;
    _secondsElapsed = 0;
    _gameStartTime = DateTime.now();
    _readingTimer?.cancel();
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_gameOver) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
    _loadPassage();
  }

  void _loadPassage() {
    _currentPassage = _passages[Random().nextInt(_passages.length)];
    _currentQuestionIndex = 0;
    _selectedAnswer = null;
    _readingPhase = true;
    _readingTime = 0;

    // Start reading timer
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_readingPhase) {
        setState(() {
          _readingTime++;
        });
      } else {
        timer.cancel();
      }
    });

    setState(() {});
  }

  void _startQuestions() {
    setState(() {
      _readingPhase = false;
    });
  }

  void _selectAnswer(int index) {
    setState(() {
      _selectedAnswer = index;
    });
  }

  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    final question = _currentPassage!['questions'][_currentQuestionIndex];
    final isCorrect = _selectedAnswer == question['correct'];

    if (isCorrect) {
      _correctAnswers++;
      final timeBonus = (30 - _readingTime).clamp(0, 30);
      _score += 100 + timeBonus;
    }

    if (_currentQuestionIndex < _currentPassage!['questions'].length - 1) {
      // Next question
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
      });
    } else {
      // All questions answered
      if (_correctAnswers == _currentPassage!['questions'].length) {
        _score += 200; // Perfect score bonus
      }
      final completedLevel = _level;
      _highestLevel = max(_highestLevel, completedLevel);
      final nextLevel = _level + 1;
      _level = nextLevel;
      _resumeLevel = nextLevel;
      _saveProgress();
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    _gameTimer?.cancel();
    _readingTimer?.cancel();
    _gameOver = true;

    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!)
        : Duration(seconds: _secondsElapsed);

    final totalQuestions = _currentPassage!['questions'].length;
    final accuracy = totalQuestions > 0
        ? _correctAnswers / totalQuestions
        : 0.0;

    // Get previous best score
    final bestScoreKey = 'speed_reading_best_score';
    final previousBest = await _storageService.getInt(bestScoreKey);

    // Save new best if achieved
    if (previousBest == null || _score > previousBest) {
      await _storageService.setInt(bestScoreKey, _score);
    }

    _saveProgress();

    // Save to Firestore
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      if (authService.currentUser != null) {
        final gameScore = GameScoreModel(
          id: '',
          userId: authService.currentUser!.uid,
          gameId: 'speed_reading',
          gameName: 'Speed Reading',
          gameType: 'language',
          score: _score,
          maxScore: 2000,
          playedAt: DateTime.now(),
          duration: duration,
          difficulty: 'medium',
          level: 1,
          accuracy: accuracy,
          attempts: totalQuestions,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          gameData: {
            'correctAnswers': _correctAnswers,
            'totalQuestions': totalQuestions,
            'readingTime': _readingTime,
          },
        );

        await firestoreService.createGameScore(gameScore);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameResultScreen(
                score: gameScore.copyWith(id: 'temp'),
                previousBestScore: previousBest,
                onPlayAgain: () {
                  Navigator.pop(context);
                  setState(() {
                    _score = 0;
                    _correctAnswers = 0;
                    _secondsElapsed = 0;
                    _gameOver = false;
                    _gameStartTime = null;
                    _showMenu = false;
                  });
                  _startGame();
                },
                onFinish: () async {
                  Navigator.pop(context);
                  await _saveProgress();
                  setState(() {
                    _showMenu = true;
                  });
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving score: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _showMenu ? 'Speed Reading' : 'Speed Reading - Level $_level',
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (!_showMenu) {
              await _saveProgress();
            }
            Navigator.pop(context);
          },
        ),
      ),
      body: _showMenu
          ? _buildMenu()
          : _currentPassage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Enhanced Stats Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEnhancedStat(
                        Icons.flag,
                        'Level',
                        _level.toString(),
                        AppColors.accent,
                      ),
                      _buildEnhancedStat(
                        Icons.star,
                        'Score',
                        _score.toString(),
                        AppColors.primary,
                      ),
                      _buildEnhancedStat(
                        Icons.timer,
                        'Time',
                        _formatTime(_secondsElapsed),
                        AppColors.accent,
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: _readingPhase
                        ? _buildReadingView()
                        : _buildQuestionView(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMenu() {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.info.withOpacity(0.05), AppColors.background],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Game Icon and Title
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.info, AppColors.info.withOpacity(0.8)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.info.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_book,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Speed Reading',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Read quickly, then answer questions to test comprehension.\nYour progress is automatically saved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      Icons.flag,
                      'Level',
                      '$_resumeLevel',
                      AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      Icons.trending_up,
                      'Highest',
                      '$_highestLevel',
                      AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      Icons.star,
                      'Score',
                      '$_score',
                      AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Play Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.info, AppColors.info.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.info.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _level = 1;
                      _score = 0;
                      _correctAnswers = 0;
                      _showMenu = false;
                    });
                    _startGame();
                  },
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: const Text(
                    'Play from Level 1',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Resume Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _level = _resumeLevel;
                      _showMenu = false;
                    });
                    _startGame();
                  },
                  icon: Icon(Icons.refresh, color: AppColors.success, size: 24),
                  label: Text(
                    'Resume Level $_resumeLevel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Level Select Button
              ElevatedButton.icon(
                onPressed: _showLevelSelect,
                icon: const Icon(Icons.grid_view, size: 24),
                label: const Text(
                  'Level Select',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.info,
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.info.withOpacity(0.2)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Back Button
              OutlinedButton.icon(
                onPressed: () async {
                  await _saveProgress();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('Back to All Games'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(double.infinity, 52),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showLevelSelect() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView.builder(
          itemCount: 15,
          itemBuilder: (context, index) {
            final lvl = index + 1;
            return ListTile(
              leading: Icon(Icons.lock_open, color: AppColors.primary),
              title: Text('Level $lvl'),
              subtitle: const Text('New passage'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _level = lvl;
                  _showMenu = false;
                });
                _startGame();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildReadingView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.info.withOpacity(0.15),
                AppColors.info.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.info.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reading Time',
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$_readingTime seconds',
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, AppColors.primary.withOpacity(0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Text(
                _currentPassage!['text'],
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.8,
                  letterSpacing: 0.5,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _startQuestions,
            icon: const Icon(Icons.check_circle, size: 24),
            label: const Text(
              'I\'m Done Reading',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionView() {
    final question = _currentPassage!['questions'][_currentQuestionIndex];
    final questionNumber = _currentQuestionIndex + 1;
    final totalQuestions = _currentPassage!['questions'].length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withOpacity(0.2),
                AppColors.accent.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.quiz, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Question $questionNumber of $totalQuestions',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, AppColors.primary.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            question['question'],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: question['options'].length,
            itemBuilder: (context, index) {
              final isSelected = _selectedAnswer == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () => _selectAnswer(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.15),
                                AppColors.primary.withOpacity(0.05),
                              ],
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.2)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: isSelected ? 12 : 5,
                          spreadRadius: isSelected ? 1 : 0,
                          offset: Offset(0, isSelected ? 4 : 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Colors.white,
                                )
                              : Center(
                                  child: Text(
                                    String.fromCharCode(
                                      65 + index,
                                    ), // A, B, C, D
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            question['options'][index],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _selectedAnswer == null ? null : _submitAnswer,
            icon: const Icon(Icons.send, size: 24),
            label: const Text(
              'Submit Answer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedStat(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
