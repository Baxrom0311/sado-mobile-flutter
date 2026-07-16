import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import '../../data/api/children_api.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/loaders.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import 'widgets/kindergarten_picker_sheet.dart';

/// Edit-an-existing-child screen.
///
/// Pre-fills the form with the child's current name / birth date / gender /
/// kindergarten, then sends a PATCH to update only the fields that actually
/// changed. Reuses the same gender tile + date field design as
/// [AddChildScreen] for consistency.
class EditChildScreen extends ConsumerStatefulWidget {
  const EditChildScreen({super.key, required this.childId});
  final String childId;

  @override
  ConsumerState<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends ConsumerState<EditChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'male';
  // The picked / pre-filled kindergarten. Not knowing the original name yet
  // (the child record only has the id) is fine — the picker hydrates this
  // when the user opens it. The id we send back to the API still uses the
  // original value until the user actually changes it.
  Kindergarten? _kindergarten;
  String? _originalKindergartenId;
  bool _kindergartenChanged = false;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _hydrate(Child child) {
    if (_initialized) return;
    _initialized = true;
    _name.text = child.name;
    _birthDate = child.birthDate;
    _gender = child.gender == 'female' ? 'female' : 'male';
    _originalKindergartenId = child.kindergartenId;
  }

  Future<void> _pickDate() async {
    final initial = _birthDate ??
        DateTime.now().subtract(const Duration(days: 365 * 4));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _birthDate = date);
  }

  Future<void> _pickKindergarten() async {
    final result = await showKindergartenPickerSheet(
      context: context,
      selectedId: _kindergarten?.id ?? _originalKindergartenId,
    );
    if (result == null || !mounted) return;
    setState(() {
      _kindergartenChanged = true;
      _kindergarten = result.isCleared ? null : result.kindergarten;
    });
  }

  Future<void> _save(Child original) async {
    if (!_formKey.currentState!.validate() || _birthDate == null) return;
    setState(() => _saving = true);

    final api = ChildrenApi(ref.read(dioProvider));
    final newName = _name.text.trim();
    final newBirth = _birthDate!.toIso8601String().split('T').first;

    try {
      await api.patch(
        original.id,
        name: newName != original.name ? newName : null,
        birthDate: original.birthDate
                    .toIso8601String()
                    .split('T')
                    .first !=
                newBirth
            ? newBirth
            : null,
        gender: _gender != original.gender ? _gender : null,
        kindergartenId: _kindergartenChanged ? _kindergarten?.id : null,
      );
      ref.invalidate(childrenProvider);
      if (!mounted) return;
      final l = L.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.childUpdated)),
      );
      context.go('/children/${original.id}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context)!.networkError)),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final children = ref.watch(childrenProvider);

    return children.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l.editChildTitle)),
        body: MascotLoader(message: l.loadingChild),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: Text(l.editChildTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ParrotMascot(mood: ParrotMood.sad, size: 120),
              const SizedBox(height: AppSpacing.lg),
              Text(l.errorTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        ),
      ),
      data: (res) {
        Child? child;
        for (final c in res.items) {
          if (c.id == widget.childId) {
            child = c;
            break;
          }
        }
        if (child == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l.editChildTitle),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/children'),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ParrotMascot(mood: ParrotMood.sad, size: 120),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l.errorTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ),
          );
        }

        _hydrate(child);
        // Effective kindergarten value to display: the freshly-picked one if
        // the user changed it, otherwise the original (id only — the picker
        // shows full info next to it).
        final effectiveKindergarten = _kindergartenChanged
            ? _kindergarten
            : _kindergarten ??
                (_originalKindergartenId != null
                    ? Kindergarten(
                        id: _originalKindergartenId!,
                        name: _originalKindergartenId!,
                      )
                    : null);
        return _Form(
          original: child,
          formKey: _formKey,
          name: _name,
          birthDate: _birthDate,
          gender: _gender,
          kindergarten: effectiveKindergarten,
          showKindergartenIdAsName: !_kindergartenChanged &&
              _kindergarten == null &&
              _originalKindergartenId != null,
          saving: _saving,
          onPickDate: _pickDate,
          onGender: (g) => setState(() => _gender = g),
          onPickKindergarten: _pickKindergarten,
          onSave: () => _save(child!),
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.original,
    required this.formKey,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.kindergarten,
    required this.showKindergartenIdAsName,
    required this.saving,
    required this.onPickDate,
    required this.onGender,
    required this.onPickKindergarten,
    required this.onSave,
  });

  final Child original;
  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final DateTime? birthDate;
  final String gender;
  final Kindergarten? kindergarten;
  /// True when we know there's an attached kindergarten but only have its id
  /// (the user hasn't opened the picker yet). Shows an "Attached" placeholder
  /// instead of the raw id.
  final bool showKindergartenIdAsName;
  final bool saving;
  final VoidCallback onPickDate;
  final ValueChanged<String> onGender;
  final VoidCallback onPickKindergarten;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final isMale = gender == 'male';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.editChildTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/children/${original.id}'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ParrotMascot(
                    mood: ParrotMood.happy,
                    size: 110,
                    message: original.name,
                  ),
                ).animate().fadeIn(duration: 280.ms),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.childName,
                    prefixIcon: const Icon(Icons.child_care_rounded),
                  ),
                  validator: (v) => v != null && v.trim().length >= 2
                      ? null
                      : l.nameRequired,
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: onPickDate,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_rounded,
                            color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            birthDate != null
                                ? '${birthDate!.day.toString().padLeft(2, '0')}.${birthDate!.month.toString().padLeft(2, '0')}.${birthDate!.year}'
                                : l.birthDate,
                            style: TextStyle(
                              color: birthDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.calendar_today_rounded,
                            size: 18,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l.gender,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    )),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _GenderTile(
                        selected: isMale,
                        color: AppColors.sky,
                        icon: Icons.face_6_rounded,
                        label: l.male,
                        onTap: () => onGender('male'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _GenderTile(
                        selected: !isMale,
                        color: AppColors.pink,
                        icon: Icons.face_3_rounded,
                        label: l.female,
                        onTap: () => onGender('female'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _KindergartenField(
                  selected: kindergarten,
                  showIdAsName: showKindergartenIdAsName,
                  onTap: onPickKindergarten,
                ),
                const SizedBox(height: AppSpacing.xxl),
                PremiumButton(
                  label: l.save,
                  icon: Icons.check_rounded,
                  onPressed: saving ? null : onSave,
                  loading: saving,
                ),
                const SizedBox(height: AppSpacing.md),
                PremiumOutlineButton(
                  label: l.cancel,
                  icon: Icons.close_rounded,
                  onPressed: saving
                      ? null
                      : () => context.go('/children/${original.id}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderTile extends StatelessWidget {
  const _GenderTile({
    required this.selected,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow:
              selected ? AppShadow.soft(color, opacity: 0.18) : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 36,
                color: selected ? color : AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindergartenField extends StatelessWidget {
  const _KindergartenField({
    required this.selected,
    required this.showIdAsName,
    required this.onTap,
  });

  final Kindergarten? selected;
  final bool showIdAsName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final hasValue = selected != null;
    final color = AppColors.tertiary;
    // When we only know the id (haven't fetched the name) show a neutral
    // "attached" message instead of the raw id, but keep the styling that
    // signals "a kindergarten is set".
    final displayName = hasValue
        ? (showIdAsName ? l.kindergarten : selected!.name)
        : l.kindergartenNotSet;

    return InkWell(
      key: const ValueKey('editChild.kindergartenField'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasValue ? color.withValues(alpha: 0.4) : Colors.transparent,
            width: hasValue ? 1.5 : 0,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.school_rounded,
                color: hasValue ? color : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.kindergartenOptional,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
