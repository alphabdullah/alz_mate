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

class MemoryCardGameScreen extends StatefulWidget {
  const MemoryCardGameScreen({super.key});

  @override
  State<MemoryCardGameScreen> createState() => _MemoryCardGameScreenState();
}

class _MemoryCardGameScreenState extends State<MemoryCardGameScreen>
    with SingleTickerProviderStateMixin {
  // Menu state
  bool _showMenu = true;

  late List<CardData> _cards;
  List<int> _flippedCards = [];
  int _moves = 0;
  int _matches = 0;
  int _level = 1;
  bool _isProcessing = false;
  Timer? _gameTimer;
  int _secondsElapsed = 0;
  int _maxSeconds = 0;
  int _maxMoves = 0;
  bool _gameStarted = false;
  bool _gameCompleted = false;
  bool _movesUp = false;

  late AnimationController _flipController;
  final LocalStorageService _storageService = LocalStorageService();
  final Map<String, dynamic> _userProgress = {};
  String? _userId;

  // Beautiful card themes with emojis and colors
  final List<Map<String, dynamic>> _cardThemes = [
    {
      'emoji': '🐶',
      'name': 'Dog',
      'color': const Color(0xFFFFB74D),
      'icon': Icons.pets,
    },
    {
      'emoji': '🐱',
      'name': 'Cat',
      'color': const Color(0xFFFF8A65),
      'icon': Icons.pets,
    },
    {
      'emoji': '🐰',
      'name': 'Rabbit',
      'color': const Color(0xFFFFD54F),
      'icon': Icons.pets,
    },
    {
      'emoji': '🐼',
      'name': 'Panda',
      'color': const Color(0xFF81C784),
      'icon': Icons.pets,
    },
    {
      'emoji': '🦁',
      'name': 'Lion',
      'color': const Color(0xFFFFA726),
      'icon': Icons.pets,
    },
    {
      'emoji': '🐯',
      'name': 'Tiger',
      'color': const Color(0xFFFF9800),
      'icon': Icons.pets,
    },
    {
      'emoji': '🐸',
      'name': 'Frog',
      'color': const Color(0xFF66BB6A),
      'icon': Icons.pets,
    },
    {
      'emoji': '🐨',
      'name': 'Koala',
      'color': const Color(0xFF90A4AE),
      'icon': Icons.pets,
    },
    {
      'emoji': '🐻',
      'name': 'Bear',
      'color': const Color(0xFF8D6E63),
      'icon': Icons.pets,
    },
    {
      'emoji': '🐷',
      'name': 'Pig',
      'color': const Color(0xFFFFB3BA),
      'icon': Icons.pets,
    },
    {
      'emoji': '🍎',
      'name': 'Apple',
      'color': const Color(0xFFFF5252),
      'icon': Icons.apple,
    },
    {
      'emoji': '🍌',
      'name': 'Banana',
      'color': const Color(0xFFFFEB3B),
      'icon': Icons.eco,
    },
    {
      'emoji': '🍇',
      'name': 'Grapes',
      'color': const Color(0xFF9C27B0),
      'icon': Icons.eco,
    },
    {
      'emoji': '🍊',
      'name': 'Orange',
      'color': const Color(0xFFFF9800),
      'icon': Icons.eco,
    },
    {
      'emoji': '🍓',
      'name': 'Strawberry',
      'color': const Color(0xFFE91E63),
      'icon': Icons.eco,
    },
    {
      'emoji': '🚗',
      'name': 'Car',
      'color': const Color(0xFF2196F3),
      'icon': Icons.directions_car,
    },
    {
      'emoji': '🚀',
      'name': 'Rocket',
      'color': const Color(0xFF9C27B0),
      'icon': Icons.rocket_launch,
    },
    {
      'emoji': '✈️',
      'name': 'Plane',
      'color': const Color(0xFF00BCD4),
      'icon': Icons.flight,
    },
    {
      'emoji': '🚢',
      'name': 'Ship',
      'color': const Color(0xFF3F51B5),
      'icon': Icons.directions_boat,
    },
    {
      'emoji': '🏠',
      'name': 'House',
      'color': const Color(0xFFFF5722),
      'icon': Icons.home,
    },
    {
      'emoji': '⭐',
      'name': 'Star',
      'color': const Color(0xFFFFD700),
      'icon': Icons.star,
    },
    {
      'emoji': '❤️',
      'name': 'Heart',
      'color': const Color(0xFFE91E63),
      'icon': Icons.favorite,
    },
    {
      'emoji': '🎈',
      'name': 'Balloon',
      'color': const Color(0xFFFF4081),
      'icon': Icons.celebration,
    },
    {
      'emoji': '🎂',
      'name': 'Cake',
      'color': const Color(0xFFFFB74D),
      'icon': Icons.cake,
    },
  ];

  // Level configurations
  final List<Map<String, int>> _levels = [
    {'rows': 2, 'cols': 2, 'pairs': 2, 'time': 0, 'moves': 0}, // Level 1
    {'rows': 2, 'cols': 3, 'pairs': 3, 'time': 0, 'moves': 0}, // Level 2
    {'rows': 3, 'cols': 4, 'pairs': 6, 'time': 0, 'moves': 0}, // Level 3
    {'rows': 4, 'cols': 4, 'pairs': 8, 'time': 180, 'moves': 40}, // Level 4
    {'rows': 4, 'cols': 5, 'pairs': 10, 'time': 180, 'moves': 45}, // Level 5
    {'rows': 5, 'cols': 5, 'pairs': 12, 'time': 210, 'moves': 50}, // Level 6
    {'rows': 5, 'cols': 6, 'pairs': 15, 'time': 240, 'moves': 55}, // Level 7
  ];

  // Track used themes to avoid repeats across levels
  final Set<int> _usedThemeIndices = {};

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeUserAndProgress();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _initializeUserAndProgress() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    _userId = authService.currentUser?.uid;
    await _loadProgress();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProgress() async {
    if (_userId == null) return;
    final data = await _storageService.getJson(
      'memory_cards_progress_${_userId!}',
    );
    if (data != null) {
      _userProgress
        ..clear()
        ..addAll(data);
    }
  }

  Future<void> _saveProgress({bool clear = false}) async {
    if (_userId == null) return;
    if (clear) {
      await _storageService.remove('memory_cards_progress_${_userId!}');
      return;
    }
    final data = {
      'highestLevel': _userProgress['highestLevel'] ?? _level,
      'currentLevel': _gameCompleted ? null : _level,
    };
    await _storageService.setJson('memory_cards_progress_${_userId!}', data);
  }

  void _initializeGame() {
    final config = _levels[_level - 1];
    final pairs = config['pairs']!;
    _maxSeconds = config['time']!;
    _maxMoves = config['moves']!;

    // Select random themes for this level (ensure we have enough unique themes)
    final random = Random();
    final selectedThemeIndices = <int>{};
    while (selectedThemeIndices.length < pairs &&
        _usedThemeIndices.length < _cardThemes.length) {
      final idx = random.nextInt(_cardThemes.length);
      if (_usedThemeIndices.contains(idx)) continue;
      selectedThemeIndices.add(idx);
    }

    // If pool exhausted, allow reuse
    while (selectedThemeIndices.length < pairs) {
      selectedThemeIndices.add(random.nextInt(_cardThemes.length));
    }
    final themeIndicesList = selectedThemeIndices.toList();
    themeIndicesList.shuffle(random);

    // Generate pairs of cards with themes - each theme appears twice
    final cardThemes = <Map<String, dynamic>>[];
    for (int i = 0; i < pairs; i++) {
      final theme = _cardThemes[themeIndicesList[i]];
      cardThemes.add(theme); // First card
      cardThemes.add(theme); // Matching pair
      _usedThemeIndices.add(themeIndicesList[i]);
    }
    cardThemes.shuffle(random);

    _cards = cardThemes.asMap().entries.map((entry) {
      final theme = entry.value;
      return CardData(
        id: entry.key,
        value: entry.key ~/ 2, // Pair index (each pair has same value)
        emoji: theme['emoji'] as String,
        name: theme['name'] as String,
        color: theme['color'] as Color,
        icon: theme['icon'] as IconData,
        isFlipped: false,
        isMatched: false,
      );
    }).toList();

    _moves = 0;
    _matches = 0;
    _flippedCards = [];
    _isProcessing = false;
    _secondsElapsed = 0;
    _movesUp = false;
    _gameStarted = false;
    _gameCompleted = false;

    _saveProgress(clear: false);
    setState(() {});
  }

  void _startGame() {
    if (!_gameStarted) {
      _gameStarted = true;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_gameCompleted) return;
        setState(() {
          _secondsElapsed++;
          if (_maxSeconds > 0 && _secondsElapsed >= _maxSeconds) {
            _failLevel(message: 'Time is up!');
          }
        });
      });
    }
  }

  void _flipCard(int index) {
    if (_isProcessing || _gameCompleted || _showMenu) return;
    if (_cards[index].isFlipped || _cards[index].isMatched) return;
    if (_flippedCards.length >= 2) return;
    if (_maxMoves > 0 && _moves >= _maxMoves) return;

    _startGame();

    setState(() {
      _cards[index].isFlipped = true;
      _flippedCards.add(index);
    });

    if (_flippedCards.length == 2) {
      _checkMatch();
    }
  }

  void _checkMatch() {
    _isProcessing = true;
    _moves++;
    if (_maxMoves > 0 && _moves > _maxMoves) {
      _movesUp = true;
      _failLevel(message: 'Move limit reached');
      return;
    }

    final firstIndex = _flippedCards[0];
    final secondIndex = _flippedCards[1];
    final firstCard = _cards[firstIndex];
    final secondCard = _cards[secondIndex];

    // Match based on emoji (which represents the same card type)
    if (firstCard.emoji == secondCard.emoji) {
      // Match found
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          _cards[firstIndex].isMatched = true;
          _cards[secondIndex].isMatched = true;
          _matches++;
          _flippedCards.clear();
          _isProcessing = false;

          // Check if level complete
          if (_matches == _levels[_level - 1]['pairs']) {
            _completeLevel();
          }
        });
      });
    } else {
      // No match
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _cards[firstIndex].isFlipped = false;
            _cards[secondIndex].isFlipped = false;
            _flippedCards.clear();
            _isProcessing = false;
          });
        }
      });
    }
  }

  void _failLevel({String? message}) {
    _isProcessing = false;
    _gameCompleted = true;
    _gameTimer?.cancel();
    _saveProgress(clear: false);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Level Failed'),
        content: Text(message ?? 'Try again!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetLevel();
            },
            child: const Text('Restart Level'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _backToMenu();
            },
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }

  void _completeLevel() {
    if (_level < _levels.length) {
      _gameCompleted = true;
      _gameTimer?.cancel();
      _userProgress['highestLevel'] = (_userProgress['highestLevel'] ?? _level)
          .clamp(1, _levels.length);
      _saveProgress(clear: false);
      _showCelebration();
    } else {
      // Game completed
      _gameCompleted = true;
      _gameTimer?.cancel();
      _finishGame();
    }
  }

  void _showCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('🎉 Congratulations! Level $_level complete'),
        content: const Text('Great job! Ready for the next challenge?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetLevel();
            },
            child: const Text('Replay Level'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToNextLevel();
            },
            child: const Text('Next Level'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _backToMenu();
            },
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }

  void _goToNextLevel() {
    if (_level >= _levels.length) {
      _backToMenu();
      return;
    }
    setState(() {
      _level++;
      _gameCompleted = false;
      _initializeGame();
    });
  }

  void _resetLevel() {
    setState(() {
      _gameCompleted = false;
      _initializeGame();
    });
  }

  void _backToMenu() {
    setState(() {
      _showMenu = true;
      _gameCompleted = false;
      _gameTimer?.cancel();
    });
  }

  Future<void> _finishGame() async {
    final config = _levels[_level - 1];
    final totalPairs = config['pairs']!;

    // Calculate score: base score + level bonus - time penalty + move efficiency
    final baseScore = 1000;
    final levelBonus = (_level - 1) * 500;
    final timeBonus = (300 - _secondsElapsed).clamp(0, 300);
    final moveEfficiency = ((totalPairs * 2 - _moves) * 10).clamp(0, 200);
    final score = baseScore + levelBonus + timeBonus + moveEfficiency;

    final accuracy = _matches / (_moves > 0 ? _moves : 1);
    final duration = Duration(seconds: _secondsElapsed);

    // Get previous best score
    final bestScoreKey = 'memory_cards_best_score';
    final previousBest = await _storageService.getInt(bestScoreKey);

    // Save new best if achieved
    if (previousBest == null || score > previousBest) {
      await _storageService.setInt(bestScoreKey, score);
    }

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
          gameId: 'memory_cards',
          gameName: 'Memory Cards',
          gameType: 'memory',
          score: score,
          maxScore: 2000,
          playedAt: DateTime.now(),
          duration: duration,
          difficulty: _level == 1
              ? 'easy'
              : _level == 2
              ? 'medium'
              : 'hard',
          level: _level,
          accuracy: accuracy,
          attempts: _moves,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          gameData: {'moves': _moves, 'matches': _matches, 'level': _level},
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
                  _resetLevel();
                },
                onFinish: () {
                  Navigator.pop(context);
                  _backToMenu();
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
          _showMenu ? 'Memory Cards' : 'Memory Cards - Level $_level',
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
    final currentLevel = _userProgress['currentLevel'] ?? 1;
    final highestLevel = _userProgress['highestLevel'] ?? 1;

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.success.withOpacity(0.05), AppColors.background],
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
                      AppColors.success,
                      AppColors.success.withOpacity(0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.style, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Memory Cards',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Flip cards to find matching pairs.\nYour progress is automatically saved.',
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
                      '$currentLevel',
                      AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      Icons.trending_up,
                      'Highest',
                      '$highestLevel',
                      AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      Icons.grid_view,
                      'Total',
                      '${_levels.length}',
                      AppColors.primary,
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
                      AppColors.success,
                      AppColors.success.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showMenu = false;
                      _level = 1;
                      _usedThemeIndices.clear();
                      _initializeGame();
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
              if (currentLevel > 1)
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
                        _showMenu = false;
                        _level = currentLevel;
                        _initializeGame();
                      });
                    },
                    icon: Icon(
                      Icons.refresh,
                      color: AppColors.success,
                      size: 24,
                    ),
                    label: Text(
                      'Resume Level $currentLevel',
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
              if (currentLevel > 1) const SizedBox(height: 16),
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
                  foregroundColor: AppColors.success,
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.success.withOpacity(0.2)),
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
      builder: (_) {
        return SafeArea(
          child: ListView.builder(
            itemCount: _levels.length,
            itemBuilder: (context, index) {
              final lvl = index + 1;
              final unlocked =
                  (_userProgress['highestLevel'] ?? 1) >= lvl || lvl == 1;
              return ListTile(
                leading: Icon(
                  unlocked ? Icons.lock_open : Icons.lock,
                  color: unlocked ? AppColors.success : AppColors.textSecondary,
                ),
                title: Text('Level $lvl'),
                subtitle: Text(
                  '${_levels[index]['rows']}x${_levels[index]['cols']} grid',
                ),
                onTap: unlocked
                    ? () {
                        Navigator.pop(context);
                        setState(() {
                          _showMenu = false;
                          _level = lvl;
                          _initializeGame();
                        });
                      }
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGame() {
    final config = _levels[_level - 1];
    final cols = config['cols']!;
    final pairs = config['pairs']!;

    return Column(
      children: [
        // Enhanced Stats Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                Icons.touch_app,
                'Moves',
                _moves.toString(),
                AppColors.primary,
              ),
              _buildEnhancedStat(
                Icons.check_circle,
                'Matches',
                '$_matches/$pairs',
                AppColors.success,
              ),
              _buildEnhancedStat(
                Icons.timer,
                'Time',
                _maxSeconds > 0
                    ? '${_formatTime(_secondsElapsed)}/${_formatTime(_maxSeconds)}'
                    : _formatTime(_secondsElapsed),
                _maxSeconds > 0 && _secondsElapsed > _maxSeconds
                    ? AppColors.danger
                    : AppColors.accent,
              ),
              if (_maxMoves > 0)
                _buildEnhancedStat(
                  Icons.flag,
                  'Moves',
                  '$_moves/$_maxMoves',
                  _movesUp ? AppColors.danger : AppColors.warning,
                ),
            ],
          ),
        ),

        // Progress Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.primary.withOpacity(0.05),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: pairs > 0 ? _matches / pairs : 0,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${((_matches / pairs) * 100).round()}%',
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

        // Game Grid
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.background,
                  AppColors.background.withOpacity(0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  return _buildCard(index);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPauseMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Paused',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Restart Level'),
                onTap: () {
                  Navigator.pop(context);
                  _resetLevel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Quit to Menu'),
                onTap: () {
                  Navigator.pop(context);
                  _backToMenu();
                },
              ),
            ],
          ),
        );
      },
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

  Widget _buildCard(int index) {
    final card = _cards[index];
    final isFlipped = card.isFlipped || card.isMatched;
    final isMatched = card.isMatched;

    return GestureDetector(
      onTap: () => _flipCard(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: isMatched
              ? LinearGradient(
                  colors: [
                    AppColors.success,
                    AppColors.success.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : isFlipped
              ? LinearGradient(
                  colors: [
                    card.color.withOpacity(0.95),
                    card.color.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isMatched
                ? AppColors.success
                : isFlipped
                ? card.color.withOpacity(0.5)
                : Colors.white.withOpacity(0.3),
            width: isMatched
                ? 4
                : isFlipped
                ? 3
                : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isMatched
                  ? AppColors.success.withOpacity(0.5)
                  : isFlipped
                  ? card.color.withOpacity(0.4)
                  : AppColors.primary.withOpacity(0.3),
              blurRadius: isMatched
                  ? 15
                  : isFlipped
                  ? 12
                  : 8,
              spreadRadius: isMatched
                  ? 3
                  : isFlipped
                  ? 2
                  : 0,
              offset: Offset(
                0,
                isMatched
                    ? 6
                    : isFlipped
                    ? 5
                    : 4,
              ),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background pattern for hidden cards
              if (!isFlipped)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CustomPaint(painter: _CardPatternPainter()),
                ),

              // Card content
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: isFlipped
                      ? Container(
                          key: ValueKey('flipped_$index'),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isMatched)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              // Emoji display
                              Text(
                                card.emoji,
                                style: TextStyle(
                                  fontSize: isMatched ? 48 : 42,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Name display
                              Text(
                                card.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isMatched ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: ValueKey('hidden_$index'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.help_outline,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '?',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class CardData {
  final int id;
  final int value;
  final String emoji;
  final String name;
  final Color color;
  final IconData icon;
  bool isFlipped;
  bool isMatched;

  CardData({
    required this.id,
    required this.value,
    required this.emoji,
    required this.name,
    required this.color,
    required this.icon,
    required this.isFlipped,
    required this.isMatched,
  });
}

// Custom painter for card pattern background
class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw diagonal lines
    final spacing = 15.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
