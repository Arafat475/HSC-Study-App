import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Plays the goal-reached alarm on a loop, with adjustable volume, and
/// keeps going (sound + a real repeating device vibration, not just a
/// light haptic tap) until [stop] is called -- i.e. until the user
/// actually responds to the "time's up" prompt, rather than a single blip
/// that's easy to miss or feel.
class AlarmPlayer {
  AlarmPlayer._internal();
  static final AlarmPlayer instance = AlarmPlayer._internal();

  AudioPlayer? _player;
  bool _playing = false;

  Future<void> start({required bool sound, required bool vibration, required double volume}) async {
    if (_playing) return;
    _playing = true;

    if (sound) {
      try {
        _player = AudioPlayer();
        await _player!.setReleaseMode(ReleaseMode.loop);
        await _player!.setVolume(volume.clamp(0.0, 1.0));
        await _player!.play(AssetSource('sounds/alarm.wav'));
      } catch (_) {
        // If the asset/player fails for any reason, fall back to a single
        // system sound rather than leaving the user with no alert at all.
        SystemSound.play(SystemSoundType.alert);
      }
    }

    if (vibration) {
      try {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator) {
          // A real, strong buzz-pause-buzz pattern (not Flutter's weak
          // HapticFeedback taps), looped from the pattern's start (index 0)
          // until stop() calls Vibration.cancel().
          Vibration.vibrate(
            pattern: [0, 700, 300, 700, 300, 700, 300],
            intensities: [0, 255, 0, 255, 0, 255, 0],
            repeat: 0,
          );
        } else {
          HapticFeedback.heavyImpact();
        }
      } catch (_) {
        HapticFeedback.heavyImpact();
      }
    }
  }

  Future<void> stop() async {
    _playing = false;
    try {
      await Vibration.cancel();
    } catch (_) {
      // Ignore -- may not be supported on this device.
    }
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {
      // Ignore -- player may already be gone.
    }
    _player = null;
  }
}
