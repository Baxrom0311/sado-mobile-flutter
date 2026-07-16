import 'dart:collection';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/services/audio_recorder_service.dart';

/// Animated waveform.
///
/// You can drive it in two ways:
///   1. [samples] — a `Stream<AmplitudeSample>` (preferred when wired to
///      [AudioRecorderService]).
///   2. [amplitude] — a single dBFS value (negative; 0 = max, -60 = silent),
///      which is what `record`'s `Amplitude.current` exposes. Each time
///      this widget rebuilds with a new value we push a sample into the
///      rolling buffer.
///
/// When neither is provided we render a flat resting baseline so the slot
/// doesn't collapse during idle.
class WaveformVisualizer extends StatefulWidget {
  const WaveformVisualizer({
    super.key,
    this.samples,
    this.amplitude,
    this.barCount = 32,
    this.height = 64,
    this.color = AppColors.primary,
    this.activeColor = AppColors.danger,
    this.active = false,
  });

  final Stream<AmplitudeSample>? samples;
  final double? amplitude;
  final int barCount;
  final double height;
  final Color color;
  final Color activeColor;
  final bool active;

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer> {
  late final Queue<double> _buf;

  @override
  void initState() {
    super.initState();
    _buf = Queue<double>.from(List.filled(widget.barCount, 0.04));
    widget.samples?.listen(_onSample);
    if (widget.amplitude != null) _pushDbfs(widget.amplitude!);
  }

  @override
  void didUpdateWidget(covariant WaveformVisualizer old) {
    super.didUpdateWidget(old);
    if (old.samples != widget.samples) {
      widget.samples?.listen(_onSample);
    }
    if (old.barCount != widget.barCount) {
      _buf
        ..clear()
        ..addAll(List.filled(widget.barCount, 0.04));
    }
    if (widget.amplitude != null && old.amplitude != widget.amplitude) {
      _pushDbfs(widget.amplitude!);
    }
  }

  void _onSample(AmplitudeSample s) {
    if (!mounted) return;
    setState(() {
      _buf.removeFirst();
      _buf.addLast(s.normalized.clamp(0.04, 1.0));
    });
  }

  void _pushDbfs(double dbfs) {
    // Convert from dBFS (0 = max, -60 = silent) into 0..1 normalized.
    final clamped = dbfs.clamp(-60.0, 0.0);
    final normalized = ((clamped + 60.0) / 60.0).clamp(0.04, 1.0);
    if (!mounted) return;
    setState(() {
      _buf.removeFirst();
      _buf.addLast(normalized);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _WaveformPainter(
          values: _buf.toList(growable: false),
          color: widget.active ? widget.activeColor : widget.color,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final n = values.length;
    final gap = 3.0;
    final barWidth = (size.width - gap * (n - 1)) / n;
    final cy = size.height / 2;

    for (var i = 0; i < n; i++) {
      final v = values[i].clamp(0.04, 1.0);
      final h = (size.height * v).clamp(4.0, size.height);
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, cy - h / 2, barWidth, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.values != values || old.color != color;
}
