import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class AlarmRingService {
  static AudioPlayer? _audioPlayer;
  static bool _isRinging = false;

  /// Start ringing the alarm with sound and vibration
  static Future<void> startRinging() async {
    if (_isRinging) {
      debugPrint('⚠️ Already ringing, skipping...');
      return;
    }

    _isRinging = true;
    debugPrint('🔔 Starting alarm ring...');

    try {
      // Start vibration pattern (vibrate for 1s, pause 0.5s, repeat)
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        // Vibrate continuously with pattern
        Vibration.vibrate(
          pattern: [0, 1000, 500, 1000, 500], // ms: [delay, vibrate, pause, ...]
          repeat: 0, // Repeat from index 0
        );
        debugPrint('📳 Vibration started');
      }

      // Play alarm sound on loop
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.setVolume(1.0); // Max volume

      // Try to play from asset
      try {
        await _audioPlayer!.play(AssetSource('sounds/alarm_sound'));
        debugPrint('🔊 Playing alarm from assets');
      } catch (e) {
        debugPrint('⚠️ Could not play from assets: $e');
        // Fallback: use a generated tone or system sound
      }

      debugPrint('🔊 Alarm sound started');
    } catch (e) {
      debugPrint('❌ Error starting alarm: $e');
    }
  }

  /// Stop the alarm
  static Future<void> stopRinging() async {
    if (!_isRinging) return;

    debugPrint('🔕 Stopping alarm...');

    try {
      // Stop vibration
      await Vibration.cancel();
      debugPrint('📳 Vibration stopped');

      // Stop audio
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
        debugPrint('🔊 Alarm sound stopped');
      }

      _isRinging = false;
    } catch (e) {
      debugPrint('❌ Error stopping alarm: $e');
    }
  }

  /// Check if alarm is currently ringing
  static bool get isRinging => _isRinging;
}