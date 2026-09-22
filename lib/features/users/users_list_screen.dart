import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../data/models/user_model.dart';
import '../../shared/permissions/workstation.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

final usersListProvider = Provider<List<UserModel>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(authRepositoryProvider).allUsers();
});

class UsersListScreen extends ConsumerWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersListProvider);

    return AppShell(
      title: 'Utilisateurs',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_alt_1_outlined),
          tooltip: 'Nouvel utilisateur',
          onPressed: () => context.push('/users/new'),
        ),
      ],
      child: users.isEmpty
          ? const EmptyState(icon: Icons.manage_accounts_outlined, title: 'Aucun utilisateur')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = users[i];
                final workstation = u.role.workstation;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: workstation.color.withValues(alpha: 0.15),
                    child: Icon(workstation.icon, color: workstation.color),
                  ),
                  title: Text(u.name),
                  subtitle: Text('${u.email} · ${u.role.label}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(workstation.label, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: workstation.color.withValues(alpha: 0.12),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        u.active ? Icons.check_circle : Icons.cancel,
                        color: u.active ? Colors.green : Colors.grey,
                        size: 18,
                      ),
                    ],
                  ),
                  onTap: () => context.push('/users/${u.id}'),
                );
              },
            ),
    );
  }
}
