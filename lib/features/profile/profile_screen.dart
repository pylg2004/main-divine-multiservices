import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/validators.dart';
import '../../shared/permissions/workstation.dart';
import '../../shared/widgets/app_shell.dart';
import '../auth/session_notifier.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider)!.user;
    _nameCtrl = TextEditingController(text: user.name);
    _phoneCtrl = TextEditingController(text: user.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final session = ref.read(sessionProvider)!;
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.updateUser(session.user, name: _nameCtrl.text, phone: _phoneCtrl.text);
      if (_passwordCtrl.text.isNotEmpty) {
        await repo.updateOwnPassword(_passwordCtrl.text);
      }
      ref.read(sessionProvider.notifier).refreshUser();
      _passwordCtrl.clear();
      _confirmPasswordCtrl.clear();
      ToastService.success('Profil mis à jour');
    } catch (e) {
      ToastService.error(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final workstation = session.workstation;

    return AppShell(
      title: 'Profil',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: workstation.color.withValues(alpha: 0.15),
                        child: Icon(workstation.icon, size: 36, color: workstation.color),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(session.user.name, style: Theme.of(context).textTheme.titleLarge),
                      Text(session.user.role.label, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: AppSizes.xs),
                      Chip(
                        label: Text(workstation.label),
                        backgroundColor: workstation.color.withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.xl),
                Form(
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
                        initialValue: session.user.email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        enabled: false,
                      ),
                      const SizedBox(height: AppSizes.sm),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Téléphone'),
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                      ),
                      // Chaque utilisateur peut changer son propre mot de passe (Firebase
                      // Auth : updatePassword() ne s'applique qu'au compte actuellement
                      // connecté, quel qu'il soit). Pour changer le mot de passe d'un
                      // AUTRE compte, un admin utilise "Envoyer un lien de
                      // réinitialisation" depuis Utilisateurs (le SDK client ne permet
                      // pas de définir directement le mot de passe d'autrui).
                      const SizedBox(height: AppSizes.md),
                      const Divider(),
                      const SizedBox(height: AppSizes.sm),
                      Text('Changer le mot de passe', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppSizes.sm),
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: const InputDecoration(labelText: 'Nouveau mot de passe (optionnel)'),
                        obscureText: true,
                        validator: (v) => v == null || v.isEmpty ? null : Validators.password(v),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                        obscureText: true,
                        validator: (v) =>
                            _passwordCtrl.text.isEmpty ? null : Validators.confirmPassword(v, _passwordCtrl.text),
                      ),
                      const SizedBox(height: AppSizes.md),
                      FilledButton(onPressed: _save, child: const Text('Enregistrer')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
