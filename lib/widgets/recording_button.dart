import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils/haptics.dart';

/// Pulsing recording button with concentric rings while recording.
class RecordingButton extends StatefulWidget {
  const RecordingButton({
    super.key,
    required this.recording,
    required this.onTap,
    this.size = 96,
  });

  final bool recording;
  final VoidCallback onTap;
  final double size;

  @override
  State<RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<RecordingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.recording) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant RecordingButton old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.recording) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.recording ? AppColors.danger : AppColors.primary;
    return GestureDetector(
      onTap: () {
        Haptics.medium();
        widget.onTap();
      },
      child: SizedBox(
        width: widget.size + 80,
        height: widget.size + 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.recording)
              ...List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final phase = ((_c.value + i / 3) % 1);
                    final r = widget.size + phase * 80;
                    final opacity = (1 - phase).clamp(0.0, 1.0);
                    return Container(
                      width: r,
                      height: r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.18 * opacity),
                      ),
                    );
                  },
                );
              }),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: AppShadow.soft(color, opacity: 0.4),
              ),
              child: Icon(
                widget.recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: widget.size * 0.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
