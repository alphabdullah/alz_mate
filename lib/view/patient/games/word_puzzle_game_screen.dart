import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/game_score_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_storage_service.dart';

class WordPuzzleGameScreen extends StatefulWidget {
  const WordPuzzleGameScreen({super.key});

  @override
  State<WordPuzzleGameScreen> createState() => _WordPuzzleGameScreenState();
}

class _WordPuzzleGameScreenState extends State<WordPuzzleGameScreen> {
  final List<Map<String, dynamic>> _wordPool = [
    {'word': 'CAT', 'hint': 'Small pet', 'category': 'Animal'},
    {'word': 'DOG', 'hint': 'Faithful pet', 'category': 'Animal'},
    {'word': 'SUN', 'hint': 'Shines bright', 'category': 'Nature'},
    {'word': 'MOON', 'hint': 'Night light', 'category': 'Nature'},
    {'word': 'TREE', 'hint': 'Has leaves', 'category': 'Nature'},
    {'word': 'WATER', 'hint': 'You drink it', 'category': 'Nature'},
    {'word': 'APPLE', 'hint': 'Red fruit', 'category': 'Fruit'},
    {'word': 'MANGO', 'hint': 'King of fruits', 'category': 'Fruit'},
    {'word': 'ORANGE', 'hint': 'Citrus fruit', 'category': 'Fruit'},
    {'word': 'BANANA', 'hint': 'Yellow fruit', 'category': 'Fruit'},
    {'word': 'BRAIN', 'hint': 'Organ in your head', 'category': 'Body'},
    {'word': 'MEMORY', 'hint': 'Ability to remember', 'category': 'Mind'},
    {'word': 'PUZZLE', 'hint': 'A game or problem', 'category': 'Games'},
    {'word': 'LEARN', 'hint': 'To gain knowledge', 'category': 'Education'},
    {'word': 'THINK', 'hint': 'Use your mind', 'category': 'Mind'},
    {'word': 'SOLVE', 'hint': 'Find the answer', 'category': 'Action'},
    {'word': 'LOGIC', 'hint': 'Reasoning ability', 'category': 'Mind'},
    {'word': 'FOCUS', 'hint': 'Concentrate', 'category': 'Mind'},
    {'word': 'SMART', 'hint': 'Intelligent', 'category': 'Trait'},
    {'word': 'QUICK', 'hint': 'Fast', 'category': 'Speed'},
    {'word': 'PLANET', 'hint': 'Earth is one', 'category': 'Space'},
    {'word': 'ROCKET', 'hint': 'It launches', 'category': 'Space'},
    {'word': 'GALAXY', 'hint': 'Milky Way', 'category': 'Space'},
    {'word': 'TEACHER', 'hint': 'Guides students', 'category': 'People'},
    {'word': 'DOCTOR', 'hint': 'Heals people', 'category': 'People'},
    {'word': 'OFFICE', 'hint': 'Workplace', 'category': 'Place'},
    {'word': 'MARKET', 'hint': 'Buy and sell', 'category': 'Place'},
    {'word': 'LIBRARY', 'hint': 'Books live here', 'category': 'Place'},
    {'word': 'TRAVEL', 'hint': 'Go places', 'category': 'Action'},
  ];

  final List<Map<String, dynamic>> _levels = [
    {'words': 1, 'min': 3, 'max': 3},
    {'words': 1, 'min': 4, 'max': 4},
    {'words': 2, 'min': 3, 'max': 4},
    {'words': 1, 'min': 5, 'max': 5},
    {'words': 1, 'min': 6, 'max': 6},
    {'words': 2, 'min': 5, 'max': 6},
    {'words': 2, 'min': 6, 'max': 7},
    {'words': 2, 'min': 7, 'max': 8},
    {'words': 3, 'min': 5, 'max': 7},
    {'words': 3, 'min': 7, 'max': 8},
  ];

  bool _showMenu = true;
  String? _userId;
  int _resumeLevel = 1;
  int _highestLevel = 1;
  Set<String> _usedWords = {};
  List<Map<String, dynamic>> _currentLevelWords = [];
  int _currentWordIndex = 0;

  String _currentWord = '';
  String _scrambledWord = '';
  String _hint = '';
  String _category = '';
  String _userAnswer = '';
  int _level = 1;
  int _score = 0;
  int _correctAnswers = 0;
  Timer? _gameTimer;
  int _secondsElapsed = 0;
  bool _showHint = false;
  final TextEditingController _answerController = TextEditingController();

  final LocalStorageService _storageService = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _initUser() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    _userId = auth.currentUser?.uid ?? 'guest';
    await _loadProgress();
    if (mounted) setState(() {});
  }

  Future<void> _loadProgress() async {
    final data = await _storageService.getJson('word_puzzle_progress_$_userId');
    if (data != null) {
      _resumeLevel = data['currentLevel'] ?? 1;
      _highestLevel = data['highestLevel'] ?? 1;
      final used = data['usedWords'] as List<dynamic>?;
      if (used != null) {
        _usedWords = used.map((e) => e.toString()).toSet();
      }
    }
  }

  Future<void> _saveProgress() async {
    await _storageService.setJson('word_puzzle_progress_$_userId', {
      'currentLevel': _level,
      'highestLevel': _highestLevel,
      'usedWords': _usedWords.toList(),
    });
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _secondsElapsed = 0;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  String _scrambleWord(String word) {
    final letters = word.split('')..shuffle(Random());
    return letters.join().toUpperCase();
  }

  void _prepareLevel(int level) {
    final cfg = _levels[(level - 1).clamp(0, _levels.length - 1)];
    final needed = cfg['words'] as int;
    final minL = cfg['min'] as int;
    final maxL = cfg['max'] as int;
    final pool = _wordPool.where((w) {
      final len = w['word'].toString().length;
      return len >= minL && len <= maxL && !_usedWords.contains(w['word']);
    }).toList();
    pool.shuffle(Random());
    _currentLevelWords = pool.take(needed).toList();
    if (_currentLevelWords.length < needed) {
      final fallback = _wordPool.where((w) {
        final len = w['word'].toString().length;
        return len >= minL && len <= maxL;
      }).toList();
      fallback.shuffle(Random());
      for (final w in fallback) {
        if (_currentLevelWords.length >= needed) break;
        _currentLevelWords.add(w);
      }
    }
    _currentWordIndex = 0;
    _correctAnswers = 0;
    _loadCurrentWord();
  }

  void _loadCurrentWord() {
    if (_currentWordIndex >= _currentLevelWords.length) {
      _completeLevel();
      return;
    }
    final current = _currentLevelWords[_currentWordIndex];
    _currentWord = current['word'];
    _scrambledWord = _scrambleWord(_currentWord);
    _hint = current['hint'];
    _category = current['category'];
    _userAnswer = '';
    _showHint = false;
    _answerController.clear();
    _startTimer();
    setState(() {});
  }

  void _checkAnswer() {
    if (_userAnswer.trim().toUpperCase() == _currentWord.toUpperCase()) {
      _correctAnswers++;
      final timeBonus = (30 - _secondsElapsed).clamp(0, 30);
      final hintPenalty = _showHint ? 10 : 0;
      final points = 100 + timeBonus - hintPenalty;
      _score += points;
      _usedWords.add(_currentWord);
      _saveProgress();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Correct! +$points points'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _currentWordIndex++;
          _loadCurrentWord();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect. Try again!'),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _completeLevel() {
    _gameTimer?.cancel();
    _highestLevel = max(_highestLevel, _level);
    _saveProgress();
    _saveScoreToFirestore(duration: Duration(seconds: _secondsElapsed));
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🎉 Congratulations!'),
        content: Text('You completed Level $_level in Word Puzzles.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showMenu = true;
              });
            },
            child: const Text('Back to Menu'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _prepareLevel(_level);
              });
            },
            child: const Text('Replay Level'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_level < _levels.length) {
                setState(() {
                  _level++;
                  _prepareLevel(_level);
                });
              } else {
                setState(() {
                  _showMenu = true;
                });
              }
            },
            child: const Text('Next Level'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveScoreToFirestore({required Duration duration}) async {
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
          gameId: 'word_puzzle',
          gameName: 'Word Puzzle',
          gameType: 'language',
          score: _score,
          maxScore: 2000,
          playedAt: DateTime.now(),
          duration: duration,
          difficulty: 'medium',
          level: _level,
          accuracy: _currentLevelWords.isNotEmpty
              ? _correctAnswers / _currentLevelWords.length
              : 0.0,
          attempts: _currentLevelWords.length,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          gameData: {
            'correctAnswers': _correctAnswers,
            'wordsThisLevel': _currentLevelWords.length,
          },
        );
        await firestoreService.createGameScore(gameScore);
      }
    } catch (_) {
      // ignore save errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _showMenu ? 'Word Puzzles' : 'Word Puzzles - Level $_level',
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
      body: _showMenu ? _buildMenu() : _buildGame(),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        // Enhanced Stats Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                '$_level',
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

        // Progress Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.primary.withOpacity(0.05),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _currentLevelWords.isNotEmpty
                      ? (_currentWordIndex + 1) / _currentLevelWords.length
                      : 0,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentWordIndex + 1}/${_currentLevelWords.length}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              IconButton(
                onPressed: _showPauseMenu,
                icon: const Icon(Icons.pause_circle_filled),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),

        // Game Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                _buildCategoryBadge(),
                const SizedBox(height: 24),
                _buildScrambleCard(),
                const SizedBox(height: 24),
                _buildHintSection(),
                const SizedBox(height: 24),
                _buildAnswerInput(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenu() {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.warning.withOpacity(0.05), AppColors.background],
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
                    colors: [
                      AppColors.warning,
                      AppColors.warning.withOpacity(0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.text_fields,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Word Puzzles',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unscramble the words to solve puzzles.\nYour progress is automatically saved.',
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
                    colors: [
                      AppColors.warning,
                      AppColors.warning.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withOpacity(0.3),
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
                      _showMenu = false;
                      _prepareLevel(_level);
                    });
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
                      _prepareLevel(_level);
                    });
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
                  foregroundColor: AppColors.warning,
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.warning.withOpacity(0.2)),
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
          itemCount: _levels.length,
          itemBuilder: (context, index) {
            final lvl = index + 1;
            final cfg = _levels[index];
            return ListTile(
              leading: Icon(Icons.lock_open, color: AppColors.primary),
              title: Text('Level $lvl'),
              subtitle: Text(
                '${cfg['words']} word(s) • ${cfg['min']}-${cfg['max']} letters',
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _level = lvl;
                  _showMenu = false;
                  _prepareLevel(_level);
                });
              },
            );
          },
        ),
      ),
    );
  }

  void _showPauseMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Paused',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Restart Level'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _prepareLevel(_level);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Back to Menu'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _showMenu = true;
                  _gameTimer?.cancel();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.accent.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            _category,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrambleCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, AppColors.primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shuffle, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Unscramble the word:',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Text(
              _scrambledWord,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 6,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintSection() {
    return Column(
      children: [
        if (!_showHint)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showHint = true;
                });
              },
              icon: const Icon(Icons.lightbulb_outline, size: 24),
              label: const Text(
                'Show Hint',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning.withOpacity(0.1),
                foregroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
                ),
                elevation: 0,
              ),
            ),
          ),
        if (_showHint)
          Container(
            width: double.infinity,
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
                color: AppColors.info.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hint',
                        style: TextStyle(
                          color: AppColors.info,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hint,
                        style: TextStyle(
                          color: AppColors.info,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAnswerInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _answerController,
        onChanged: (value) {
          setState(() {
            _userAnswer = value.toUpperCase();
          });
        },
        onSubmitted: (_) => _checkAnswer(),
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        decoration: InputDecoration(
          hintText: 'Type your answer',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.5),
            fontSize: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary, width: 3),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _userAnswer.trim().isEmpty ? null : _checkAnswer,
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
