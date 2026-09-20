import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/utils/validators.dart';
import '../../data/models/client_model.dart';

/// Recherche ou création rapide d'un client — utilisé par la caisse et par
/// la gestion des clients. Un client est obligatoire pour encaisser (plus
/// de vente anonyme) : retourne `null` seulement si l'utilisateur ferme la
/// feuille sans choisir, auquel cas le bouton "Encaisser" reste désactivé.
Future<ClientModel?> showClientPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<ClientModel>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ClientPickerSheet(),
  );
}

class _ClientPickerSheet extends ConsumerStatefulWidget {
  const _ClientPickerSheet();

  @override
  ConsumerState<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<_ClientPickerSheet> {
  String _query = '';
  bool _creating = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAndSelect() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final client = await ref.read(clientRepositoryProvider).create(
          fullName: _nameCtrl.text,
          phone: _phoneCtrl.text,
        );
    ref.read(dataRevisionProvider.notifier).state++;
    if (mounted) Navigator.of(context).pop(client);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(clientRepositoryProvider).search(_query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sélectionner un client', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSizes.sm),
                if (!_creating) ...[
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher par nom ou téléphone...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _creating = true),
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: const Text('Nouveau client'),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        for (final c in results)
                          ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(c.fullName),
                            subtitle: Text(c.phone),
                            onTap: () => Navigator.of(context).pop(c),
                          ),
                      ],
                    ),
                  ),
                ] else
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
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
                            const SizedBox(height: AppSizes.md),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _creating = false),
                                    child: const Text('Annuler'),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.sm),
                                Expanded(
                                  child: FilledButton(onPressed: _createAndSelect, child: const Text('Créer')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
