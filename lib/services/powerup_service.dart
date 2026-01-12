import 'package:shared_preferences/shared_preferences.dart';

enum PowerUpType {
  bomb,      // Destroy bottom row of orbs
  wild,      // Next orb merges with anything
  magnet,    // Pull orbs of same color together
  shield,    // Protect from game over once
}

class PowerUpInventory {
  final Map<PowerUpType, int> _inventory = {
    PowerUpType.bomb: 0,
    PowerUpType.wild: 0,
    PowerUpType.magnet: 0,
    PowerUpType.shield: 0,
  };

  PowerUpInventory() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (var type in PowerUpType.values) {
      _inventory[type] = prefs.getInt('powerup_${type.name}') ?? 0;
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (var entry in _inventory.entries) {
      await prefs.setInt('powerup_${entry.key.name}', entry.value);
    }
  }

  void add(PowerUpType type, int amount) {
    _inventory[type] = (_inventory[type] ?? 0) + amount;
    _saveToPrefs();
  }

  bool use(PowerUpType type) {
    if ((_inventory[type] ?? 0) > 0) {
      _inventory[type] = _inventory[type]! - 1;
      _saveToPrefs();
      return true;
    }
    return false;
  }

  int getCount(PowerUpType type) => _inventory[type] ?? 0;

  Map<PowerUpType, int> getAll() => Map.from(_inventory);
}

class PowerUpInfo {
  static String getName(PowerUpType type) {
    switch (type) {
      case PowerUpType.bomb:
        return 'Bomb';
      case PowerUpType.wild:
        return 'Wild Card';
      case PowerUpType.magnet:
        return 'Magnet';
      case PowerUpType.shield:
        return 'Shield';
    }
  }

  static String getDescription(PowerUpType type) {
    switch (type) {
      case PowerUpType.bomb:
        return 'Destroy bottom row';
      case PowerUpType.wild:
        return 'Merge with anything';
      case PowerUpType.magnet:
        return 'Pull same colors';
      case PowerUpType.shield:
        return 'Prevent game over';
    }
  }

  static String getEmoji(PowerUpType type) {
    switch (type) {
      case PowerUpType.bomb:
        return '💣';
      case PowerUpType.wild:
        return '🃏';
      case PowerUpType.magnet:
        return '🧲';
      case PowerUpType.shield:
        return '🛡️';
    }
  }

  static int getCoinPrice(PowerUpType type) {
    switch (type) {
      case PowerUpType.bomb:
        return 10;  // 10 coins
      case PowerUpType.shield:
        return 15;  // 15 coins
      case PowerUpType.wild:
        return 20;  // 20 coins
      case PowerUpType.magnet:
        return 12;  // 12 coins
    }
  }
}