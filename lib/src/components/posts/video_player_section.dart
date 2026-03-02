import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Reusable video player with play/pause (center tap + bottom button) and mute toggle.
class VideoPlayerSection extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerSection({super.key, required this.videoUrl});

  @override
  State<VideoPlayerSection> createState() => _VideoPlayerSectionState();
}

class _VideoPlayerSectionState extends State<VideoPlayerSection> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
          ..initialize().then((_) {
            if (mounted) setState(() => _initialized = true);
          });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  void _toggleMute() {
    _controller.setVolume(_controller.value.volume == 0.0 ? 1.0 : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          color: Colors.black,
          child: const Center(
            child:
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        ),
      );
    }

    final isPlaying = _controller.value.isPlaying;
    final isMuted = _controller.value.volume == 0.0;

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        children: [
          // Video
          VideoPlayer(_controller),

          // Tappable overlay — play/pause on tap
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: Container(color: Colors.transparent),
          ),

          // Big centered play icon — visible when paused
          if (!isPlaying)
            IgnorePointer(
              child: Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 44),
                ),
              ),
            ),

          // Bottom control bar — always visible
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  // Play / Pause button
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  // Mute / Unmute button
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Icon(
                      isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
