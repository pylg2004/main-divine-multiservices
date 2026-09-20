import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/print_service_model.dart';
import '../../../shared/permissions/permission.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../../auth/session_notifier.dart';

final printServicesListProvider = Provider<List<PrintServiceModel>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(printServiceRepositoryProvider).all();
});

String printCategoryLabel(PrintServiceCategory c) {
  switch (c) {
    case PrintServiceCategory.impression:
      return 'Impression';
    case PrintServiceCategory.flyers:
      return 'Flyers';
    case PrintServiceCategory.cartesDeVisite:
      return 'Cartes de visite';
    case PrintServiceCategory.affiches:
      return 'Affiches';
    case PrintServiceCategory.servicesInformatiques:
      return 'Services informatiques';
    case PrintServiceCategory.autre:
      return 'Autre';
  }
}

class PrintServicesListScreen extends ConsumerStatefulWidget {
  const PrintServicesListScreen({super.key});

  @override
  ConsumerState<PrintServicesListScreen> createState() => _PrintServicesListScreenState();
}

class _PrintServicesListScreenState extends ConsumerState<PrintServicesListScreen> {
  PrintServiceCategory? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final canManage = session.can(Permission.printServicesCreateEdit);
    var services = ref.watch(printServicesListProvider);
    if (_filter != null) services = services.where((s) => s.category == _filter).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      services = services.where((s) => s.name.toLowerCase().contains(q)).toList();
    }

    return AppShell(
      title: "Catalogue d'impression",
      actions: [
        PermissionGate(
          permission: Permission.printServicesCreateEdit,
          child: IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau service',
            onPressed: () => context.push('/catalog/print-services/new'),
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
                    hintText: 'Rechercher un service...',
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
                      ...PrintServiceCategory.values.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(printCategoryLabel(c)),
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
            child: services.isEmpty
                ? const EmptyState(
                    icon: Icons.local_printshop_outlined,
                    title: 'Aucun service',
                    message: "Ajoutez votre premier service d'impression (flyers, cartes, services informatiques...).",
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      mainAxisExtent: 210,
                      crossAxisSpacing: AppSizes.sm,
                      mainAxisSpacing: AppSizes.sm,
                    ),
                    itemCount: services.length,
                    itemBuilder: (context, i) {
                      final s = services[i];
                      return Card(
                        child: InkWell(
                          onTap: canManage ? () => context.push('/catalog/print-services/${s.id}') : null,
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
                                        s.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!s.active)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.visibility_off_outlined, size: 16, color: Colors.grey),
                                      ),
                                  ],
                                ),
                                Text(printCategoryLabel(s.category),
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                if (s.description != null && s.description!.isNotEmpty)
                                  Text(
                                    s.description!,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const Spacer(),
                                Text(
                                  MoneyFormatter.format(s.price),
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
      ),
    );
  }
}
