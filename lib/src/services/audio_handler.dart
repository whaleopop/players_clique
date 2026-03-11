import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

/// Global singleton — initialised in main() before runApp().
late PlayerAudioHandler audioHandler;

class PlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  /// Called when the OS (or user) requests skip-next / skip-prev.
  void Function()? onNext;
  void Function()? onPrev;

  Duration _pos = Duration.zero;

  PlayerAudioHandler() {
    // Configure background audio session
    AudioPlayer.global.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {},
      ),
    ));

    _player.onPlayerStateChanged.listen(_onStateChanged);
    _player.onPositionChanged.listen(_onPositionChanged);
    _player.onDurationChanged.listen(_onDurationChanged);
    _player.onPlayerComplete.listen((_) => skipToNext());

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  AudioPlayer get player => _player;

  void _onStateChanged(PlayerState state) {
    final playing = state == PlayerState.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      processingState: state == PlayerState.stopped
          ? AudioProcessingState.idle
          : AudioProcessingState.ready,
      playing: playing,
      updatePosition: _pos,
    ));
  }

  void _onPositionChanged(Duration pos) {
    _pos = pos;
    playbackState.add(playbackState.value.copyWith(updatePosition: pos));
  }

  void _onDurationChanged(Duration dur) {
    final current = mediaItem.value;
    if (current != null) {
      mediaItem.add(current.copyWith(duration: dur));
    }
  }

  /// Play a URL with full media metadata for lock-screen / control-center.
  Future<void> playUrl(String url, MediaItem item) async {
    mediaItem.add(item);
    await _player.play(UrlSource(url));
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async => onNext?.call();

  @override
  Future<void> skipToPrevious() async => onPrev?.call();

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
    ));
  }
}
