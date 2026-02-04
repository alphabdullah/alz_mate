import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/game_score_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_storage_service.dart';

class NumberSequenceGameScreen extends StatefulWidget {
  const NumberSequenceGameScreen({super.key});

  @override
  State<NumberSequenceGameScreen> createState() =>
      _NumberSequenceGameScreenState();
}

class _NumberSequenceGameScreenState extends State<NumberSequenceGameScreen> {
  List<int> _sequence = [];
  List<int> _userSequence = [];
  int _currentLevel = 1;
  int _score = 0;
  int _highestLevel = 1;
  int _resumeLevel = 1;
  bool _showMenu = true;
  String? _userId;
  bool _showingSequence = true;
  bool _gameOver = false;
  Timer? _sequenceTimer;
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
    _sequenceTimer?.cancel();
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
      'number_sequence_progress_${_userId ?? "guest"}',
    );
    if (data != null) {
      _resumeLevel = data['currentLevel'] ?? 1;
      _highestLevel = data['highestLevel'] ?? 1;
      _score = data['score'] ?? 0;
    }
  }

  Future<void> _saveProgress() async {
    await _storageService.setJson(
      'number_sequence_progress_${_userId ?? "guest"}',
      {
        'currentLevel': _currentLevel,
        'highestLevel': _highestLevel,
        'score': _score,
      },
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
    _generateSequence();
  }

  void _generateSequence() {
    _sequence = [];
    _userSequence = [];
    _showingSequence = true;

    // Generate sequence based on level
    final sequenceLength = 3 + _currentLevel;
    int startValue = Random().nextInt(10) + 1;
    final pattern = Random().nextInt(
      3,
    ); // 0: addition, 1: multiplication, 2: fibonacci-like

    for (int i = 0; i < sequenceLength; i++) {
      if (pattern == 0) {
        // Addition pattern: +2, +3, +4, etc.
        _sequence.add(startValue);
        startValue += (i + 2);
      } else if (pattern == 1) {
        // Multiplication pattern: *2, *3, etc.
        _sequence.add(startValue);
        startValue *= (i + 2);
      } else {
        // Fibonacci-like pattern
        if (i == 0) {
          _sequence.add(startValue);
        } else if (i == 1) {
          _sequence.add(startValue + 1);
        } else {
          _sequence.add(_sequence[i - 1] + _sequence[i - 2]);
        }
      }
    }

    // Show sequence for a few seconds
    _sequenceTimer = Timer(
      Duration(milliseconds: 2000 + (_currentLevel * 500)),
      () {
        setState(() {
          _showingSequence = false;
        });
      },
    );

    setState(() {});
  }

  void _onNumberTap(int number) {
    if (_showingSequence || _gameOver) return;

    setState(() {
      _userSequence.add(number);
    });

    // Check if sequence matches
    if (_userSequence.length == _sequence.length) {
      _checkSequence();
    } else {
      // Check if current input is wrong
      if (_userSequence[_userSequence.length - 1] !=
          _sequence[_userSequence.length - 1]) {
        _gameOver = true;
        _finishGame();
      }
    }
  }

  void _checkSequence() {
    bool isCorrect = true;
    for (int i = 0; i < _sequence.length; i++) {
      if (_userSequence[i] != _sequence[i]) {
        isCorrect = false;
        break;
      }
    }

    if (isCorrect) {
      // Correct sequence
      final levelBonus = _currentLevel * 100;
      final timeBonus = (60 - _secondsElapsed).clamp(0, 60);
      _score += levelBonus + timeBonus;
      _highestLevel = max(_highestLevel, _currentLevel);
      _resumeLevel = _currentLevel; // Save current level as resume point
      _saveProgress();

      _showLevelComplete(levelBonus + timeBonus);
    } else {
      // Wrong sequence
      _gameOver = true;
      _finishGame();
    }
  }

  void _showLevelComplete(int points) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🎉 Level Complete'),
        content: Text(
          'Great job! You completed Level $_currentLevel. +$points points.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _startGame(); // replay current level
              });
            },
            child: const Text('Replay Level'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _currentLevel++;
                _resumeLevel = _currentLevel;
                _highestLevel = max(_highestLevel, _currentLevel);
              });
              await _saveProgress();
              _startGame();
            },
            child: const Text('Next Level'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveProgress();
              setState(() {
                _showMenu = true;
              });
            },
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishGame() async {
    _gameTimer?.cancel();
    _sequenceTimer?.cancel();

    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!)
        : Duration(seconds: _secondsElapsed);

    final accuracy = _currentLevel > 1 ? 1.0 : 0.0;

    // Get previous best score
    final bestScoreKey = 'number_sequence_best_score';
    final previousBest = await _storageService.getInt(bestScoreKey);

    // Save new best if achieved
    if (previousBest == null || _score > previousBest) {
      await _storageService.setInt(bestScoreKey, _score);
    }

    // Save to Firestore (best effort)
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
          gameId: 'number_sequence',
          gameName: 'Number Sequence',
          gameType: 'logic',
          score: _score,
          maxScore: 2000,
          playedAt: DateTime.now(),
          duration: duration,
          difficulty: _currentLevel <= 3
              ? 'easy'
              : _currentLevel <= 6
              ? 'medium'
              : 'hard',
          level: _currentLevel,
          accuracy: accuracy,
          attempts: _currentLevel,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          gameData: {
            'levelReached': _currentLevel,
            'sequenceLength': _sequence.length,
          },
        );

        await firestoreService.createGameScore(gameScore);
      }
    } catch (_) {
      // ignore errors
    }

    _resumeLevel = _currentLevel; // Save current level as resume point
    _saveProgress();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Level Failed'),
        content: const Text('Try again or go back to menu.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _gameOver = false;
                _startGame();
              });
            },
            child: const Text('Replay Level'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveProgress();
              setState(() {
                _gameOver = false;
                _showMenu = true;
              });
            },
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Number Sequence'),
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
            colors: [AppColors.primary.withOpacity(0.05), AppColors.background],
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
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.numbers, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Number Sequence',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remember the sequence and tap in order.\nYour progress is automatically saved.',
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
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentLevel = 1;
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
                      _currentLevel = _resumeLevel;
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
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
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
              subtitle: Text('Sequence length ${3 + lvl}'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentLevel = lvl;
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
                Icons.flag,
                'Level',
                _currentLevel.toString(),
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
                AppColors.warning,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_showingSequence) ...[
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
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          AppColors.primary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: _sequence.asMap().entries.map((entry) {
                        return Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              entry.value.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
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
                          'Tap numbers in order',
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
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.0,
                        ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final number = index + 1;
                      final isSelected = _userSequence.contains(number);
                      final selectionIndex = _userSequence.indexOf(number);
                      return GestureDetector(
                        onTap: () => _onNumberTap(number),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      AppColors.success,
                                      AppColors.success.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [Colors.white, Colors.grey.shade50],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.success
                                  : AppColors.primary.withOpacity(0.3),
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? AppColors.success.withOpacity(0.4)
                                    : AppColors.primary.withOpacity(0.2),
                                blurRadius: isSelected ? 12 : 8,
                                spreadRadius: isSelected ? 2 : 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  number.toString(),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                              if (isSelected && selectionIndex >= 0)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${selectionIndex + 1}',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_userSequence.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.list,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Your Sequence:',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: _userSequence.asMap().entries.map((
                              entry,
                            ) {
                              return Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        entry.value.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${entry.key + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
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
