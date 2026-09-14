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
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  UserRole _role = UserRole.vendeur;
  bool _active = true;
  bool _loaded = false;

  bool get _isEdit => widget.userId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final user = ref.read(authRepositoryProvider).byId(widget.userId!);
      if (user != null) {
        _nameCtrl.text = user.name;
        _usernameCtrl.text = user.username;
        _phoneCtrl.text = user.phone ?? '';
        _role = user.role;
        _active = user.active;
      }
    }
    _loaded = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
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
          newPassword: _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
        );
      } else {
        await repo.createUser(
          username: _usernameCtrl.text,
          name: _nameCtrl.text,
          role: _role,
          phone: _phoneCtrl.text,
          password: _passwordCtrl.text,
          active: _active,
        );
      }
      ref.read(dataRevisionProvider.notifier).state++;
      final actor = ref.read(sessionProvider)!.user;
      await ref
          .read(auditServiceProvider)
          .log(actor, _isEdit ? 'Utilisateur modifié' : 'Utilisateur créé', details: _usernameCtrl.text);
      if (mounted) {
        ToastService.success(_isEdit ? 'Utilisateur mis à jour' : 'Utilisateur créé');
        context.pop();
      }
    } catch (e) {
      ToastService.error(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final workstation = _role.workstation;

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
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: "Nom d'utilisateur"),
                    enabled: !_isEdit,
                    validator: (v) => Validators.required(v, field: "Le nom d'utilisateur"),
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
                        .map((r) => DropdownMenuItem(value: r, child: Text('${r.label} → ${r.workstation.label}')))
                        .toList(),
                    onChanged: (v) => setState(() => _role = v ?? _role),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: workstation.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(workstation.icon, color: workstation.color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cet utilisateur aura accès au poste : ${workstation.label}',
                          style: TextStyle(color: workstation.color, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: _isEdit ? 'Nouveau mot de passe (laisser vide pour ne pas changer)' : 'Mot de passe',
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (_isEdit && (v == null || v.isEmpty)) return null;
                      return Validators.password(v);
                    },
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                    obscureText: true,
                    validator: (v) {
                      if (_isEdit && _passwordCtrl.text.isEmpty) return null;
                      return Validators.confirmPassword(v, _passwordCtrl.text);
                    },
                  ),
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
