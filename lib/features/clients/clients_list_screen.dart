import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/utils/money_formatter.dart';
import '../../data/models/client_model.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

final clientsListProvider = Provider<List<ClientModel>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(clientRepositoryProvider).all();
});

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    var clients = ref.watch(clientsListProvider);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      clients = clients.where((c) => c.fullName.toLowerCase().contains(q) || c.phone.contains(q)).toList();
    }

    return AppShell(
      title: 'Clients',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_alt_outlined),
          tooltip: 'Nouveau client',
          onPressed: () => context.push('/clients/new'),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom ou téléphone...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: clients.isEmpty
                ? const EmptyState(icon: Icons.people_outline, title: 'Aucun client')
                : ListView.separated(
                    itemCount: clients.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = clients[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(c.fullName),
                        subtitle: Text(c.phone),
                        trailing: Text(MoneyFormatter.format(c.totalSpent)),
                        onTap: () => context.push('/clients/${c.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
