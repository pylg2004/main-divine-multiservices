import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/app_shell.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  final String? clientId;
  const ClientFormScreen({super.key, this.clientId});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loaded = false;

  bool get _isEdit => widget.clientId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final client = ref.read(clientRepositoryProvider).byId(widget.clientId!);
      if (client != null) {
        _nameCtrl.text = client.fullName;
        _phoneCtrl.text = client.phone;
        _emailCtrl.text = client.email ?? '';
        _notesCtrl.text = client.notes ?? '';
      }
    }
    _loaded = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(clientRepositoryProvider);
    if (_isEdit) {
      final client = repo.byId(widget.clientId!)!;
      await repo.update(
        client,
        fullName: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        notes: _notesCtrl.text,
      );
    } else {
      await repo.create(
        fullName: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        notes: _notesCtrl.text,
      );
    }
    ref.read(dataRevisionProvider.notifier).state++;
    if (mounted) {
      ToastService.success(_isEdit ? 'Client mis à jour' : 'Client créé');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return AppShell(
      title: _isEdit ? 'Modifier le client' : 'Nouveau client',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email (optionnel)'),
                    validator: Validators.optionalEmail,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes / préférences'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSizes.md),
                  FilledButton(onPressed: _save, child: Text(_isEdit ? 'Enregistrer' : 'Créer le client')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
