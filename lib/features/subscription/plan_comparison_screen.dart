import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/local/preferences.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/models/subscription_plan_labels.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/speech_bubble.dart';
import 'widgets/payment_method_sheet.dart';

/// Side-by-side feature matrix that compares the public plans
/// (Free, Premium, Logoped) on a single page.
///
/// The screen is intentionally one wide horizontally-scrollable card
/// rather than three stacked plan cards (those already exist on
/// [SubscriptionScreen]). The comparison surface answers a different
/// question — "which features differ between tiers?" — and is the
/// fastest way for a parent to confirm that Premium is worth the
/// upgrade before tapping the CTA.
///
/// State handling matches the rest of the subscription stack:
///  * loading → shimmer matrix (no default `CircularProgressIndicator`).
///  * error → friendly mascot + retry.
///  * empty → mascot + "no plans yet" message (defensive, the API
///    always returns at least the free tier).
///  * success → hero, sticky plan-name header, grouped matrix rows,
///    primary CTA at the bottom.
class PlanComparisonScreen extends ConsumerWidget {
  const PlanComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context)!;
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final mySubAsync = ref.watch(mySubscriptionProvider);
    final locale = ref.watch(localeProvider).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.planCompareTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/subscription'),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: plansAsync.when(
          loading: () => const _ComparisonLoading(),
          error: (_, __) => ErrorState(
            title: l.planCompareErrorTitle,
            body: l.planCompareErrorBody,
            retryLabel: l.planCompareErrorRetry,
            onRetry: () => ref.invalidate(subscriptionPlansProvider),
          ),
          data: (plans) {
            final columns = _selectColumns(plans);
            if (columns.isEmpty) {
              return EmptyState(
                title: l.planCompareEmptyTitle,
                body: l.planCompareEmptyBody,
              );
            }
            final currentPlanId = mySubAsync.maybeWhen(
              data: (s) => SubscriptionPlanLabels.normalise(s.planId),
              orElse: () => SubscriptionPlanLabels.free,
            );
            return RefreshIndicator(
              key: const Key('planCompare.refresh'),
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(subscriptionPlansProvider);
                ref.invalidate(mySubscriptionProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.huge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(
                      title: l.planCompareTitle,
                      subtitle: l.planCompareSubtitle,
                      mascotMessage: l.planCompareMascotMessage,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _MatrixCard(
                      columns: columns,
                      currentPlanId: currentPlanId,
                      locale: locale,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _PrimaryCta(
                      columns: columns,
                      currentPlanId: currentPlanId,
                      locale: locale,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Pick at most three plans for the matrix: Free, Premium and the
  /// professional tier (Logoped if present, else the next paid plan).
  /// Anything outside this trio creates a column overflow on small
  /// phones — the SubscriptionScreen still surfaces the full catalog
  /// for users who want to see it.
  List<_PlanColumn> _selectColumns(List<SubscriptionPlan> plans) {
    SubscriptionPlan? findById(String id) {
      for (final p in plans) {
        if (SubscriptionPlanLabels.normalise(p.id) == id) return p;
      }
      return null;
    }

    final free = findById(SubscriptionPlanLabels.free);
    final pro = findById(SubscriptionPlanLabels.parentPro);
    final logoped = findById(SubscriptionPlanLabels.logopedPro) ??
        findById(SubscriptionPlanLabels.logoped);

    final out = <_PlanColumn>[];
    if (free != null) {
      out.add(_PlanColumn(plan: free, kind: _PlanKind.free));
    }
    if (pro != null) {
      out.add(_PlanColumn(plan: pro, kind: _PlanKind.pro));
    }
    if (logoped != null) {
      out.add(_PlanColumn(plan: logoped, kind: _PlanKind.logoped));
    }
    // Defensive fallback when the API only returned a single tier so
    // the screen never renders an empty matrix.
    if (out.isEmpty && plans.isNotEmpty) {
      out.add(_PlanColumn(plan: plans.first, kind: _PlanKind.free));
    }
    return out;
  }
}

enum _PlanKind { free, pro, logoped }

class _PlanColumn {
  const _PlanColumn({required this.plan, required this.kind});
  final SubscriptionPlan plan;
  final _PlanKind kind;
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.mascotMessage,
  });

  final String title;
  final String subtitle;
  final String mascotMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft(AppColors.primary, opacity: 0.22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ParrotMascot(mood: ParrotMood.happy, size: 88),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SpeechBubble(
                  text: mascotMessage,
                  color: Colors.white,
                  textColor: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06);
  }
}

class _MatrixCard extends StatelessWidget {
  const _MatrixCard({
    required this.columns,
    required this.currentPlanId,
    required this.locale,
  });

  final List<_PlanColumn> columns;
  final String currentPlanId;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final rows = _buildRows(l);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderRow(
              columns: columns,
              currentPlanId: currentPlanId,
              locale: locale,
            ),
            for (final section in rows) ...[
              _SectionLabel(text: section.label),
              for (var i = 0; i < section.rows.length; i++)
                _MatrixRow(
                  row: section.rows[i],
                  columns: columns,
                  isStripe: i.isOdd,
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<_Section> _buildRows(L l) {
    return [
      _Section(
        label: l.planCompareSectionUsage,
        rows: [
          _Row(
            label: l.planCompareRowExercises,
            cells: _usageCellsFor(
              l,
              perDay: (p) => p.limits.exercisesPerDay,
            ),
          ),
          _Row(
            label: l.planCompareRowAi,
            cells: _usageCellsFor(
              l,
              perMonth: (p) => p.limits.aiAnalysesPerMonth,
            ),
          ),
          _Row(
            label: l.planCompareRowChildren,
            cells: _usageCellsFor(
              l,
              count: (p) => p.limits.maxChildren,
            ),
          ),
          // Patient-count row only renders when at least one column
          // has the metric — saves a row of em-dashes for parent users.
          if (columns.any((c) => c.plan.limits.maxPatients != 0))
            _Row(
              label: l.planCompareRowPatients,
              cells: _usageCellsFor(
                l,
                count: (p) => p.limits.maxPatients,
              ),
            ),
        ],
      ),
      _Section(
        label: l.planCompareSectionFeatures,
        rows: [
          _Row(
            label: l.planCompareRowDetailedProgress,
            cells: _featureCells(l, 'detailed_progress', proIncluded: true),
          ),
          _Row(
            label: l.planCompareRowRecommendations,
            cells: _featureCells(l, 'recommendations', proIncluded: true),
          ),
          _Row(
            label: l.planCompareRowExportPdf,
            cells: _featureCells(l, 'export_pdf', proIncluded: true),
          ),
          _Row(
            label: l.planCompareRowPatientManagement,
            cells: _featureCells(l, 'patient_management', proIncluded: false),
          ),
          _Row(
            label: l.planCompareRowAssignExercises,
            cells: _featureCells(l, 'assign_exercises', proIncluded: false),
          ),
          _Row(
            label: l.planCompareRowTherapyGoals,
            cells: _featureCells(l, 'therapy_goals', proIncluded: false),
          ),
          _Row(
            label: l.planCompareRowScreeningBattery,
            cells: _featureCells(l, 'screening_battery', proIncluded: false),
          ),
          _Row(
            label: l.planCompareRowReferralPdf,
            cells: _featureCells(l, 'referral_pdf', proIncluded: false),
          ),
          _Row(
            label: l.planCompareRowAnalytics,
            cells: _featureCells(l, 'analytics', proIncluded: false),
          ),
        ],
      ),
      _Section(
        label: l.planCompareSectionSupport,
        rows: [
          _Row(
            label: l.planCompareRowPrioritySupport,
            cells: [
              for (final c in columns)
                _supportCellFor(l, c.kind),
            ],
          ),
        ],
      ),
    ];
  }

  /// Build the limit-style cell for a row given any of the three
  /// dimension extractors. Exactly one extractor should be supplied.
  List<_Cell> _usageCellsFor(
    L l, {
    int Function(SubscriptionPlan)? perDay,
    int Function(SubscriptionPlan)? perMonth,
    int Function(SubscriptionPlan)? count,
  }) {
    return [
      for (final c in columns)
        _limitCell(
          l,
          extract: perDay ?? perMonth ?? count!,
          unit: perDay != null
              ? _LimitUnit.perDay
              : perMonth != null
                  ? _LimitUnit.perMonth
                  : _LimitUnit.count,
          column: c,
        ),
    ];
  }

  _Cell _limitCell(
    L l, {
    required int Function(SubscriptionPlan) extract,
    required _LimitUnit unit,
    required _PlanColumn column,
  }) {
    final v = extract(column.plan);
    if (v < 0) {
      return _Cell.text(l.planCompareCellUnlimited, kind: _CellKind.unlimited);
    }
    if (v == 0) {
      return _Cell.text(l.planCompareCellExcluded, kind: _CellKind.excluded);
    }
    final label = switch (unit) {
      _LimitUnit.perDay => l.planCompareCellPerDay(v),
      _LimitUnit.perMonth => l.planCompareCellPerMonth(v),
      _LimitUnit.count => l.planCompareCellCount(v),
    };
    return _Cell.text(label, kind: _CellKind.value);
  }

  /// Resolve a feature cell. The first preference is the actual
  /// `features` list shipped with the plan (so the API stays
  /// authoritative). When the catalogue doesn't include the feature
  /// flag we fall back to the design intent encoded in [proIncluded] —
  /// the matrix is documentation as much as configuration, and during
  /// the billing rollout the API may not have the full feature list
  /// wired up yet.
  List<_Cell> _featureCells(
    L l,
    String feature, {
    required bool proIncluded,
  }) {
    return [
      for (final column in columns) _featureCellFor(l, feature, column, proIncluded),
    ];
  }

  _Cell _featureCellFor(
    L l,
    String feature,
    _PlanColumn column,
    bool proIncluded,
  ) {
    final hasFlag = column.plan.features.contains(feature);
    if (hasFlag) {
      return _Cell.icon(
        kind: _CellKind.included,
        label: l.planCompareCellIncluded,
      );
    }
    final shouldHave = switch (column.kind) {
      _PlanKind.free => false,
      _PlanKind.pro => proIncluded,
      _PlanKind.logoped => true,
    };
    if (shouldHave) {
      return _Cell.icon(
        kind: _CellKind.included,
        label: l.planCompareCellIncluded,
      );
    }
    return _Cell.icon(
      kind: _CellKind.excluded,
      label: l.planCompareCellExcluded,
    );
  }

  _Cell _supportCellFor(L l, _PlanKind kind) {
    return switch (kind) {
      _PlanKind.free => _Cell.text(
          l.planCompareCellEmail,
          kind: _CellKind.value,
        ),
      _PlanKind.pro => _Cell.text(
          l.planCompareCellPriority,
          kind: _CellKind.included,
        ),
      _PlanKind.logoped => _Cell.text(
          l.planCompareCellPriority,
          kind: _CellKind.included,
        ),
    };
  }
}

enum _LimitUnit { perDay, perMonth, count }

enum _CellKind { included, excluded, unlimited, value }

class _Cell {
  const _Cell({
    required this.label,
    required this.kind,
    required this.isIcon,
  });

  factory _Cell.text(String label, {required _CellKind kind}) =>
      _Cell(label: label, kind: kind, isIcon: false);

  factory _Cell.icon({required _CellKind kind, required String label}) =>
      _Cell(label: label, kind: kind, isIcon: true);

  final String label;
  final _CellKind kind;
  final bool isIcon;
}

class _Section {
  const _Section({required this.label, required this.rows});
  final String label;
  final List<_Row> rows;
}

class _Row {
  const _Row({required this.label, required this.cells});
  final String label;
  final List<_Cell> cells;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.currentPlanId,
    required this.locale,
  });

  final List<_PlanColumn> columns;
  final String currentPlanId;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 110),
          for (final c in columns)
            Expanded(
              child: _PlanHeaderCell(
                column: c,
                isCurrent: SubscriptionPlanLabels.normalise(c.plan.id) ==
                    currentPlanId,
                isRecommended: c.kind == _PlanKind.pro,
                locale: locale,
                currentBadge: l.planCompareCurrentBadge,
                recommendedBadge: l.planCompareRecommendedBadge,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanHeaderCell extends StatelessWidget {
  const _PlanHeaderCell({
    required this.column,
    required this.isCurrent,
    required this.isRecommended,
    required this.locale,
    required this.currentBadge,
    required this.recommendedBadge,
  });

  final _PlanColumn column;
  final bool isCurrent;
  final bool isRecommended;
  final String locale;
  final String currentBadge;
  final String recommendedBadge;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final name = SubscriptionPlanLabels.nameForPlan(l, column.plan, locale);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          if (isCurrent)
            _Pill(
              label: currentBadge,
              fill: Colors.white,
              text: AppColors.primaryDark,
            )
          else if (isRecommended)
            _Pill(
              label: recommendedBadge,
              fill: AppColors.accent,
              text: AppColors.textPrimary,
            )
          else
            const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.fill,
    required this.text,
  });

  final String label;
  final Color fill;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MatrixRow extends StatelessWidget {
  const _MatrixRow({
    required this.row,
    required this.columns,
    required this.isStripe,
  });

  final _Row row;
  final List<_PlanColumn> columns;
  final bool isStripe;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

    // Build a screen-reader label that captures the whole row in a
    // single utterance — easier than focusing each cell separately.
    final freeLabel = _safeLabel(0);
    final proLabel = _safeLabel(1);
    final logopedLabel = _safeLabel(2);
    final semantics = l.planCompareSemanticsRow(
      row.label,
      freeLabel,
      proLabel,
      logopedLabel,
    );

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        color: isStripe ? AppColors.background : AppColors.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                row.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            for (var i = 0; i < columns.length; i++)
              Expanded(
                child: Center(
                  child: _CellWidget(
                    cell: i < row.cells.length ? row.cells[i] : _Cell.text('—', kind: _CellKind.excluded),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _safeLabel(int idx) =>
      idx < row.cells.length ? row.cells[idx].label : '—';
}

class _CellWidget extends StatelessWidget {
  const _CellWidget({required this.cell});
  final _Cell cell;

  @override
  Widget build(BuildContext context) {
    if (cell.isIcon) {
      switch (cell.kind) {
        case _CellKind.included:
          return Icon(
            Icons.check_circle_rounded,
            size: 22,
            color: AppColors.primary,
            semanticLabel: cell.label,
          );
        case _CellKind.excluded:
          return Icon(
            Icons.cancel_outlined,
            size: 22,
            color: AppColors.textMuted,
            semanticLabel: cell.label,
          );
        case _CellKind.unlimited:
        case _CellKind.value:
          break;
      }
    }
    final colour = switch (cell.kind) {
      _CellKind.unlimited => AppColors.primaryDark,
      _CellKind.included => AppColors.primaryDark,
      _CellKind.excluded => AppColors.textMuted,
      _CellKind.value => AppColors.textPrimary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        cell.label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colour,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.columns,
    required this.currentPlanId,
    required this.locale,
  });

  final List<_PlanColumn> columns;
  final String currentPlanId;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;

    final pro = columns.firstWhere(
      (c) => c.kind == _PlanKind.pro,
      orElse: () => columns.first,
    );

    final isCurrent =
        SubscriptionPlanLabels.normalise(pro.plan.id) == currentPlanId;
    final label = isCurrent
        ? l.planCompareCtaCurrent
        : (pro.kind == _PlanKind.logoped
            ? l.planCompareCtaContact
            : l.planCompareCtaUpgrade);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        key: const Key('planCompare.primaryCta'),
        onPressed: isCurrent
            ? null
            : () => _onTap(context, l, pro),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, L l, _PlanColumn column) async {
    if (column.kind == _PlanKind.logoped) {
      // B2B/B2B2C tiers don't have a self-serve checkout yet — route
      // back to the catalog where the existing "coming soon" sheet is
      // already wired in.
      context.go('/subscription');
      return;
    }
    final name =
        SubscriptionPlanLabels.nameForPlan(l, column.plan, locale);
    await PaymentMethodSheet.show(
      context,
      plan: column.plan,
      planDisplayName: name,
    );
  }
}

class _ComparisonLoading extends StatelessWidget {
  const _ComparisonLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: [
        const ShimmerBox(height: 96, radius: AppRadius.xl),
        const SizedBox(height: AppSpacing.lg),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadow.card,
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              ShimmerBox(height: 18, width: 120),
              SizedBox(height: AppSpacing.md),
              ShimmerBox(height: 14),
              SizedBox(height: AppSpacing.sm),
              ShimmerBox(height: 14),
              SizedBox(height: AppSpacing.sm),
              ShimmerBox(height: 14),
              SizedBox(height: AppSpacing.sm),
              ShimmerBox(height: 14),
              SizedBox(height: AppSpacing.sm),
              ShimmerBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }
}
