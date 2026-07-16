import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/parrot_mascot.dart';
import '../../widgets/premium_button.dart';

/// Available registration roles. Backend currently supports 'parent' and
/// 'teacher'. Admin is provisioned out-of-band.
enum RegisterRole { parent, teacher }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _termsAccepted = false;
  bool _termsTouched = false;
  RegisterRole _role = RegisterRole.parent;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _termsTouched = true);
    if (!formOk || !_termsAccepted) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).register(
          _email.text.trim(),
          _password.text,
          _name.text.trim(),
          role: _role.name,
        );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final auth = ref.watch(authProvider);
    final errorText = auth.error == 'network'
        ? l.networkError
        : auth.error == 'auth'
            ? l.error
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.register),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
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
                const ParrotMascot(mood: ParrotMood.talking, size: 120)
                    .animate()
                    .fadeIn(duration: 350.ms),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.registerWelcome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Role selector — toggle cards.
                Text(
                  l.registerRoleQuestion,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _RoleSelector(
                  value: _role,
                  onChanged: (r) => setState(() => _role = r),
                ),

                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  key: const ValueKey('register-name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.fullName,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) =>
                      v != null && v.trim().length >= 2 ? null : l.nameRequired,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: const ValueKey('register-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.email,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (v) =>
                      v != null && v.contains('@') ? null : l.emailInvalid,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: const ValueKey('register-password'),
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l.password,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      v != null && v.length >= 6 ? null : l.passwordMinLength,
                ),

                const SizedBox(height: AppSpacing.lg),

                _TermsCheckbox(
                  value: _termsAccepted,
                  showError: _termsTouched && !_termsAccepted,
                  onChanged: (v) =>
                      setState(() => _termsAccepted = v ?? false),
                  label: l.termsAccept,
                  errorText: l.termsRequired,
                ),

                if (errorText != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                PremiumButton(
                  label: l.registerButton,
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _loading ? null : _submit,
                  loading: _loading,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l.hasAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-up role toggle. Animates the selection ring and gradient on the
/// active card, mirroring the gender selector used in the add-child flow.
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.value, required this.onChanged});

  final RegisterRole value;
  final ValueChanged<RegisterRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            key: const ValueKey('role-parent'),
            selected: value == RegisterRole.parent,
            icon: Icons.family_restroom_rounded,
            tint: AppColors.primary,
            title: l.roleParent,
            subtitle: l.roleParentHint,
            onTap: () => onChanged(RegisterRole.parent),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _RoleCard(
            key: const ValueKey('role-teacher'),
            selected: value == RegisterRole.teacher,
            icon: Icons.school_rounded,
            tint: AppColors.tertiary,
            title: l.roleTeacher,
            subtitle: l.roleTeacherHint,
            onTap: () => onChanged(RegisterRole.teacher),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.selected,
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeShadow = AppShadow.soft(tint);
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? tint : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: selected ? activeShadow : AppShadow.card,
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : tint,
                  size: 24,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.showError,
    required this.label,
    required this.errorText,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool showError;
  final String label;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    final activeColor = showError ? AppColors.danger : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  key: const ValueKey('register-terms'),
                  value: value,
                  onChanged: onChanged,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeColor: activeColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: showError
                          ? AppColors.danger
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text(
              errorText,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
