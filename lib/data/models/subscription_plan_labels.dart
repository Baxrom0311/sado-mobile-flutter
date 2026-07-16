// Centralised resolver for "what should we call this plan in the UI?"
//
// The API has shipped under a couple of slug variants during the
// billing rollout (`logoped` vs `logoped_pro`, `clinic` vs
// `clinic_basic`, `clinic_premium`). Mobile screens used to fork on
// these strings with hardcoded English literals — that violated the
// "no hardcoded user-facing strings" rule and meant new plan codes
// silently rendered as raw slugs.
//
// This module funnels every plan-name / tagline lookup through a
// single helper backed by ARB strings so:
//
//  * Both Uzbek and Russian users see localised plan names.
//  * Adding a new plan code is a one-place edit.
//  * Tests can rely on a stable contract for "given code X, you get
//    string Y in locale Z".
//
// Plan codes are tolerated case-insensitively and unknown codes fall
// back to a humanised version of the slug (or the explicit
// `nameUz` / `nameRu` shipped with `SubscriptionPlan` when one is
// passed in).

import 'package:flutter/widgets.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import 'subscription_plan.dart';

/// Canonical plan-code helpers + localised label lookups.
///
/// Use [name] / [tagline] when you only have a slug (e.g. inside a
/// payment-history row that knows nothing about the plan catalogue).
/// Use [nameForPlan] / [taglineForPlan] when you do have a hydrated
/// [SubscriptionPlan] — those variants prefer the API-provided
/// `name_uz` / `name_ru` over the static fallback so a custom plan
/// name from the server still wins.
class SubscriptionPlanLabels {
  const SubscriptionPlanLabels._();

  // ---- canonical slugs ----------------------------------------------------

  static const String free = 'free';
  static const String parentPro = 'parent_pro';

  // The API renamed `logoped` → `logoped_pro` mid-rollout. We accept
  // both as aliases so a payment row created against the old name
  // still resolves cleanly.
  static const String logoped = 'logoped';
  static const String logopedPro = 'logoped_pro';

  // Same story for `clinic` (formerly `clinic_basic`).
  static const String clinic = 'clinic';
  static const String clinicBasic = 'clinic_basic';
  static const String clinicPremium = 'clinic_premium';

  /// Every code we know about. Anything outside this set falls back
  /// to the humanised-slug branch in [name] / [tagline].
  static const Set<String> known = <String>{
    free,
    parentPro,
    logoped,
    logopedPro,
    clinic,
    clinicBasic,
    clinicPremium,
  };

  /// Normalise a wire slug (`Logoped`, `LOGOPED_PRO `, …) for
  /// switching. Empty / null → empty string so `unknown` branch fires.
  static String normalise(String? raw) {
    if (raw == null) return '';
    return raw.trim().toLowerCase();
  }

  /// Localised plan name for a slug.
  ///
  /// Returns the ARB-backed string for known codes, falls back to a
  /// humanised version of the slug for unknown codes, and to the
  /// generic "Reja" / "План" placeholder when we get nothing at all.
  static String name(L l, String? code) {
    final c = normalise(code);
    return switch (c) {
      free => l.subscriptionFreeName,
      parentPro => l.subscriptionProName,
      logoped || logopedPro => l.subscriptionLogopedName,
      clinic || clinicBasic => l.subscriptionClinicName,
      clinicPremium => l.subscriptionClinicPremiumName,
      _ => _humanise(c, fallback: l.subscriptionUnknownPlanName),
    };
  }

  /// Localised tagline for a slug. Returns an empty string for
  /// unknown codes (the UI hides the tagline row when empty).
  static String tagline(L l, String? code) {
    final c = normalise(code);
    return switch (c) {
      free => l.subscriptionFreeTagline,
      parentPro => l.subscriptionProTagline,
      logoped || logopedPro => l.subscriptionLogopedTagline,
      clinic || clinicBasic => l.subscriptionClinicTagline,
      clinicPremium => l.subscriptionClinicPremiumTagline,
      _ => '',
    };
  }

  /// Resolve the localised name for a hydrated [SubscriptionPlan],
  /// preferring an API-provided locale-specific name when it differs
  /// from the canonical fallback.
  static String nameForPlan(L l, SubscriptionPlan plan, String locale) {
    final canonical = name(l, plan.id);
    final apiName = plan.name(locale);
    if (apiName.isNotEmpty &&
        apiName != plan.id &&
        apiName.toLowerCase() != normalise(plan.id)) {
      return apiName;
    }
    return canonical;
  }

  /// Same as [tagline] but prefers the API-provided description
  /// when the plan ships one.
  static String taglineForPlan(L l, SubscriptionPlan plan, String locale) {
    final desc = plan.description(locale);
    if (desc != null && desc.trim().isNotEmpty) return desc;
    return tagline(l, plan.id);
  }

  /// Build a humanised name from an unknown slug — `parent_pro`
  /// becomes `Parent Pro`. Falls back to [fallback] for empty input.
  static String _humanise(String slug, {required String fallback}) {
    if (slug.isEmpty) return fallback;
    final parts = slug
        .split(RegExp(r'[_\s-]+'))
        .where((p) => p.isNotEmpty)
        .map(_titleCase);
    final humanised = parts.join(' ');
    return humanised.isEmpty ? fallback : humanised;
  }

  static String _titleCase(String word) {
    if (word.length <= 1) return word.toUpperCase();
    return word[0].toUpperCase() + word.substring(1);
  }
}

/// Convenience extension for screens that already have a
/// [BuildContext] and a slug. Keeps the call site terse without
/// pulling in a separate import.
extension SubscriptionPlanLabelContext on BuildContext {
  String subscriptionPlanName(String? code) {
    final l = L.of(this);
    if (l == null) return code ?? '';
    return SubscriptionPlanLabels.name(l, code);
  }

  String subscriptionPlanTagline(String? code) {
    final l = L.of(this);
    if (l == null) return '';
    return SubscriptionPlanLabels.tagline(l, code);
  }
}
