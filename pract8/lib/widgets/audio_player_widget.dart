import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatelessWidget {
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final Function(Duration) onSeek;
  final String audioPath;

  const AudioPlayerWidget({
    super.key,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
    required this.audioPath,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = audioPath.split('/').last;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: position.inMilliseconds.toDouble(),
              max: duration.inMilliseconds.toDouble(),
              onChanged: (value) {
                onSeek(Duration(milliseconds: value.toInt()));
              },
              onChangeEnd: (value) {
                onSeek(Duration(milliseconds: value.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position)),
                Text(_formatDuration(duration)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: Icon(
                    isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.blue,
                  ),
                  onPressed: onPlayPause,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
