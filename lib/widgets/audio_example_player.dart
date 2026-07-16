import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/theme.dart';
import 'loaders.dart';

/// Plays a single remote audio "example" with play / pause / seek bar.
/// Used on the exercise detail screen so kids can hear the target sound
/// before recording themselves.
class AudioExamplePlayer extends StatefulWidget {
  const AudioExamplePlayer({
    super.key,
    required this.url,
    required this.label,
    required this.errorLabel,
    this.color = AppColors.primary,
  });

  final String url;
  final String label;
  final String errorLabel;
  final Color color;

  @override
  State<AudioExamplePlayer> createState() => _AudioExamplePlayerState();
}

class _AudioExamplePlayerState extends State<AudioExamplePlayer> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _duration = await _player.setUrl(widget.url) ?? Duration.zero;
      if (!mounted) return;
      setState(() => _loading = false);

      _stateSub = _player.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
        setState(() {});
      });
      _posSub = _player.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.errorLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final playing = _player.playing;
    final total = _duration.inMilliseconds.clamp(1, 1 << 30);
    final progress =
        (_position.inMilliseconds / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: widget.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _loading ? null : _togglePlay,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _loading
                    ? widget.color.withValues(alpha: 0.4)
                    : widget.color,
                shape: BoxShape.circle,
                boxShadow: AppShadow.soft(widget.color, opacity: 0.25),
              ),
              child: _loading
                  ? Center(
                      child: const BrandedSpinner(
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : Icon(
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: widget.color.withValues(alpha: 0.15),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(widget.color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(_position)} / ${_fmt(_duration)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
