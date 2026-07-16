import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Wrap a screen body with this to trigger confetti on success events.
class ConfettiHost extends StatefulWidget {
  const ConfettiHost({super.key, required this.child, required this.controller});

  final Widget child;
  final ConfettiController controller;

  @override
  State<ConfettiHost> createState() => _ConfettiHostState();
}

class _ConfettiHostState extends State<ConfettiHost> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: widget.controller,
            blastDirection: pi / 2,
            emissionFrequency: 0.05,
            numberOfParticles: 24,
            maxBlastForce: 22,
            minBlastForce: 8,
            gravity: 0.25,
            shouldLoop: false,
            colors: const [
              AppColors.primary,
              AppColors.secondary,
              AppColors.accent,
              AppColors.tertiary,
              AppColors.sky,
              AppColors.pink,
            ],
          ),
        ),
      ],
    );
  }
}
