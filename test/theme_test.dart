import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/theme.dart';

void main() {
  group('AppColors.categoryColor', () {
    test('returns brand colors for known categories', () {
      expect(AppColors.categoryColor('articulation'), AppColors.primary);
      expect(AppColors.categoryColor('breathing'), AppColors.sky);
      expect(AppColors.categoryColor('vocabulary'), AppColors.pink);
      expect(AppColors.categoryColor('fluency'), AppColors.secondary);
      expect(AppColors.categoryColor('listening'), AppColors.tertiary);
      expect(AppColors.categoryColor('phonemic_awareness'), AppColors.accent);
    });

    test('falls back to primary for unknown category', () {
      expect(AppColors.categoryColor('unknown'), AppColors.primary);
    });
  });

  group('AppColors.difficultyColor', () {
    test('maps levels to risk-style colors', () {
      expect(AppColors.difficultyColor('easy'), AppColors.success);
      expect(AppColors.difficultyColor('medium'), AppColors.warning);
      expect(AppColors.difficultyColor('hard'), AppColors.danger);
    });

    test('returns muted text color for unknown difficulty', () {
      expect(AppColors.difficultyColor('???'), AppColors.textMuted);
    });
  });

  group('AppColors.riskColor', () {
    test('handles both color names and severity labels', () {
      expect(AppColors.riskColor('green'), AppColors.success);
      expect(AppColors.riskColor('low'), AppColors.success);
      expect(AppColors.riskColor('yellow'), AppColors.warning);
      expect(AppColors.riskColor('medium'), AppColors.warning);
      expect(AppColors.riskColor('red'), AppColors.danger);
      expect(AppColors.riskColor('high'), AppColors.danger);
    });

    test('returns muted text color for null or unknown', () {
      expect(AppColors.riskColor(null), AppColors.textMuted);
      expect(AppColors.riskColor('???'), AppColors.textMuted);
    });
  });

  group('Spacing & radius constants', () {
    test('spacing follows 4px grid', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.xxl, 32);
    });

    test('radius pill is large enough to look fully rounded', () {
      expect(AppRadius.pill, greaterThan(100));
    });
  });

  group('AppShadow.soft', () {
    test('produces a single shadow with the given color', () {
      final shadows = AppShadow.soft(const Color(0xFF22C55E));
      expect(shadows, hasLength(1));
      expect(shadows.first.color.toARGB32() & 0x00FFFFFF,
          0xFF22C55E & 0x00FFFFFF);
    });
  });
}
