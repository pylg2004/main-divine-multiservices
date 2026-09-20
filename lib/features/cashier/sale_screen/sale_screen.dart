import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers.dart';
import '../../../core/services/toast_service.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/qty_formatter.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/sale_item_model.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/aune_quantity_picker.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/session_notifier.dart';
import '../../catalog/beauty_services/beauty_services_list_screen.dart';
import '../../catalog/print_services/print_services_list_screen.dart';
import '../../catalog/products/products_list_screen.dart';
import '../../clients/client_picker.dart';
import 'checkout_sheet.dart';
import '../cart/cart_notifier.dart';

class _CatalogEntry {
  final String id;
  final SaleItemType type;
  final String title;
  final String categoryLabel;
  final String unit;
  final String? color;
  final double price;
  final bool discountEligible;
  const _CatalogEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.categoryLabel,
    this.unit = 'unité',
    this.color,
    required this.price,
    this.discountEligible = true,
  });
}

/// Caisse unifiée (spec §8) : une seule interface dont le catalogue et les
/// filtres s'adaptent automatiquement au poste de travail connecté.
class SaleScreen extends ConsumerStatefulWidget {
  const SaleScreen({super.key});

  @override
  ConsumerState<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends ConsumerState<SaleScreen> {
  String _categoryFilter = 'Tout';
  String _query = '';
  int _mobileTab = 0;

  List<_CatalogEntry> _catalogFor(Workstation workstation) {
    final entries = <_CatalogEntry>[];
    if (workstation == Workstation.pos || workstation == Workstation.admin || workstation == Workstation.general) {
      for (final p in ref.watch(productsListProvider).where((p) => p.active)) {
        entries.add(_CatalogEntry(
          id: p.id,
          type: SaleItemType.product,
          title: p.name,
          categoryLabel: productCategoryLabel(p.category),
          unit: p.unit,
          color: p.color,
          price: p.price,
          discountEligible: p.discountEligible,
        ));
      }
    }
    if (workstation == Workstation.beauty || workstation == Workstation.admin || workstation == Workstation.general) {
      for (final s in ref.watch(beautyServicesListProvider).where((s) => s.active)) {
        entries.add(_CatalogEntry(
          id: s.id,
          type: SaleItemType.beautyService,
          title: s.name,
          categoryLabel: beautyCategoryLabel(s.category),
          price: s.price,
        ));
      }
    }
    if (workstation == Workstation.impression || workstation == Workstation.admin || workstation == Workstation.general) {
      for (final s in ref.watch(printServicesListProvider).where((s) => s.active)) {
        entries.add(_CatalogEntry(
          id: s.id,
          type: SaleItemType.printService,
          title: s.name,
          categoryLabel: printCategoryLabel(s.category),
          price: s.price,
        ));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final workstation = session.workstation;
    var catalog = _catalogFor(workstation);

    final categories = ['Tout', ...{for (final e in catalog) e.categoryLabel}];
    if (_categoryFilter != 'Tout') {
      catalog = catalog.where((e) => e.categoryLabel == _categoryFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      catalog = catalog.where((e) => e.title.toLowerCase().contains(q)).toList();
    }

    final catalogPane = _buildCatalogPane(catalog, categories);
    final cartPane = const _CartPane();

    return AppShell(
      title: 'Caisse',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppSizes.tabletBreakpoint) {
            return Row(
              children: [
                Expanded(flex: 3, child: catalogPane),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: cartPane),
              ],
            );
          }
          final cartCount = ref.watch(cartProvider).length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSizes.sm),
                child: SegmentedButton<int>(
                  segments: [
                    const ButtonSegment(value: 0, label: Text('Catalogue'), icon: Icon(Icons.grid_view)),
                    ButtonSegment(
                      value: 1,
                      label: Text('Panier ($cartCount)'),
                      icon: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ],
                  selected: {_mobileTab},
                  onSelectionChanged: (s) => setState(() => _mobileTab = s.first),
                ),
              ),
              Expanded(child: _mobileTab == 0 ? catalogPane : cartPane),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCatalogPane(List<_CatalogEntry> catalog, List<String> categories) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(hintText: 'Rechercher...', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSizes.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: _categoryFilter == c,
                              onSelected: (_) => setState(() => _categoryFilter = c),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: catalog.isEmpty
              ? const EmptyState(icon: Icons.storefront_outlined, title: 'Catalogue vide')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: AppSizes.sm,
                    mainAxisSpacing: AppSizes.sm,
                  ),
                  itemCount: catalog.length,
                  itemBuilder: (context, i) {
                    final e = catalog[i];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          var qty = 1.0;
                          if (QtyFormatter.isFractionalUnit(e.unit)) {
                            final picked = await showAuneQuantityPicker(
                              context,
                              title: e.title,
                              unitPrice: e.price,
                            );
                            if (picked == null) return;
                            qty = picked;
                          }
                          if (!context.mounted) return;
                          ref.read(cartProvider.notifier).add(CartItem(
                                referenceId: e.id,
                                type: e.type,
                                title: e.title,
                                category: e.categoryLabel,
                                unit: e.unit,
                                color: e.color,
                                unitPrice: e.price,
                                qty: qty,
                                discountEligible: e.discountEligible,
                              ));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              Text(e.categoryLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const Spacer(),
                              Text(
                                MoneyFormatter.format(e.price),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CartPane extends ConsumerWidget {
  const _CartPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final client = ref.watch(selectedClientProvider);
    final subtotal = cart.fold<double>(0, (sum, i) => sum + i.sum);
    final total = subtotal;

    return Column(
      children: [
        Expanded(
          child: cart.isEmpty
              ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Panier vide')
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: cart.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = cart[i];
                    final fractional = QtyFormatter.isFractionalUnit(item.unit);
                    final step = fractional ? QtyFormatter.auneStep : 1.0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title),
                      subtitle: Text(
                        item.hasBulkDiscount
                            ? '${MoneyFormatter.format(item.unitPrice)} · -10% (quantité ≥ 3)'
                            : MoneyFormatter.format(item.unitPrice),
                        style: item.hasBulkDiscount
                            ? const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)
                            : null,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .updateQty(item.referenceId, item.type, item.qty - step),
                          ),
                          fractional
                              ? InkWell(
                                  onTap: () async {
                                    final picked = await showAuneQuantityPicker(
                                      context,
                                      title: item.title,
                                      initial: item.qty,
                                      unitPrice: item.unitPrice,
                                    );
                                    if (picked == null) return;
                                    ref
                                        .read(cartProvider.notifier)
                                        .updateQty(item.referenceId, item.type, picked);
                                  },
                                  child: Text(QtyFormatter.format(item.qty, fractional: true)),
                                )
                              : _CartQtyField(
                                  qty: item.qty,
                                  onChanged: (v) => ref
                                      .read(cartProvider.notifier)
                                      .updateQty(item.referenceId, item.type, v),
                                ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .updateQty(item.referenceId, item.type, item.qty + step),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.person_outline,
                  color: client == null ? Colors.red : null,
                ),
                title: Text(
                  client?.fullName ?? 'Client requis',
                  style: client == null ? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold) : null,
                ),
                subtitle: client == null ? const Text('Sélectionnez un client pour pouvoir encaisser') : null,
                trailing: TextButton(
                  onPressed: () async {
                    final selected = await showClientPicker(context, ref);
                    ref.read(selectedClientProvider.notifier).state = selected;
                  },
                  child: const Text('Choisir'),
                ),
              ),
              _totalRow('Sous-total', MoneyFormatter.format(subtotal)),
              _totalRow('TOTAL', MoneyFormatter.format(total), bold: true),
              const SizedBox(height: AppSizes.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: cart.isEmpty ? null : () => ref.read(cartProvider.notifier).clear(),
                      child: const Text('Vider'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: cart.isEmpty || client == null
                          ? null
                          : () => _checkout(context, ref, client, total),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Encaisser'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 18 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: style),
        Text(value, style: style),
      ]),
    );
  }

  Future<void> _checkout(
    BuildContext context,
    WidgetRef ref,
    ClientModel client,
    double total,
  ) async {
    final method = await showCheckoutSheet(context, total: total);
    if (method == null) return;

    final session = ref.read(sessionProvider)!;
    final cart = ref.read(cartProvider);
    final items = cart
        .map((c) => SaleItemModel(
              id: c.referenceId,
              type: c.type,
              referenceId: c.referenceId,
              title: c.title,
              category: c.category,
              unit: c.unit,
              color: c.color,
              qty: c.qty,
              unitPrice: c.unitPrice,
              discountEligible: c.discountEligible,
            ))
        .toList();

    final loyaltyPoints = (total / 100).floor();

    final sale = await ref.read(saleRepositoryProvider).create(
          sellerId: session.user.id,
          sellerName: session.user.name,
          sellerRole: session.user.role.name,
          workstation: session.workstation,
          clientId: client.id,
          clientName: client.fullName,
          clientPhone: client.phone,
          items: items,
          paymentMethod: method,
          loyaltyPointsEarned: loyaltyPoints,
        );

    await ref.read(clientRepositoryProvider).registerVisit(
          clientId: client.id,
          amountSpent: total,
          pointsEarned: loyaltyPoints,
        );

    await ref.read(auditServiceProvider).log(
          session.user,
          'Vente créée',
          details: '${sale.id} — ${MoneyFormatter.format(total)}',
        );

    ref.read(cartProvider.notifier).clear();
    ref.read(selectedClientProvider.notifier).state = null;
    ref.read(dataRevisionProvider.notifier).state++;

    if (context.mounted) {
      ToastService.success('Vente ${sale.id} enregistrée');
      final company = ref.read(settingsRepositoryProvider).company;
      try {
        final bytes = await ref.read(thermalPrinterServiceProvider).buildSaleReceipt(sale: sale, company: company);
        await ref.read(thermalPrinterServiceProvider).printBytes(bytes);
        if (context.mounted) ToastService.success('Reçu imprimé');
      } catch (e) {
        if (context.mounted) ToastService.error(e.toString());
      }
    }
  }
}

/// Petit champ de saisie pour la quantité d'une ligne du panier — plus
/// rapide que les boutons +/- pour entrer un grand nombre. Garde son
/// propre contrôleur pour permettre la frappe libre, et ne pousse la
/// valeur vers le panier qu'à la validation (submit/perte de focus) ; se
/// resynchronise sur `qty` si celle-ci change ailleurs (boutons +/-).
class _CartQtyField extends StatefulWidget {
  final double qty;
  final ValueChanged<double> onChanged;

  const _CartQtyField({required this.qty, required this.onChanged});

  @override
  State<_CartQtyField> createState() => _CartQtyFieldState();
}

class _CartQtyFieldState extends State<_CartQtyField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  static String _format(double q) => q == q.roundToDouble() ? q.round().toString() : q.toString();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.qty));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
      } else {
        _submit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CartQtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (oldWidget.qty != widget.qty && current != widget.qty) {
      _ctrl.text = _format(widget.qty);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (parsed != null && parsed > 0) {
      widget.onChanged(parsed);
    } else {
      _ctrl.text = _format(widget.qty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _ctrl,
        focusNode: _focusNode,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
        ),
        onSubmitted: (_) => _focusNode.unfocus(),
      ),
    );
  }
}
