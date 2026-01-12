import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _initialized = false;
  bool _isPlayingSound = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
      
      // Configure players for better performance
      await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.3);
      
      _initialized = true;
    } catch (e) {
      debugPrint('Sound initialization error: $e');
      _initialized = false;
    }
  }

  // Sound effects with queue protection
  Future<void> playDrop() async {
    if (!_soundEnabled || _isPlayingSound) return;
    
    _isPlayingSound = true;
    
    try {
      await _sfxPlayer.stop(); // Stop any previous sound
      await _sfxPlayer.play(AssetSource('sounds/drop.mp3'), volume: 0.4);
    } catch (e) {
      // Silent fail
    } finally {
      // Reset flag after short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _isPlayingSound = false;
      });
    }
  }

  Future<void> playMerge(int level) async {
    if (!_soundEnabled) return;
    
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/merge.mp3'), volume: 0.4);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> playGameOver() async {
    if (!_soundEnabled) return;
    
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/gameover.mp3'), volume: 0.6);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> playWin() async {
    if (!_soundEnabled) return;
    
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/win.mp3'), volume: 0.7);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> playCombo() async {
    if (!_soundEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('sounds/combo.mp3'), volume: 0.6);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> playPowerUp() async {
    if (!_soundEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('sounds/powerup.mp3'), volume: 0.5);
    } catch (e) {
      // Silent fail
    }
  }

  // Background music
  Future<void> playBackgroundMusic() async {
    if (!_musicEnabled) return;
    
    try {
      await _musicPlayer.play(AssetSource('music/background.mp3'), volume: 0.5);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> pauseBackgroundMusic() async {
    try {
      await _musicPlayer.pause();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> resumeBackgroundMusic() async {
    if (!_musicEnabled) return;
    try {
      await _musicPlayer.resume();
    } catch (e) {
      // Silent fail
    }
  }

  // Settings
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_enabled', enabled);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('music_enabled', enabled);
      
      if (enabled) {
        await playBackgroundMusic();
      } else {
        await stopBackgroundMusic();
      }
    } catch (e) {
      // Silent fail
    }
  }

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  void dispose() {
    try {
      _sfxPlayer.dispose();
      _musicPlayer.dispose();
    } catch (e) {
      // Silent fail
    }
  }
}