import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _checkPlayer = AudioPlayer();
  final AudioPlayer _perfectPlayer = AudioPlayer();
  final AudioPlayer _trophyPlayer = AudioPlayer();
  bool _initialized = false;

  /// Preloads the audio files directly into memory/native player sources.
  /// This guarantees absolute zero latency click response when checking habits.
  Future<void> init() async {
    if (_initialized) return;
    try {
      await _checkPlayer.setSource(AssetSource('sounds/clin.wav'));
      await _perfectPlayer.setSource(AssetSource('sounds/tibetan_bowl.wav'));
      await _trophyPlayer.setSource(AssetSource('sounds/trophy.wav'));
      
      // Volumen ajustado para el nuevo sonido "clin"
      await _checkPlayer.setVolume(0.40);
      
      // Set release mode to stop to allow rapid replay
      await _checkPlayer.setReleaseMode(ReleaseMode.stop);
      await _perfectPlayer.setReleaseMode(ReleaseMode.stop);
      await _trophyPlayer.setReleaseMode(ReleaseMode.stop);
      
      _initialized = true;
    } catch (e) {
      // Graceful degradation
    }
  }

  /// Instantly plays the soft water droplet click with zero delay.
  Future<void> playCheck() async {
    try {
      await init(); 
      if (_checkPlayer.state == PlayerState.playing) {
        await _checkPlayer.stop();
      }
      await _checkPlayer.resume();
    } catch (e) {
      // Create a throwaway player if the main one is stuck
      AudioPlayer().play(AssetSource('sounds/clin.wav'));
    }
  }

  /// Instantly plays the deep, resonant Tibetan Singing Bowl chime.
  Future<void> playPerfectDay() async {
    try {
      await init();
      if (_perfectPlayer.state == PlayerState.playing) {
        await _perfectPlayer.stop();
      }
      await _perfectPlayer.resume();
    } catch (e) {}
  }

  /// Instantly plays the high quality metallic bell PlayStation style trophy sound.
  Future<void> playTrophy() async {
    try {
      await init();
      if (_trophyPlayer.state == PlayerState.playing) {
        await _trophyPlayer.stop();
      }
      await _trophyPlayer.resume();
    } catch (e) {}
  }
}
