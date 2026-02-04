import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/game_score_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/custom_button.dart';
import 'games/memory_card_game_screen.dart';
import 'games/word_puzzle_game_screen.dart';
import 'games/number_sequence_game_screen.dart';
import 'games/pattern_match_game_screen.dart';
import 'games/color_memory_game_screen.dart';
import 'games/speed_reading_game_screen.dart';

class BrainGamesScreen extends StatefulWidget {
  const BrainGamesScreen({super.key});

  @override
  State<BrainGamesScreen> createState() => _BrainGamesScreenState();
}

class _BrainGamesScreenState extends State<BrainGamesScreen>
    with SingleTickerProviderStateMixin {
  List<GameScoreModel> _gameScores = [];
  bool _isLoading = false;
  String _selectedCategory = 'all';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _categories = [
    'all',
    'memory',
    'logic',
    'speed',
    'language',
    'pattern',
  ];

  final List<Map<String, dynamic>> _availableGames = [
    {
      'id': 'memory_cards',
      'name': 'Memory Cards',
      'description': 'Match pairs of cards',
      'type': 'memory',
      'icon': 'psychology',
      'color': 0xFF6366F1,
      'duration': '5-10 min',
      'difficulty': 'Easy',
      'instructions':
          'Flip cards to find matching pairs. Remember their positions!',
      'benefits': [
        'Improves short-term memory',
        'Enhances concentration',
        'Boosts pattern recognition',
      ],
    },
    {
      'id': 'word_puzzle',
      'name': 'Word Puzzle',
      'description': 'Find words in letter grids',
      'type': 'language',
      'icon': 'text_fields',
      'color': 0xFF10B981,
      'duration': '10-15 min',
      'difficulty': 'Medium',
      'instructions':
          'Find hidden words in the letter grid by connecting adjacent letters.',
      'benefits': [
        'Improves vocabulary',
        'Enhances language skills',
        'Boosts cognitive flexibility',
      ],
    },
    {
      'id': 'number_sequence',
      'name': 'Number Sequence',
      'description': 'Complete number patterns',
      'type': 'logic',
      'icon': 'calculate',
      'color': 0xFFF59E0B,
      'duration': '5-8 min',
      'difficulty': 'Medium',
      'instructions': 'Identify the pattern and complete the number sequence.',
      'benefits': [
        'Improves logical thinking',
        'Enhances problem-solving',
        'Boosts mathematical skills',
      ],
    },
    {
      'id': 'pattern_match',
      'name': 'Pattern Match',
      'description': 'Match visual patterns',
      'type': 'pattern',
      'icon': 'grid_view',
      'color': 0xFFEF4444,
      'duration': '3-5 min',
      'difficulty': 'Easy',
      'instructions':
          'Match the patterns as quickly and accurately as possible.',
      'benefits': [
        'Improves visual processing',
        'Enhances attention to detail',
        'Boosts reaction time',
      ],
    },
    {
      'id': 'color_memory',
      'name': 'Color Memory',
      'description': 'Remember color sequences',
      'type': 'memory',
      'icon': 'palette',
      'color': 0xFF8B5CF6,
      'duration': '5-7 min',
      'difficulty': 'Hard',
      'instructions':
          'Watch the color sequence and repeat it back in the correct order.',
      'benefits': [
        'Improves working memory',
        'Enhances visual memory',
        'Boosts sequential processing',
      ],
    },
    {
      'id': 'speed_reading',
      'name': 'Speed Reading',
      'description': 'Read and comprehend quickly',
      'type': 'language',
      'icon': 'book',
      'color': 0xFF06B6D4,
      'duration': '10-12 min',
      'difficulty': 'Medium',
      'instructions':
          'Read passages quickly and answer comprehension questions.',
      'benefits': [
        'Improves reading speed',
        'Enhances comprehension',
        'Boosts information processing',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _loadGameScores();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGameScores() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      if (authService.currentUser != null) {
        final scores = await firestoreService.getGameScoresByUserId(
          authService.currentUser!.uid,
        );
        setState(() {
          _gameScores = scores;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading game scores: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredGames {
    if (_selectedCategory == 'all') {
      return _availableGames;
    }
    return _availableGames
        .where((game) => game['type'] == _selectedCategory)
        .toList();
  }

  void _playGame(Map<String, dynamic> game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(game['color']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getGameIcon(game['icon']),
                color: Color(game['color']),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(game['name'], style: AppStyles.titleMedium)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(game['description'], style: AppStyles.bodyMedium),
            const SizedBox(height: 16),
            Text('Instructions:', style: AppStyles.labelLarge),
            const SizedBox(height: 4),
            Text(
              game['instructions'],
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text('Benefits:', style: AppStyles.labelLarge),
            const SizedBox(height: 4),
            ...game['benefits']
                .map<Widget>(
                  (benefit) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            benefit,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CustomButton(
            text: 'Start Game',
            onPressed: () {
              Navigator.pop(context);
              _startGame(game);
            },
            width: 120,
          ),
        ],
      ),
    );
  }

  Future<void> _startGame(Map<String, dynamic> game) async {
    // Navigate to the appropriate game screen based on game ID
    Widget? gameScreen;

    switch (game['id']) {
      case 'memory_cards':
        gameScreen = const MemoryCardGameScreen();
        break;
      case 'word_puzzle':
        gameScreen = const WordPuzzleGameScreen();
        break;
      case 'number_sequence':
        gameScreen = const NumberSequenceGameScreen();
        break;
      case 'pattern_match':
        gameScreen = const PatternMatchGameScreen();
        break;
      case 'color_memory':
        gameScreen = const ColorMemoryGameScreen();
        break;
      case 'speed_reading':
        gameScreen = const SpeedReadingGameScreen();
        break;
      default:
        // Fallback to old behavior if game not found
        return;
    }

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => gameScreen!),
      );
      // Reload scores when returning from game
      _loadGameScores();
    }
  }

  IconData _getGameIcon(String iconName) {
    switch (iconName) {
      case 'psychology':
        return Icons.psychology;
      case 'text_fields':
        return Icons.text_fields;
      case 'calculate':
        return Icons.calculate;
      case 'grid_view':
        return Icons.grid_view;
      case 'palette':
        return Icons.palette;
      case 'book':
        return Icons.book;
      default:
        return Icons.games;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Brain Games'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Category Filter
            Container(
              height: 50,
              margin: const EdgeInsets.all(16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppStyles.softShadow,
                      ),
                      child: Text(
                        category.substring(0, 1).toUpperCase() +
                            category.substring(1),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Games Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildGamesGrid(),
            ),

            // Recent Scores Section
            if (_gameScores.isNotEmpty) _buildRecentScores(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: _filteredGames.length,
      itemBuilder: (context, index) {
        final game = _filteredGames[index];
        return _buildGameCard(game);
      },
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    return GestureDetector(
      onTap: () => _playGame(game),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppStyles.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Game Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(game['color']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getGameIcon(game['icon']),
                  color: Color(game['color']),
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),

              // Game Name
              Flexible(
                child: Text(
                  game['name'],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),

              // Description
              Flexible(
                child: Text(
                  game['description'],
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),

              // Duration & Play Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Color(game['color']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        game['duration'],
                        style: TextStyle(
                          color: Color(game['color']),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.play_arrow, color: Color(game['color']), size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentScores() {
    final recentScores = _gameScores.take(3).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Scores', style: AppStyles.titleMedium),
          const SizedBox(height: 12),
          ...recentScores.map((score) => _buildScoreItem(score)),
        ],
      ),
    );
  }

  Widget _buildScoreItem(GameScoreModel score) {
    final game = _availableGames.firstWhere(
      (g) => g['id'] == score.gameId,
      orElse: () => {
        'name': score.gameName,
        'color': 0xFF6366F1,
        'icon': 'games',
      },
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(game['color']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getGameIcon(game['icon']),
              color: Color(game['color']),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.gameName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${score.playedAt.day}/${score.playedAt.month} • ${score.durationText}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.score.toString(),
                style: TextStyle(
                  color: Color(game['color']),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                score.performanceGrade,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
