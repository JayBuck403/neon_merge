import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_state.dart';
import '../services/powerup_service.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';

class PowerUpBar extends StatelessWidget {
  final Function(PowerUpType) onPowerUpUsed;

  const PowerUpBar({
    super.key,
    required this.onPowerUpUsed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        if (!gameState.isPlaying) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPowerUpButton(
                context,
                PowerUpType.bomb,
                gameState.powerUpInventory.getCount(PowerUpType.bomb),
              ),
              _buildPowerUpButton(
                context,
                PowerUpType.shield,
                gameState.powerUpInventory.getCount(PowerUpType.shield),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPowerUpButton(
    BuildContext context,
    PowerUpType type,
    int count,
  ) {
    final isDisabled = count <= 0;
    
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: () => _handlePowerUpTap(context, type, count),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isDisabled
                ? Colors.black26
                : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled
                  ? Colors.white12
                  : const Color(0xFF00F2FF),
              width: 2,
            ),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF00F2FF).withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  PowerUpInfo.getEmoji(type),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00F2FF),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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

  void _handlePowerUpTap(BuildContext context, PowerUpType type, int count) {
    if (count > 0) {
      // Use the power-up
      final gameState = context.read<GameState>();
      if (gameState.powerUpInventory.use(type)) {
        onPowerUpUsed(type);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${PowerUpInfo.getName(type)} activated!',
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF00F2FF),
          ),
        );
      }
    } else {
      // Show ad offer dialog
      _showGetPowerUpDialog(context, type);
    }
  }

  void _showGetPowerUpDialog(BuildContext context, PowerUpType type) {
    final adService = context.read<AdService>();
    final gameState = context.read<GameState>();
    final coinPrice = PowerUpInfo.getCoinPrice(type);
    final hasEnoughCoins = gameState.coins >= coinPrice;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          'GET ${PowerUpInfo.getName(type).toUpperCase()}?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              PowerUpInfo.getEmoji(type),
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              PowerUpInfo.getDescription(type),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Coin balance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'You have: ${gameState.coins} coins',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Choose your payment method:',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          
          // Buy with coins button
          ElevatedButton.icon(
            onPressed: hasEnoughCoins
                ? () async {
                    Navigator.of(dialogContext).pop();
                    
                    // Spend coins
                    final success = await gameState.spendCoins(coinPrice);
                    if (success) {
                      gameState.powerUpInventory.add(type, 1);
                      
                      // Track power-up purchase with coins
                      AnalyticsService().logPowerUpPurchased(
                        powerUpType: type.toString().split('.').last,
                        purchaseMethod: 'coins',
                      );
                      AnalyticsService().logCoinsSpent(
                        amount: coinPrice,
                        item: type.toString().split('.').last,
                      );
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Bought: ${PowerUpInfo.getEmoji(type)} ${PowerUpInfo.getName(type)}!',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: const Color(0xFF00FF00),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  }
                : null,
            icon: const Icon(Icons.monetization_on, size: 18),
            label: Text('$coinPrice COINS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasEnoughCoins ? const Color(0xFFFFD700) : Colors.grey,
              foregroundColor: Colors.black,
            ),
          ),
          
          // Watch ad button
          ElevatedButton.icon(
            onPressed: adService.isRewardedAdReady
                ? () async {
                    Navigator.of(dialogContext).pop();
                    
                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00F2FF)),
                      ),
                    );
                    
                    await Future.delayed(const Duration(milliseconds: 100));
                    
                    try {
                      await adService.showRewardedAd(
                        onRewarded: () {
                          gameState.powerUpInventory.add(type, 1);
                          
                          // Track power-up purchase with ad
                          AnalyticsService().logPowerUpPurchased(
                            powerUpType: type.toString().split('.').last,
                            purchaseMethod: 'ad',
                          );
                          AnalyticsService().logAdRewarded(
                            placement: 'power_up',
                            reward: 'power_up',
                          );
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'You got: ${PowerUpInfo.getEmoji(type)} ${PowerUpInfo.getName(type)}!',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: const Color(0xFF00FF00),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                      
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Dismiss loading
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  }
                : null,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('WATCH AD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: adService.isRewardedAdReady 
                  ? const Color(0xFF00F2FF) 
                  : Colors.grey,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}