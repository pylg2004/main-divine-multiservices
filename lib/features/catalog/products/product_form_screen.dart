import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers.dart';
import '../../../core/services/toast_service.dart';
import '../../../core/utils/qty_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/enums.dart';
import '../../../shared/permissions/permission.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/session_notifier.dart';
import 'products_list_screen.dart';

const _auneUnit = 'aune';

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
  bool _discountEligible = true;
  bool _loaded = false;
  int _auneWhole = 0;
  int _auneQuarters = 0;

  bool get _isEdit => widget.productId != null;
  bool get _isTissu => _category == ProductCategory.tissu;

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
        _discountEligible = product.discountEligible;
        _setAuneFromStock(product.stock);
      }
    }
    if (_isTissu) _unitCtrl.text = _auneUnit;
    _loaded = true;
  }

  void _setAuneFromStock(double stock) {
    final rounded = QtyFormatter.roundToStep(stock.abs());
    var whole = rounded.truncate();
    var quarters = ((rounded - whole) * 4).round();
    if (quarters == 4) {
      whole += 1;
      quarters = 0;
    }
    _auneWhole = whole;
    _auneQuarters = quarters;
  }

  void _onCategoryChanged(ProductCategory? c) {
    setState(() {
      _category = c ?? _category;
      if (_isTissu) {
        _unitCtrl.text = _auneUnit;
      }
    });
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
    final stock = _isTissu
        ? _auneWhole + _auneQuarters * QtyFormatter.auneStep
        : (double.tryParse(_stockCtrl.text.replaceAll(',', '.')) ?? 0);
    final unit = _isTissu ? _auneUnit : _unitCtrl.text;
    if (_isEdit) {
      final product = repo.byId(widget.productId!)!;
      await repo.update(
        product,
        name: _nameCtrl.text,
        category: _category,
        price: price,
        unit: unit,
        stock: stock,
        color: _colorCtrl.text,
        active: _active,
        discountEligible: _discountEligible,
      );
    } else {
      await repo.create(
        name: _nameCtrl.text,
        category: _category,
        price: price,
        unit: unit,
        stock: stock,
        color: _colorCtrl.text,
        discountEligible: _discountEligible,
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
                    onChanged: _onCategoryChanged,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceCtrl,
                          decoration: InputDecoration(labelText: _isTissu ? 'Prix par aune' : 'Prix'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => Validators.positiveNumber(v, field: 'Le prix'),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _unitCtrl,
                          enabled: !_isTissu,
                          decoration: const InputDecoration(labelText: 'Unité (ex: unité, mètre)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  if (_isTissu) _buildAuneStockPicker() else _buildStockRow(),
                  const SizedBox(height: AppSizes.sm),
                  SwitchListTile(
                    title: const Text('Actif'),
                    subtitle: const Text('Visible dans le catalogue de la caisse'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Remise quantité'),
                    subtitle: const Text('10% de remise automatique dès 3 unités achetées'),
                    value: _discountEligible,
                    onChanged: (v) => setState(() => _discountEligible = v),
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

  Widget _buildStockRow() {
    return Row(
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
    );
  }

  Widget _buildAuneStockPicker() {
    final total = _auneWhole + _auneQuarters * QtyFormatter.auneStep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stock (en aune)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSizes.sm),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _auneWhole > 0 ? () => setState(() => _auneWhole--) : null,
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$_auneWhole',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => _auneWhole++),
            ),
            const SizedBox(width: AppSizes.sm),
            const Text('aune(s)'),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        Wrap(
          spacing: AppSizes.sm,
          children: [
            ChoiceChip(
              label: const Text('Aucun'),
              selected: _auneQuarters == 0,
              onSelected: (_) => setState(() => _auneQuarters = 0),
            ),
            ChoiceChip(
              label: const Text('1/4'),
              selected: _auneQuarters == 1,
              onSelected: (_) => setState(() => _auneQuarters = 1),
            ),
            ChoiceChip(
              label: const Text('1/2'),
              selected: _auneQuarters == 2,
              onSelected: (_) => setState(() => _auneQuarters = 2),
            ),
            ChoiceChip(
              label: const Text('3/4'),
              selected: _auneQuarters == 3,
              onSelected: (_) => setState(() => _auneQuarters = 3),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        Text('Quantité en stock: ${QtyFormatter.aune(total)} aune',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSizes.sm),
        TextFormField(
          controller: _colorCtrl,
          decoration: const InputDecoration(labelText: 'Couleur (optionnel)'),
        ),
      ],
    );
  }
}
