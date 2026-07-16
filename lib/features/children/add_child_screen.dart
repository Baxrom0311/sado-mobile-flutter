import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import '../../data/api/children_api.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';
import 'widgets/kindergarten_picker_sheet.dart';

class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'male';
  Kindergarten? _kindergarten;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 4)),
      firstDate: DateTime(2015),
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
      selectedId: _kindergarten?.id,
    );
    if (result == null || !mounted) return;
    setState(() {
      _kindergarten = result.isCleared ? null : result.kindergarten;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _birthDate == null) return;
    setState(() => _loading = true);

    try {
      final api = ChildrenApi(ref.read(dioProvider));
      await api.create(
        name: _name.text.trim(),
        birthDate: _birthDate!.toIso8601String().split('T').first,
        gender: _gender,
        kindergartenId: _kindergarten?.id,
      );
      ref.invalidate(childrenProvider);
      if (mounted) context.go('/children');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context)!.error)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final isMale = _gender == 'male';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.addChild),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/children'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: ParrotMascot(mood: ParrotMood.happy, size: 110),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.childName,
                    prefixIcon:
                        const Icon(Icons.child_care_rounded),
                  ),
                  validator: (v) =>
                      v != null && v.length >= 2 ? null : l.nameRequired,
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: _pickDate,
                  child: Container(
                    padding:
                        const EdgeInsets.all(AppSpacing.lg),
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
                            _birthDate != null
                                ? '${_birthDate!.day.toString().padLeft(2, '0')}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.year}'
                                : l.birthDate,
                            style: TextStyle(
                              color: _birthDate != null
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
                        onTap: () =>
                            setState(() => _gender = 'male'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _GenderTile(
                        selected: !isMale,
                        color: AppColors.pink,
                        icon: Icons.face_3_rounded,
                        label: l.female,
                        onTap: () =>
                            setState(() => _gender = 'female'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _KindergartenField(
                  selected: _kindergarten,
                  onTap: _pickKindergarten,
                ),
                const SizedBox(height: AppSpacing.xxl),
                PremiumButton(
                  label: l.save,
                  icon: Icons.check_rounded,
                  onPressed: _loading ? null : _submit,
                  loading: _loading,
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
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppShadow.soft(color, opacity: 0.18) : null,
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

/// Tappable row that surfaces the currently-attached kindergarten (or a
/// "(optional)" hint when nothing is selected). Tapping opens the
/// searchable [KindergartenPickerSheet].
///
/// Lives on its own so the Add and Edit child screens can share an
/// identical look and accessibility surface.
class _KindergartenField extends StatelessWidget {
  const _KindergartenField({
    required this.selected,
    required this.onTap,
  });

  final Kindergarten? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final hasValue = selected != null;
    final color = AppColors.tertiary;

    return InkWell(
      key: const ValueKey('addChild.kindergartenField'),
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
                    hasValue ? selected!.name : l.kindergartenNotSet,
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
