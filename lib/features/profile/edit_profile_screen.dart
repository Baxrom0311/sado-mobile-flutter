import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/local/preferences.dart';
import '../../providers/providers.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_card.dart';

/// Premium profile editor — lets the parent update their display name and
/// preferred app language. Designed to feel reassuring (mascot, breathing
/// animations) rather than form-y.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _initialName;
  late String _initialLang;
  String? _selectedLang;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _initialName = user?.fullName ?? '';
    _initialLang = ref.read(localeProvider).languageCode;
    _name = TextEditingController(text: _initialName);
    _selectedLang = _initialLang;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final nameChanged = _name.text.trim() != _initialName.trim();
    final langChanged = (_selectedLang ?? _initialLang) != _initialLang;
    return nameChanged || langChanged;
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final l = L.of(context)!;
    final stay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.unsavedChangesTitle),
        content: Text(l.unsavedChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.stay),
          ),
        ],
      ),
    );
    return stay == true;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return;

    // Capture context-bound objects synchronously so we can safely use them
    // across awaits without re-touching `context` afterwards.
    final l = L.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() => _saving = true);
    final newName = _name.text.trim();
    final newLang = _selectedLang ?? _initialLang;

    try {
      // Apply the locale change immediately so the next frame is in the
      // user's chosen language even if the API call fails.
      if (newLang != _initialLang) {
        await ref
            .read(localeProvider.notifier)
            .setLocale(Locale(newLang));
      }

      await ref.read(authProvider.notifier).updateProfile(
            fullName: newName != _initialName ? newName : null,
            language: newLang != _initialLang ? newLang : null,
          );

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.profileUpdated)));
      router.go('/profile');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.profileSaveError)));
    }
  }

  /// Confirm + navigate back to /profile, capturing the router synchronously
  /// to avoid using `BuildContext` after the awaited dialog.
  Future<void> _confirmAndExit() async {
    final router = GoRouter.of(context);
    if (await _confirmDiscard()) {
      if (!mounted) return;
      router.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final user = ref.watch(authProvider).user;
    final initial = (user?.fullName.isNotEmpty == true)
        ? user!.fullName[0].toUpperCase()
        : '?';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmAndExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(l.editProfile),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _confirmAndExit,
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Hero card with avatar + tagline.
                PremiumCard(
                  gradient: AppColors.heroGradient,
                  shadowColor: AppColors.primary,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: AppShadow.card,
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.editProfileTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.editProfileSubtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 320.ms).slideY(begin: -0.05),

                const SizedBox(height: AppSpacing.lg),

                // Name field card.
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_rounded,
                              color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l.fullNameField,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: l.fullName,
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return l.fieldRequired;
                          if (value.length < 2) return l.nameMinLength;
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.05),

                const SizedBox(height: AppSpacing.lg),

                // Language selector card.
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language_rounded,
                              color: AppColors.tertiary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l.languagePreference,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _LangCard(
                              flag: '🇺🇿',
                              label: l.uzbek,
                              selected: _selectedLang == 'uz',
                              onTap: () =>
                                  setState(() => _selectedLang = 'uz'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _LangCard(
                              flag: '🇷🇺',
                              label: l.russian,
                              selected: _selectedLang == 'ru',
                              onTap: () =>
                                  setState(() => _selectedLang = 'ru'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate(delay: 140.ms).fadeIn().slideY(begin: 0.05),

                const SizedBox(height: AppSpacing.xl),

                // Action buttons.
                PremiumButton(
                  label: l.saveChanges,
                  icon: Icons.check_rounded,
                  onPressed: _isDirty && !_saving ? _save : null,
                  loading: _saving,
                ),
                const SizedBox(height: AppSpacing.md),
                PremiumButton(
                  label: l.cancel,
                  icon: Icons.close_rounded,
                  color: AppColors.surfaceMuted,
                  foreground: AppColors.textPrimary,
                  onPressed: _saving ? null : _confirmAndExit,
                ),

                const SizedBox(height: AppSpacing.xl),

                // Mascot footer.
                Center(
                  child: Column(
                    children: [
                      const ParrotMascot(
                          mood: ParrotMood.happy, size: 96),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l.mascotEncourage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  const _LangCard({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color:
                    selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
