import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:neon_merge/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/intro_splash_screen.dart';
import 'screens/game_screen.dart';
import 'services/game_state.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize AdMob
  await MobileAds.instance.initialize();
  
  // Log app open
  final analytics = AnalyticsService();
  await analytics.logAppOpen();
  
  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Load preferences
  final prefs = await SharedPreferences.getInstance();
  final highScore = prefs.getInt('highScore') ?? 0;
  
  runApp(NeonMergeApp(highScore: highScore));
}

class NeonMergeApp extends StatefulWidget {
  final int highScore;
  
  const NeonMergeApp({super.key, required this.highScore});

  @override
  State<NeonMergeApp> createState() => _NeonMergeAppState();
}

class _NeonMergeAppState extends State<NeonMergeApp> {
  bool _showIntro = true;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GameState(widget.highScore),
        ),
        Provider(
          create: (_) => AdService(),
        ),
      ],
      child: MaterialApp(
        title: 'Neon Merge: Zen Drop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF050507),
          primaryColor: const Color(0xFF00F2FF),
          fontFamily: 'Segoe UI',
        ),
        home: _showIntro
            ? IntroSplashScreen(
                onComplete: () {
                  setState(() {
                    _showIntro = false;
                  });
                },
              )
            : const GameScreen(),
      ),
    );
  }
}