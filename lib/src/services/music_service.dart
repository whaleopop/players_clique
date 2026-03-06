import 'package:flutter/foundation.dart';
import 'ynison_service.dart';

class MusicService extends ChangeNotifier {
  TrackInfo? _currentTrack;
  bool _isPlaying = false;

  TrackInfo? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;

  void setCurrentTrack(TrackInfo? track, {bool isPlaying = false}) {
    _currentTrack = track;
    _isPlaying = isPlaying;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    if (_isPlaying == playing) return;
    _isPlaying = playing;
    notifyListeners();
  }

  void clear() {
    _currentTrack = null;
    _isPlaying = false;
    notifyListeners();
  }
}
