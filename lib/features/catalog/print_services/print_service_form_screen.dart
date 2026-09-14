import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers.dart';
import '../../../core/services/toast_service.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/enums.dart';
import '../../../shared/permissions/permission.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/session_notifier.dart';
import 'print_services_list_screen.dart';

class PrintServiceFormScreen extends ConsumerStatefulWidget {
  final String? serviceId;
  const PrintServiceFormScreen({super.key, this.serviceId});

  @override
  ConsumerState<PrintServiceFormScreen> createState() => _PrintServiceFormScreenState();
}

class _PrintServiceFormScreenState extends ConsumerState<PrintServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  PrintServiceCategory _category = PrintServiceCategory.impression;
  bool _active = true;
  bool _loaded = false;

  bool get _isEdit => widget.serviceId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final service = ref.read(printServiceRepositoryProvider).byId(widget.serviceId!);
      if (service != null) {
        _nameCtrl.text = service.name;
        _priceCtrl.text = service.price.toString();
        _descriptionCtrl.text = service.description ?? '';
        _category = service.category;
        _active = service.active;
      }
    }
    _loaded = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(printServiceRepositoryProvider);
    final price = double.parse(_priceCtrl.text.replaceAll(',', '.'));
    if (_isEdit) {
      final service = repo.byId(widget.serviceId!)!;
      await repo.update(
        service,
        name: _nameCtrl.text,
        category: _category,
        price: price,
        description: _descriptionCtrl.text,
        active: _active,
      );
    } else {
      await repo.create(
        name: _nameCtrl.text,
        category: _category,
        price: price,
        description: _descriptionCtrl.text,
      );
    }
    ref.read(dataRevisionProvider.notifier).state++;
    if (mounted) {
      ToastService.success(_isEdit ? 'Service mis à jour' : 'Service créé');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final canDelete = session.can(Permission.printServicesDelete);

    if (!_loaded) return const SizedBox.shrink();

    return AppShell(
      title: _isEdit ? 'Modifier le service' : 'Nouveau service',
      actions: [
        if (_isEdit && canDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Supprimer le service',
                message: 'Cette action est irréversible.',
                danger: true,
              );
              if (ok) {
                await ref.read(printServiceRepositoryProvider).delete(widget.serviceId!);
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
                    decoration: const InputDecoration(labelText: 'Nom du service'),
                    validator: (v) => Validators.required(v, field: 'Le nom'),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  DropdownButtonFormField<PrintServiceCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: PrintServiceCategory.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(printCategoryLabel(c))))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(labelText: 'Prix'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => Validators.positiveNumber(v, field: 'Le prix'),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                      hintText: 'Ex : flyers A5 recto-verso, installation logiciel...',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  SwitchListTile(
                    title: const Text('Actif'),
                    subtitle: const Text('Visible dans le catalogue de la caisse'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSizes.md),
                  FilledButton(onPressed: _save, child: Text(_isEdit ? 'Enregistrer' : 'Créer le service')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
