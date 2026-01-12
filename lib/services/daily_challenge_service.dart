import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

enum ChallengeType {
  reachScore,
  createLevel,
  mergeCount,
  timeLimit,
  noDeathLine,
}

class DailyChallenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int target;
  final int rewardCoins;
  final DateTime date;

  DailyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.rewardCoins,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'target': target,
        'rewardCoins': rewardCoins,
        'date': date.toIso8601String(),
      };

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    return DailyChallenge(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: ChallengeType.values.firstWhere((e) => e.name == json['type']),
      target: json['target'],
      rewardCoins: json['rewardCoins'],
      date: DateTime.parse(json['date']),
    );
  }
}

class DailyChallengeService {
  static final DailyChallengeService _instance = DailyChallengeService._internal();
  factory DailyChallengeService() => _instance;
  DailyChallengeService._internal();

  DailyChallenge? _currentChallenge;
  bool _isCompleted = false;
  int _progress = 0;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('last_challenge_date');
    final today = _getTodayString();

    if (lastDate != today) {
      // New day, generate new challenge
      _currentChallenge = _generateChallenge(today);
      _isCompleted = false;
      _progress = 0;
      await _saveChallenge();
    } else {
      // Load existing challenge
      await _loadChallenge();
    }
  }

  DailyChallenge _generateChallenge(String dateString) {
    final date = DateTime.parse(dateString);
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final random = Random(seed);

    final challenges = [
      DailyChallenge(
        id: 'score_1000',
        title: 'Beginner',
        description: 'Reach 1,000 points',
        type: ChallengeType.reachScore,
        target: 1000,
        rewardCoins: 5,  // Reduced from 50
        date: date,
      ),
      DailyChallenge(
        id: 'score_5000',
        title: 'Intermediate',
        description: 'Reach 5,000 points',
        type: ChallengeType.reachScore,
        target: 5000,
        rewardCoins: 15,  // Reduced from 150
        date: date,
      ),
      DailyChallenge(
        id: 'score_10000',
        title: 'Expert',
        description: 'Reach 10,000 points',
        type: ChallengeType.reachScore,
        target: 10000,
        rewardCoins: 30,  // Reduced from 300
        date: date,
      ),
      DailyChallenge(
        id: 'level_5',
        title: 'Merge Master',
        description: 'Create a Level 5 orb',
        type: ChallengeType.createLevel,
        target: 5,
        rewardCoins: 10,  // Reduced from 100
        date: date,
      ),
      DailyChallenge(
        id: 'level_7',
        title: 'Advanced Merger',
        description: 'Create a Level 7 orb',
        type: ChallengeType.createLevel,
        target: 7,
        rewardCoins: 20,  // Reduced from 200
        date: date,
      ),
      DailyChallenge(
        id: 'level_10',
        title: 'Supernova',
        description: 'Create the final Supernova orb',
        type: ChallengeType.createLevel,
        target: 10,
        rewardCoins: 50,  // Reduced from 500
        date: date,
      ),
      DailyChallenge(
        id: 'merge_50',
        title: 'Merger Maniac',
        description: 'Complete 50 merges in one game',
        type: ChallengeType.mergeCount,
        target: 50,
        rewardCoins: 15,  // Reduced from 150
        date: date,
      ),
    ];

    return challenges[random.nextInt(challenges.length)];
  }

  Future<void> _saveChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentChallenge != null) {
      await prefs.setString('current_challenge', _currentChallenge!.id);
      await prefs.setString('last_challenge_date', _getTodayString());
      await prefs.setBool('challenge_completed', _isCompleted);
      await prefs.setInt('challenge_progress', _progress);
    }
  }

  Future<void> _loadChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    final challengeId = prefs.getString('current_challenge');
    _isCompleted = prefs.getBool('challenge_completed') ?? false;
    _progress = prefs.getInt('challenge_progress') ?? 0;

    if (challengeId != null) {
      _currentChallenge = _generateChallenge(_getTodayString());
    }
  }

  void updateProgress(ChallengeType type, int value) {
    if (_currentChallenge == null || _isCompleted) return;
    if (_currentChallenge!.type != type) return;

    _progress = value;
    
    if (_progress >= _currentChallenge!.target) {
      _completeChallenge();
    }
    
    _saveChallenge();
  }

  Future<void> _completeChallenge() async {
    if (_isCompleted) return;
    
    _isCompleted = true;
    
    // Award coins
    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt('coins') ?? 0;
    await prefs.setInt('coins', currentCoins + _currentChallenge!.rewardCoins);
    
    await _saveChallenge();
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  DailyChallenge? get currentChallenge => _currentChallenge;
  bool get isCompleted => _isCompleted;
  int get progress => _progress;
  
  double get progressPercentage {
    if (_currentChallenge == null) return 0;
    return (_progress / _currentChallenge!.target).clamp(0.0, 1.0);
  }
}