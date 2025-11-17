import 'package:just_audio/just_audio.dart';
import '../models/track.dart';

/// Service for playing 30-90 second track previews from Apple Music/iTunes
/// Manages a single audio player instance for the app
class MusicPreviewPlayer {
  final AudioPlayer _player;

  Track? _currentTrack;
  bool _isDisposed = false;

  MusicPreviewPlayer() : _player = AudioPlayer() {
    // Set up error handling
    _player.playbackEventStream.listen(
      null,
      onError: (Object e, StackTrace stackTrace) {
        print('[PreviewPlayer] Playback error: $e');
        print('[PreviewPlayer] Stack trace: $stackTrace');
      },
    );
  }

  /// Currently playing/loaded track
  Track? get currentTrack => _currentTrack;

  /// Whether a track is currently playing
  bool get isPlaying => _player.playing;

  /// Current playback state stream
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Current position stream
  Stream<Duration> get positionStream => _player.positionStream;

  /// Total duration of current track
  Duration? get duration => _player.duration;

  /// Current position in playback
  Duration get position => _player.position;

  /// Processing state (loading, ready, completed, etc.)
  ProcessingState get processingState => _player.processingState;

  /// Play or resume playback
  Future<void> play() async {
    if (_isDisposed) return;
    try {
      await _player.play();
    } catch (e) {
      print('[PreviewPlayer] Error playing: $e');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    if (_isDisposed) return;
    try {
      await _player.pause();
    } catch (e) {
      print('[PreviewPlayer] Error pausing: $e');
    }
  }

  /// Stop playback and reset
  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _player.stop();
      _currentTrack = null;
    } catch (e) {
      print('[PreviewPlayer] Error stopping: $e');
    }
  }

  /// Load and play a track preview
  /// If the track is already loaded, toggles play/pause
  /// If a different track is loaded, stops it and loads the new one
  Future<void> playTrack(Track track) async {
    if (_isDisposed) return;

    // If this track is already loaded, toggle play/pause
    if (_currentTrack == track) {
      if (isPlaying) {
        await pause();
      } else {
        await play();
      }
      return;
    }

    // Check if track has preview URL
    if (track.previewUrl == null || track.previewUrl!.isEmpty) {
      print('[PreviewPlayer] Track has no preview URL: ${track.title}');
      return;
    }

    try {
      // Stop current track if playing
      if (_currentTrack != null) {
        await stop();
      }

      // Set the new track
      _currentTrack = track;

      // Load the preview URL
      await _player.setUrl(track.previewUrl!);

      // Auto-play
      await _player.play();
    } catch (e) {
      print('[PreviewPlayer] Error loading track: $e');
      _currentTrack = null;
    }
  }

  /// Seek to a position in the current track
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    try {
      await _player.seek(position);
    } catch (e) {
      print('[PreviewPlayer] Error seeking: $e');
    }
  }

  /// Set the volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      print('[PreviewPlayer] Error setting volume: $e');
    }
  }

  /// Dispose the player (call when no longer needed)
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _currentTrack = null;

    try {
      await _player.dispose();
    } catch (e) {
      print('[PreviewPlayer] Error disposing player: $e');
    }
  }

  /// Check if a specific track is currently playing
  bool isTrackPlaying(Track track) {
    return _currentTrack == track && isPlaying;
  }

  /// Check if a specific track is currently loaded (but maybe paused)
  bool isTrackLoaded(Track track) {
    return _currentTrack == track;
  }
}
