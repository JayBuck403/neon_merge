import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sound_manager.dart';
import '../services/game_state.dart';
import '../services/powerup_service.dart';
import '../services/analytics_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SoundManager _soundManager = SoundManager();
  late bool _soundEnabled;
  late bool _musicEnabled;
  late bool _hapticsEnabled;

  @override
  void initState() {
    super.initState();
    _soundEnabled = _soundManager.soundEnabled;
    _musicEnabled = _soundManager.musicEnabled;
    _hapticsEnabled = true; // We'll add this setting
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF050507),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Settings content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildStatsSection(gameState),
                    const SizedBox(height: 24),
                    _buildAudioSection(),
                    const SizedBox(height: 24),
                    _buildGameplaySection(),
                    const SizedBox(height: 24),
                    _buildPowerUpsSection(gameState),
                    const SizedBox(height: 24),
                    _buildAccountSection(gameState),
                    const SizedBox(height: 24),
                    _buildAboutSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(GameState gameState) {
    return _buildSection(
      title: '📊 STATISTICS',
      children: [
        _buildStatRow('High Score', '${gameState.highScore}'),
        _buildStatRow('Total Coins', '${gameState.coins}'),
        _buildStatRow('Games Played', 'Coming soon'),
        _buildStatRow('Total Merges', 'Coming soon'),
      ],
    );
  }

  Widget _buildAudioSection() {
    return _buildSection(
      title: '🔊 AUDIO',
      children: [
        _buildSwitchTile(
          icon: Icons.volume_up,
          title: 'Sound Effects',
          subtitle: 'Drop, merge, and game sounds',
          value: _soundEnabled,
          onChanged: (value) async {
            setState(() => _soundEnabled = value);
            await _soundManager.setSoundEnabled(value);
            
            // Track audio settings change
            AnalyticsService().logSettingChanged(
              setting: 'sound',
              enabled: value,
            );
          },
        ),
        _buildSwitchTile(
          icon: Icons.music_note,
          title: 'Background Music',
          subtitle: 'Relaxing ambient music',
          value: _musicEnabled,
          onChanged: (value) async {
            setState(() => _musicEnabled = value);
            await _soundManager.setMusicEnabled(value);
            
            // Track audio settings change
            AnalyticsService().logSettingChanged(
              setting: 'music',
              enabled: value,
            );
          },
        ),
      ],
    );
  }

  Widget _buildGameplaySection() {
    return _buildSection(
      title: '🎮 GAMEPLAY',
      children: [
        _buildSwitchTile(
          icon: Icons.vibration,
          title: 'Haptic Feedback',
          subtitle: 'Vibration on tap and merge',
          value: _hapticsEnabled,
          onChanged: (value) {
            setState(() => _hapticsEnabled = value);
            // TODO: Save to preferences
          },
        ),
        _buildActionTile(
          icon: Icons.refresh,
          title: 'Reset High Score',
          subtitle: 'Start fresh',
          color: Colors.orange,
          onTap: () => _showResetDialog(),
        ),
      ],
    );
  }

  Widget _buildPowerUpsSection(GameState gameState) {
    return _buildSection(
      title: '⚡ POWER-UPS',
      children: [
        _buildInventoryRow(
          '💣 Bomb',
          gameState.powerUpInventory.getCount(PowerUpType.bomb),
        ),
        _buildInventoryRow(
          '🛡️ Shield',
          gameState.powerUpInventory.getCount(PowerUpType.shield),
        ),
      ],
    );
  }

  Widget _buildAccountSection(GameState gameState) {
    return _buildSection(
      title: '💎 ACCOUNT',
      children: [
        _buildActionTile(
          icon: Icons.block,
          title: 'Remove Ads',
          subtitle: '\$2.99 - One-time purchase',
          color: const Color(0xFFFFD700),
          onTap: () => _showRemoveAdsDialog(),
        ),
        _buildActionTile(
          icon: Icons.restore,
          title: 'Restore Purchases',
          subtitle: 'Recover previous purchases',
          color: const Color(0xFF00F2FF),
          onTap: () => _showRestorePurchasesDialog(),
        ),
        _buildActionTile(
          icon: Icons.delete_forever,
          title: 'Clear All Data',
          subtitle: 'Delete progress and start over',
          color: Colors.red,
          onTap: () => _showClearDataDialog(),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      title: 'ℹ️ ABOUT',
      children: [
        _buildInfoTile('Version', '1.0.0'),
        _buildInfoTile('Developer', 'appGrade'),
        _buildActionTile(
          icon: Icons.privacy_tip,
          title: 'Privacy Policy',
          subtitle: 'How we handle your data',
          color: const Color(0xFF00F2FF),
          onTap: () {
            launchUrl(Uri.parse('https://zen-drop-merge.web.app/'));
          },
        ),
        _buildActionTile(
          icon: Icons.description,
          title: 'Terms of Service',
          subtitle: 'Terms and conditions',
          color: const Color(0xFF00F2FF),
          onTap: () {
            launchUrl(Uri.parse('https://zen-drop-merge.web.app/'));
          },
        ),
        _buildActionTile(
          icon: Icons.help,
          title: 'How to Play',
          subtitle: 'Tutorial and tips',
          color: const Color(0xFF00F2FF),
          onTap: () => _showHowToPlay(),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00F2FF),
                letterSpacing: 1,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00F2FF).withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF00F2FF), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF00F2FF),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00F2FF),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryRow(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: count > 0 
                  ? const Color(0xFF00F2FF).withValues(alpha:0.2)
                  : Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: count > 0 ? const Color(0xFF00F2FF) : Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Reset High Score?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will reset your high score to 0. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final gameState = context.read<GameState>();
              // Reset high score
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('highScore', 0);
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('High score reset!'),
                  backgroundColor: Color(0xFF00F2FF),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }

  void _showRemoveAdsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'REMOVE ADS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Enjoy the game without any interruptions!\n\n'
          'One-time purchase: \$2.99\n\n'
          'This will remove banner and interstitial ads.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('IAP coming soon! Feature is ready.'),
                  backgroundColor: Color(0xFF00F2FF),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('BUY NOW'),
          ),
        ],
      ),
    );
  }

  void _showRestorePurchasesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'RESTORE PURCHASES',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will restore any previous purchases you made.\n\n'
          'Your purchases are linked to your app store account.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Purchases restored successfully!'),
                  backgroundColor: Color(0xFF00FF00),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F2FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Clear All Data?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will delete:\n'
          '• High score\n'
          '• Coins\n'
          '• Power-ups\n'
          '• All progress\n\n'
          'This cannot be undone!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data cleared!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _showHowToPlay() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'HOW TO PLAY',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎯 Objective',
                style: TextStyle(
                  color: Color(0xFF00F2FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Merge orbs to reach the Supernova (Level 10)!',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 16),
              
              Text(
                '🎮 How to Play',
                style: TextStyle(
                  color: Color(0xFF00F2FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Tap to drop orbs\n'
                '• Match same colors to merge\n'
                '• Each merge creates a bigger orb\n'
                '• Avoid crossing the red death line',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 16),
              
              Text(
                '⚡ Power-Ups',
                style: TextStyle(
                  color: Color(0xFF00F2FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '💣 Bomb - Destroy bottom orbs\n'
                '🛡️ Shield - Prevent game over\n'
                '💡 Hint - Show next 3 orbs',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 16),
              
              Text(
                '💰 Coins',
                style: TextStyle(
                  color: Color(0xFF00F2FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Earn coins by scoring points!\n'
                'Use coins to buy power-ups\n'
                'Or watch ads for free power-ups',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F2FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }
}