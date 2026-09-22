import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../shared/permissions/workstation.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../auth/session_notifier.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  final String? userId;
  const UserFormScreen({super.key, this.userId});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  UserRole _role = UserRole.vendeur;
  bool _active = true;
  bool _loaded = false;
  bool _sendingReset = false;
  Set<Workstation> _departments = {};

  bool get _isEdit => widget.userId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final user = ref.read(authRepositoryProvider).byId(widget.userId!);
      if (user != null) {
        _nameCtrl.text = user.name;
        _emailCtrl.text = user.email;
        _phoneCtrl.text = user.phone ?? '';
        _role = user.role;
        _active = user.active;
        _departments = user.departments.toSet();
      }
    }
    _loaded = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isEdit) {
        final user = repo.byId(widget.userId!)!;
        await repo.updateUser(
          user,
          name: _nameCtrl.text,
          phone: _phoneCtrl.text,
          role: _role,
          active: _active,
          departments: _role.isDepartmentAssignable ? _departments.toList() : const [],
        );
      } else {
        await repo.createUser(
          email: _emailCtrl.text,
          name: _nameCtrl.text,
          role: _role,
          phone: _phoneCtrl.text,
          password: _passwordCtrl.text,
          active: _active,
          departments: _role.isDepartmentAssignable ? _departments.toList() : const [],
        );
      }
      ref.read(dataRevisionProvider.notifier).state++;
      final actor = ref.read(sessionProvider)!.user;
      await ref
          .read(auditServiceProvider)
          .log(actor, _isEdit ? 'Utilisateur modifié' : 'Utilisateur créé', details: _emailCtrl.text);
      if (mounted) {
        ToastService.success(_isEdit ? 'Utilisateur mis à jour' : 'Utilisateur créé');
        context.pop();
      }
    } catch (e) {
      ToastService.error(e.toString());
    }
  }

  Future<void> _sendPasswordReset() async {
    setState(() => _sendingReset = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_emailCtrl.text);
      if (mounted) ToastService.success('Email de réinitialisation envoyé à ${_emailCtrl.text}');
    } catch (e) {
      ToastService.error(e.toString());
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final effectiveDepartments = _role.isDepartmentAssignable && _departments.isNotEmpty
        ? _departments
        : {_role.workstation};
    final primary = kDepartmentOrder.firstWhere(
      effectiveDepartments.contains,
      orElse: () => _role.workstation,
    );

    return AppShell(
      title: _isEdit ? "Modifier l'utilisateur" : 'Nouvel utilisateur',
      actions: [
        if (_isEdit)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: "Supprimer l'utilisateur",
                message: 'Cette action est irréversible.',
                danger: true,
              );
              if (ok) {
                await ref.read(authRepositoryProvider).deleteUser(widget.userId!);
                ref.read(dataRevisionProvider.notifier).state++;
                if (context.mounted) context.pop();
              }
            },
          ),
      ],
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom complet'),
                    validator: (v) => Validators.required(v, field: 'Le nom'),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email (identifiant de connexion)'),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isEdit,
                    validator: Validators.requiredEmail,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Rôle'),
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _role = v ?? _role),
                  ),
                  if (_role.isDepartmentAssignable) ...[
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      'Départements (facultatif — laisser vide pour garder le poste par défaut du rôle)',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: AppSizes.xs,
                      children: kAssignableDepartments
                          .map((d) => FilterChip(
                                avatar: Icon(d.icon, size: 16, color: d.color),
                                label: Text(d.label),
                                selected: _departments.contains(d),
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _departments.add(d);
                                  } else {
                                    _departments.remove(d);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: AppSizes.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: primary.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(primary.icon, color: primary.color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cet utilisateur aura accès au${effectiveDepartments.length > 1 ? 'x postes' : ' poste'} : '
                          '${effectiveDepartments.map((w) => w.label).join(', ')}',
                          style: TextStyle(color: primary.color, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  if (_isEdit) ...[
                    OutlinedButton.icon(
                      onPressed: _sendingReset ? null : _sendPasswordReset,
                      icon: _sendingReset
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.lock_reset),
                      label: Text(
                        _sendingReset ? 'Envoi en cours...' : 'Envoyer un lien de réinitialisation du mot de passe',
                      ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: const InputDecoration(labelText: 'Mot de passe'),
                      obscureText: true,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                      obscureText: true,
                      validator: (v) => Validators.confirmPassword(v, _passwordCtrl.text),
                    ),
                  ],
                  const SizedBox(height: AppSizes.sm),
                  SwitchListTile(
                    title: const Text('Compte actif'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSizes.md),
                  FilledButton(onPressed: _save, child: Text(_isEdit ? 'Enregistrer' : "Créer l'utilisateur")),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
