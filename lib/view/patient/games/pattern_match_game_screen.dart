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

class PatternMatchGameScreen extends StatefulWidget {
  const PatternMatchGameScreen({super.key});

  @override
  State<PatternMatchGameScreen> createState() => _PatternMatchGameScreenState();
}

class _PatternMatchGameScreenState extends State<PatternMatchGameScreen> {
  List<List<bool>> _pattern = [];
  List<List<bool>> _userPattern = [];
  int _gridSize = 3;
  int _level = 1;
  int _highestLevel = 1;
  int _resumeLevel = 1;
  int _score = 0;
  bool _showingPattern = true;
  bool _gameOver = false;
  bool _showMenu = true;
  String? _userId;
  Timer? _patternTimer;
  Timer? _gameTimer;
  int _secondsElapsed = 0;
  final LocalStorageService _storageService = LocalStorageService();
  DateTime? _gameStartTime;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  @override
  void dispose() {
    _patternTimer?.cancel();
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
      'pattern_match_progress_${_userId ?? "guest"}',
    );
    if (data != null) {
      _resumeLevel = data['currentLevel'] ?? 1;
      _highestLevel = data['highestLevel'] ?? 1;
      _score = data['score'] ?? 0;
    }
  }

  Future<void> _saveProgress() async {
    await _storageService.setJson(
      'pattern_match_progress_${_userId ?? "guest"}',
      {'currentLevel': _level, 'highestLevel': _highestLevel, 'score': _score},
    );
  }

  void _startGame() {
    _gameOver = false;
    _gameStartTime = DateTime.now();
    _secondsElapsed = 0;
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_gameOver) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
    _generatePattern();
  }

  void _generatePattern() {
    _gridSize = 3 + (_level ~/ 2);
    if (_gridSize > 5) _gridSize = 5;

    _pattern = List.generate(_gridSize, (_) => List.filled(_gridSize, false));
    _userPattern = List.generate(
      _gridSize,
      (_) => List.filled(_gridSize, false),
    );
    _showingPattern = true;

    // Generate random pattern
    final patternCells = (_gridSize * _gridSize * 0.4).round();
    final random = Random();
    int cellsPlaced = 0;

    while (cellsPlaced < patternCells) {
      final row = random.nextInt(_gridSize);
      final col = random.nextInt(_gridSize);
      if (!_pattern[row][col]) {
        _pattern[row][col] = true;
        cellsPlaced++;
      }
    }

    // Show pattern for a few seconds
    _patternTimer = Timer(Duration(milliseconds: 2000 + (_level * 300)), () {
      setState(() {
        _showingPattern = false;
      });
    });

    setState(() {});
  }

  void _onCellTap(int row, int col) {
    if (_showingPattern || _gameOver) return;

    setState(() {
      _userPattern[row][col] = !_userPattern[row][col];
    });
  }

  void _checkPattern() {
    bool isCorrect = true;
    for (int i = 0; i < _gridSize; i++) {
      for (int j = 0; j < _gridSize; j++) {
        if (_pattern[i][j] != _userPattern[i][j]) {
          isCorrect = false;
          break;
        }
      }
      if (!isCorrect) break;
    }

    if (isCorrect) {
      // Correct pattern
      final completedLevel = _level;
      final levelBonus = _level * 150;
      final timeBonus = (45 - _secondsElapsed).clamp(0, 45);
      _score += levelBonus + timeBonus;
      _highestLevel = max(_highestLevel, completedLevel);
      final nextLevel = _level + 1;
      setState(() {
        _level = nextLevel;
        _resumeLevel = nextLevel;
      });
      _saveProgress();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Level $_level Complete! +${levelBonus + timeBonus} points',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_gameOver) {
          _generatePattern();
        }
      });
    } else {
      // Wrong pattern
      _gameOver = true;
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    _gameTimer?.cancel();
    _patternTimer?.cancel();

    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!)
        : Duration(seconds: _secondsElapsed);

    final accuracy = _level > 1 ? 1.0 : 0.0;

    // Get previous best score
    final bestScoreKey = 'pattern_match_best_score';
    final previousBest = await _storageService.getInt(bestScoreKey);

    // Save new best if achieved
    if (previousBest == null || _score > previousBest) {
      await _storageService.setInt(bestScoreKey, _score);
    }
    _resumeLevel = _level; // Save current level as resume point
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
          gameId: 'pattern_match',
          gameName: 'Pattern Match',
          gameType: 'pattern',
          score: _score,
          maxScore: 2500,
          playedAt: DateTime.now(),
          duration: duration,
          difficulty: _level <= 3
              ? 'easy'
              : _level <= 6
              ? 'medium'
              : 'hard',
          level: _level,
          accuracy: accuracy,
          attempts: _level,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          gameData: {'levelReached': _level, 'gridSize': _gridSize},
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
                    _level = 1;
                    _resumeLevel = 1;
                    _score = 0;
                    _secondsElapsed = 0;
                    _gameOver = false;
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
          _showMenu ? 'Pattern Match' : 'Pattern Match - Level $_level',
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

  Widget _buildMenu() {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent.withOpacity(0.05), AppColors.background],
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
                      AppColors.accent,
                      AppColors.accent.withOpacity(0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.grid_view,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pattern Match',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remember the highlighted cells and recreate the pattern.\nYour progress is automatically saved.',
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
                      AppColors.accent,
                      AppColors.accent.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
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
                  foregroundColor: AppColors.accent,
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.accent.withOpacity(0.2)),
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
              subtitle: Text('Grid size ${3 + (lvl ~/ 2)}'),
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

  Widget _buildGame() {
    return Column(
      children: [
        // Enhanced Stats Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                Icons.star,
                'Score',
                _score.toString(),
                AppColors.primary,
              ),
              _buildEnhancedStat(
                Icons.flag,
                'Level',
                _level.toString(),
                AppColors.accent,
              ),
              _buildEnhancedStat(
                Icons.timer,
                'Time',
                _formatTime(_secondsElapsed),
                AppColors.warning,
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
                if (_showingPattern) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility, color: AppColors.info, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Watch and Remember',
                          style: TextStyle(
                            color: AppColors.info,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildPatternGrid(_pattern, isInteractive: false),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: AppColors.success,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Tap to recreate the pattern',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildPatternGrid(_userPattern, isInteractive: true),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _checkPattern,
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: const Text(
                        'Check Pattern',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatternGrid(
    List<List<bool>> pattern, {
    required bool isInteractive,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridSize,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: _gridSize * _gridSize,
        itemBuilder: (context, index) {
          final row = index ~/ _gridSize;
          final col = index % _gridSize;
          final isFilled = pattern[row][col];

          return GestureDetector(
            onTap: isInteractive ? () => _onCellTap(row, col) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: isFilled
                    ? LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.white, Colors.grey.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFilled
                      ? AppColors.primary.withOpacity(0.5)
                      : AppColors.border,
                  width: isFilled ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isFilled
                        ? AppColors.primary.withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: isFilled ? 8 : 2,
                    spreadRadius: isFilled ? 1 : 0,
                    offset: Offset(0, isFilled ? 4 : 2),
                  ),
                ],
              ),
              child: isFilled
                  ? Icon(Icons.circle, color: Colors.white, size: 20)
                  : null,
            ),
          );
        },
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
