import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/qty_formatter.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/product_model.dart';
import '../../../shared/permissions/permission.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../../auth/session_notifier.dart';

final productsListProvider = Provider<List<ProductModel>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(productRepositoryProvider).all();
});

String productCategoryLabel(ProductCategory c) {
  switch (c) {
    case ProductCategory.papeterie:
      return 'Papeterie';
    case ProductCategory.tissu:
      return 'Tissu';
    case ProductCategory.livre:
      return 'Livre';
    case ProductCategory.boisson:
      return 'Boisson';
  }
}

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  ProductCategory? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final canManage = session.can(Permission.productsCreateEdit);
    var products = ref.watch(productsListProvider);
    if (_filter != null) products = products.where((p) => p.category == _filter).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      products = products.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    return AppShell(
      title: 'Catalogue produits',
      actions: [
        PermissionGate(
          permission: Permission.productsCreateEdit,
          child: IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau produit',
            onPressed: () => context.push('/catalog/products/new'),
          ),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: AppSizes.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Tout'),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      const SizedBox(width: 8),
                      ...ProductCategory.values.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(productCategoryLabel(c)),
                              selected: _filter == c,
                              onSelected: (_) => setState(() => _filter = c),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Aucun produit',
                    message: 'Ajoutez votre premier produit pour commencer à vendre.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      mainAxisExtent: 210,
                      crossAxisSpacing: AppSizes.sm,
                      mainAxisSpacing: AppSizes.sm,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final p = products[i];
                      return Card(
                        child: InkWell(
                          onTap: canManage ? () => context.push('/catalog/products/${p.id}') : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSizes.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!p.active)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.visibility_off_outlined, size: 16, color: Colors.grey),
                                      ),
                                  ],
                                ),
                                Text(productCategoryLabel(p.category),
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                const Spacer(),
                                Text(
                                  MoneyFormatter.format(p.price),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Stock: ${QtyFormatter.format(p.stock, fractional: p.category == ProductCategory.tissu)} ${p.unit}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.stock <= 3 ? Colors.orange : Colors.grey,
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
      ),
    );
  }
}

Future<void> deleteProductWithConfirm(
  BuildContext context,
  WidgetRef ref,
  String productId,
) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Supprimer le produit',
    message: 'Cette action est irréversible.',
    danger: true,
  );
  if (!ok) return;
  await ref.read(productRepositoryProvider).delete(productId);
  ref.read(dataRevisionProvider.notifier).state++;
}
