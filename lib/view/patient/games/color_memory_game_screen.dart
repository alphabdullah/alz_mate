import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_storage_service.dart';

class ColorMemoryGameScreen extends StatefulWidget {
  const ColorMemoryGameScreen({super.key});

  @override
  State<ColorMemoryGameScreen> createState() => _ColorMemoryGameScreenState();
}

class _ColorMemoryGameScreenState extends State<ColorMemoryGameScreen> {
  final List<Map<String, dynamic>> _availableColors = [
    {'name': 'Red', 'color': Colors.red},
    {'name': 'Blue', 'color': Colors.blue},
    {'name': 'Green', 'color': Colors.green},
    {'name': 'Yellow', 'color': Colors.yellow},
    {'name': 'Purple', 'color': Colors.purple},
    {'name': 'Orange', 'color': Colors.orange},
    {'name': 'Pink', 'color': Colors.pink},
    {'name': 'Teal', 'color': Colors.teal},
    {'name': 'Brown', 'color': Colors.brown},
    {'name': 'Cyan', 'color': Colors.cyan},
  ];

  final List<Map<String, dynamic>> _levels = [
    {'colors': 2, 'sequence': 1},
    {'colors': 3, 'sequence': 1},
    {'colors': 4, 'sequence': 2},
    {'colors': 5, 'sequence': 3},
    {'colors': 6, 'sequence': 4},
    {'colors': 7, 'sequence': 5},
    {'colors': 8, 'sequence': 6},
  ];

  bool _showMenu = true;
  String? _userId;
  int _resumeLevel = 1;
  int _highestLevel = 1;
  final FlutterTts _tts = FlutterTts();
  List<int> _sequence = [];
  List<int> _userSequence = [];
  int _currentIndex = 0;
  int _level = 1;
  int _score = 0;
  bool _showingSequence = true;
  bool _userTurn = false;
  bool _gameOver = false;
  Timer? _sequenceTimer;
  Timer? _gameTimer;
  int _secondsElapsed = 0;
  final LocalStorageService _storageService = LocalStorageService();
  DateTime? _gameStartTime;
  int _maxSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initUser();
    _initTts();
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
  }

  Future<void> _initUser() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    _userId = auth.currentUser?.uid ?? 'guest';
    await _loadProgress();
  }

  Future<void> _loadProgress() async {
    final data = await _storageService.getJson(
      'color_memory_progress_$_userId',
    );
    if (data != null) {
      _resumeLevel = data['currentLevel'] ?? 1;
      _highestLevel = data['highestLevel'] ?? 1;
      _score = data['score'] ?? 0;
    }
  }

  Future<void> _saveProgress() async {
    _highestLevel = max(_highestLevel, _level);
    await _storageService.setJson('color_memory_progress_$_userId', {
      'currentLevel': _level,
      'highestLevel': _highestLevel,
      'score': _score,
    });
  }

  void _startGame() {
    _gameStartTime = DateTime.now();
    _secondsElapsed = 0;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_gameOver) {
        setState(() {
          _secondsElapsed++;
          if (_maxSeconds > 0 && _secondsElapsed >= _maxSeconds) {
            _gameOver = true;
            _failLevel('Time is up!');
          }
        });
      }
    });
    _generateSequence();
  }

  void _generateSequence() {
    final levelConfig = _levels[(_level - 1).clamp(0, _levels.length - 1)];
    final colorCount =
        levelConfig['colors'].clamp(2, _availableColors.length) as int;
    _maxSeconds = max(0, 20 + (_level * 5));

    _sequence = [];
    final rand = Random();
    final pool = List.generate(colorCount, (i) => i);
    for (int i = 0; i < levelConfig['sequence']; i++) {
      _sequence.add(pool[rand.nextInt(pool.length)]);
    }
    _userSequence = [];
    _currentIndex = 0;
    _showingSequence = true;
    _userTurn = false;

    // Show sequence
    _showSequence();
  }

  Future<void> _showSequence() async {
    for (int i = 0; i < _sequence.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _currentIndex = i;
        });
      }
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _currentIndex = -1;
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _showingSequence = false;
        _userTurn = true;
      });
    }
  }

  void _onColorTap(int colorIndex) {
    if (!_userTurn || _gameOver) return;

    setState(() {
      _userSequence.add(colorIndex);
    });

    _speakColor(_availableColors[colorIndex]['name'] as String);

    // Check if correct
    if (_userSequence[_userSequence.length - 1] !=
        _sequence[_userSequence.length - 1]) {
      // Wrong color
      _failLevel('Wrong color, try again!');
    } else if (_userSequence.length == _sequence.length) {
      // Level complete
      _score += _level * 100;
      _highestLevel = max(_highestLevel, _level);
      final nextLevel = _level + 1;
      _level = nextLevel;
      _resumeLevel = nextLevel;
      _saveProgress();

      if (_level >= _levels.length) {
        _gameOver = true;
        _showCelebration(
          '🎉 Great job! You completed Level $_level in Color Memory.',
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Level $_level! +${_level * 100} points'),
          backgroundColor: AppColors.success,
        ),
      );

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_gameOver) {
          _generateSequence();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _showMenu ? 'Color Memory' : 'Color Memory - Level $_level',
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
                child: const Icon(Icons.palette, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Color Memory',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Listen and tap the correct colors in sequence.\nYour progress is automatically saved.',
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
                      _level = 1;
                      _score = 0;
                      _showMenu = false;
                      _gameOver = false;
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
                      _gameOver = false;
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
          itemCount: _levels.length,
          itemBuilder: (context, index) {
            final lvl = index + 1;
            return ListTile(
              leading: Icon(Icons.palette, color: AppColors.primary),
              title: Text('Level $lvl'),
              subtitle: Text(
                '${_levels[index]['colors']} colors • ${_levels[index]['sequence']} taps',
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _level = lvl;
                  _showMenu = false;
                  _gameOver = false;
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
    final levelConfig = _levels[(_level - 1).clamp(0, _levels.length - 1)];
    final colorsToUse = levelConfig['colors'] as int;
    final activeColors = _availableColors.take(colorsToUse).toList();

    return Column(
      children: [
        // Stats Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
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
                '$_score',
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
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_showingSequence)
                  _buildBanner(AppColors.info, 'Watch the sequence')
                else
                  _buildBanner(AppColors.success, 'Repeat the sequence'),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: activeColors.length,
                  itemBuilder: (context, index) {
                    final colorData = activeColors[index];
                    final isHighlighted =
                        _showingSequence &&
                        _currentIndex >= 0 &&
                        _sequence[_currentIndex] == index;
                    final isUserSelected =
                        _userTurn &&
                        _userSequence.isNotEmpty &&
                        _userSequence.last == index;
                    final color = colorData['color'] as Color;
                    final name = colorData['name'] as String;
                    return GestureDetector(
                      onTap: _userTurn ? () => _onColorTap(index) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isHighlighted || isUserSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: isHighlighted || isUserSelected ? 4 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(
                                isHighlighted || isUserSelected ? 0.7 : 0.3,
                              ),
                              blurRadius: isHighlighted || isUserSelected
                                  ? 16
                                  : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (_userTurn && _userSequence.isNotEmpty)
                  Text(
                    'Progress: ${_userSequence.length}/${_sequence.length}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showPauseMenu,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause / Quit'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            color == AppColors.info ? Icons.visibility : Icons.touch_app,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _speakColor(String name) {
    _tts.stop();
    _tts.speak(name);
  }

  void _failLevel(String message) {
    _gameOver = true;
    _gameTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Level Failed'),
        content: Text(message),
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
            onPressed: () {
              Navigator.pop(context);
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
                  _gameOver = false;
                });
                _startGame();
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Back to Menu'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _showMenu = true;
                  _gameOver = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCelebration(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Level Complete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _gameOver = false;
                _showMenu = true;
              });
            },
            child: const Text('Back to Menu'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _gameOver = false;
              });
              _startGame();
            },
            child: const Text('Replay Level'),
          ),
        ],
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
