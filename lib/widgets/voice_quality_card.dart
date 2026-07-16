import 'package:flutter/material.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../core/theme.dart';
import '../data/models/models.dart';
import 'premium_card.dart';

/// Premium "voice quality" card surfaced on the assessment results
/// screen. Shows the four clinical metrics produced by the API
/// analyzer (jitter, shimmer, HNR, words-per-minute) as parent-
/// friendly tiles with traffic-light colours.
///
/// Renders nothing when [voiceQuality] is `null` or empty so the
/// parent screen can drop the widget into a column without
/// having to defend the empty case.
class VoiceQualityCard extends StatelessWidget {
  const VoiceQualityCard({super.key, required this.voiceQuality});

  final VoiceQuality? voiceQuality;

  @override
  Widget build(BuildContext context) {
    final vq = voiceQuality;
    if (vq == null || vq.isEmpty) return const SizedBox.shrink();

    final l = L.of(context)!;
    final overall = vq.overallStatus;
    final accent = _statusColor(overall);
    final headline = _headlineFor(l, overall);

    final tiles = <_MetricTileData>[
      if (vq.hasJitter)
        _MetricTileData(
          label: l.voiceQualityJitterLabel,
          description: l.voiceQualityJitterDescription,
          value: l.voiceQualityPercentValue(_fmtNumber(vq.jitterLocalPct!, 2)),
          status: vq.jitterStatus,
          icon: Icons.show_chart_rounded,
        ),
      if (vq.hasShimmer)
        _MetricTileData(
          label: l.voiceQualityShimmerLabel,
          description: l.voiceQualityShimmerDescription,
          value: l.voiceQualityPercentValue(
            _fmtNumber(vq.shimmerLocalPct!, 2),
          ),
          status: vq.shimmerStatus,
          icon: Icons.equalizer_rounded,
        ),
      if (vq.hasHnr)
        _MetricTileData(
          label: l.voiceQualityHnrLabel,
          description: l.voiceQualityHnrDescription,
          value: l.voiceQualityDecibelValue(_fmtNumber(vq.hnrDb!, 1)),
          status: vq.hnrStatus,
          icon: Icons.graphic_eq_rounded,
        ),
      if (vq.hasSpeechRate)
        _MetricTileData(
          label: l.voiceQualitySpeechRateLabel,
          description: l.voiceQualitySpeechRateDescription,
          value: l.voiceQualityWpmValue(_fmtNumber(vq.speechRateWpm!, 0)),
          status: vq.speechRateStatus,
          icon: Icons.speed_rounded,
        ),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: l.voiceQualitySemantics(_statusLabel(l, overall)),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.spatial_audio_rounded,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.voiceQualityTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.voiceQualitySubtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(status: overall),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: accent.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(_headlineIcon(overall), size: 18, color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      headline,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Two-column grid of metric tiles. We render manually
            // (rather than using GridView) so the column count adapts
            // to one when the available width is narrow (e.g. a small
            // phone in landscape on a split screen).
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = constraints.maxWidth >= 320;
                if (!twoCol) {
                  return Column(
                    children: [
                      for (final t in tiles) ...[
                        _MetricTile(data: t),
                        if (t != tiles.last)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                }
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final t in tiles)
                      SizedBox(
                        width: (constraints.maxWidth - AppSpacing.sm) / 2,
                        child: _MetricTile(data: t),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(VoiceQualityStatus s) {
    switch (s) {
      case VoiceQualityStatus.normal:
        return AppColors.success;
      case VoiceQualityStatus.elevated:
        return AppColors.warning;
      case VoiceQualityStatus.abnormal:
        return AppColors.danger;
      case VoiceQualityStatus.unknown:
        return AppColors.textSecondary;
    }
  }

  static IconData _headlineIcon(VoiceQualityStatus s) {
    switch (s) {
      case VoiceQualityStatus.normal:
        return Icons.verified_rounded;
      case VoiceQualityStatus.elevated:
        return Icons.info_outline_rounded;
      case VoiceQualityStatus.abnormal:
        return Icons.warning_amber_rounded;
      case VoiceQualityStatus.unknown:
        return Icons.help_outline_rounded;
    }
  }

  static String _headlineFor(L l, VoiceQualityStatus s) {
    switch (s) {
      case VoiceQualityStatus.normal:
        return l.voiceQualityHeadlineNormal;
      case VoiceQualityStatus.elevated:
        return l.voiceQualityHeadlineElevated;
      case VoiceQualityStatus.abnormal:
        return l.voiceQualityHeadlineAbnormal;
      case VoiceQualityStatus.unknown:
        return l.voiceQualityStatusUnknown;
    }
  }

  static String _statusLabel(L l, VoiceQualityStatus s) {
    switch (s) {
      case VoiceQualityStatus.normal:
        return l.voiceQualityStatusNormal;
      case VoiceQualityStatus.elevated:
        return l.voiceQualityStatusElevated;
      case VoiceQualityStatus.abnormal:
        return l.voiceQualityStatusAbnormal;
      case VoiceQualityStatus.unknown:
        return l.voiceQualityStatusUnknown;
    }
  }

  /// Format a number with a fixed number of decimals and trim a
  /// trailing `.0` when the precision is zero so the WPM tile reads
  /// "120 so'z/daq" instead of "120.0 so'z/daq".
  static String _fmtNumber(double value, int decimals) {
    if (decimals <= 0) return value.round().toString();
    return value.toStringAsFixed(decimals);
  }
}

class _MetricTileData {
  const _MetricTileData({
    required this.label,
    required this.description,
    required this.value,
    required this.status,
    required this.icon,
  });

  final String label;
  final String description;
  final String value;
  final VoiceQualityStatus status;
  final IconData icon;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});
  final _MetricTileData data;

  @override
  Widget build(BuildContext context) {
    final color = VoiceQualityCard._statusColor(data.status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final VoiceQualityStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final color = VoiceQualityCard._statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        VoiceQualityCard._statusLabel(l, status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
