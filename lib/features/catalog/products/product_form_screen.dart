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
import 'products_list_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'unité');
  final _stockCtrl = TextEditingController(text: '0');
  final _colorCtrl = TextEditingController();
  ProductCategory _category = ProductCategory.papeterie;
  bool _active = true;
  bool _loaded = false;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final product = ref.read(productRepositoryProvider).byId(widget.productId!);
      if (product != null) {
        _nameCtrl.text = product.name;
        _priceCtrl.text = product.price.toString();
        _unitCtrl.text = product.unit;
        _stockCtrl.text = product.stock.toString();
        _colorCtrl.text = product.color ?? '';
        _category = product.category;
        _active = product.active;
      }
    }
    _loaded = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _stockCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(productRepositoryProvider);
    final price = double.parse(_priceCtrl.text.replaceAll(',', '.'));
    final stock = int.tryParse(_stockCtrl.text) ?? 0;
    if (_isEdit) {
      final product = repo.byId(widget.productId!)!;
      await repo.update(
        product,
        name: _nameCtrl.text,
        category: _category,
        price: price,
        unit: _unitCtrl.text,
        stock: stock,
        color: _colorCtrl.text,
        active: _active,
      );
    } else {
      await repo.create(
        name: _nameCtrl.text,
        category: _category,
        price: price,
        unit: _unitCtrl.text,
        stock: stock,
        color: _colorCtrl.text,
      );
    }
    ref.read(dataRevisionProvider.notifier).state++;
    if (mounted) {
      ToastService.success(_isEdit ? 'Produit mis à jour' : 'Produit créé');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final canDelete = session.can(Permission.productsDelete);

    if (!_loaded) return const SizedBox.shrink();

    return AppShell(
      title: _isEdit ? 'Modifier le produit' : 'Nouveau produit',
      actions: [
        if (_isEdit && canDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Supprimer le produit',
                message: 'Cette action est irréversible.',
                danger: true,
              );
              if (ok) {
                await ref.read(productRepositoryProvider).delete(widget.productId!);
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
                    decoration: const InputDecoration(labelText: 'Nom du produit'),
                    validator: (v) => Validators.required(v, field: 'Le nom'),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  DropdownButtonFormField<ProductCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: ProductCategory.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(productCategoryLabel(c))))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceCtrl,
                          decoration: const InputDecoration(labelText: 'Prix'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => Validators.positiveNumber(v, field: 'Le prix'),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _unitCtrl,
                          decoration: const InputDecoration(labelText: 'Unité (ex: unité, mètre)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockCtrl,
                          decoration: const InputDecoration(labelText: 'Stock'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _colorCtrl,
                          decoration: const InputDecoration(labelText: 'Couleur (optionnel)'),
                        ),
                      ),
                    ],
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
                  FilledButton(onPressed: _save, child: Text(_isEdit ? 'Enregistrer' : 'Créer le produit')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
