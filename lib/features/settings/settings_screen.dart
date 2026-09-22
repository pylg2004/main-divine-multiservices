import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers.dart';
import '../../core/services/toast_service.dart';
import '../../data/models/company_settings_model.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/confirm_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sloganCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late String _currencyCode;

  @override
  void initState() {
    super.initState();
    final company = ref.read(settingsRepositoryProvider).company;
    _nameCtrl = TextEditingController(text: company.name);
    _sloganCtrl = TextEditingController(text: company.slogan ?? '');
    _phoneCtrl = TextEditingController(text: company.phone ?? '');
    _addressCtrl = TextEditingController(text: company.address ?? '');
    _currencyCode = company.currencyCode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sloganCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(settingsRepositoryProvider).saveCompany(CompanySettingsModel(
          name: _nameCtrl.text.trim(),
          slogan: _sloganCtrl.text.trim().isEmpty ? null : _sloganCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          currencyCode: _currencyCode,
          currencySymbol: _currencyCode == 'USD' ? '\$' : 'G',
          logoPath: AppStrings.logoAssetPath,
          setupComplete: true,
        ));
    ToastService.success('Paramètres enregistrés');
  }

  Future<void> _resetTransactionalData() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Réinitialiser les données',
      message: 'Produits, services, clients, ventes et journal d\'audit seront définitivement supprimés. '
          'Les comptes utilisateurs et les paramètres seront conservés. Cette action est irréversible.',
      confirmLabel: 'Tout réinitialiser',
      danger: true,
    );
    if (!ok) return;
    await ref.read(productRepositoryProvider).deleteAll();
    await ref.read(beautyServiceRepositoryProvider).deleteAll();
    await ref.read(clientRepositoryProvider).deleteAll();
    await ref.read(saleRepositoryProvider).deleteAll();
    await ref.read(auditRepositoryProvider).deleteAll();
    ref.read(dataRevisionProvider.notifier).state++;
    if (mounted) ToastService.success('Données réinitialisées');
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Paramètres',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Informations entreprise', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSizes.md),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Nom de l'entreprise")),
                const SizedBox(height: AppSizes.sm),
                TextField(controller: _sloganCtrl, decoration: const InputDecoration(labelText: 'Slogan / sous-titre')),
                const SizedBox(height: AppSizes.sm),
                TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone')),
                const SizedBox(height: AppSizes.sm),
                TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Adresse')),
                const SizedBox(height: AppSizes.sm),
                DropdownButtonFormField<String>(
                  initialValue: _currencyCode,
                  decoration: const InputDecoration(labelText: 'Devise'),
                  items: const [
                    DropdownMenuItem(value: 'HTG', child: Text('Gourde haïtienne (HTG)')),
                    DropdownMenuItem(value: 'USD', child: Text('Dollar américain (USD)')),
                  ],
                  onChanged: (v) => setState(() => _currencyCode = v ?? 'HTG'),
                ),
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    Image.asset(AppStrings.logoAssetPath, width: 40, height: 40),
                    const SizedBox(width: AppSizes.sm),
                    const Expanded(
                      child: Text(
                        'Logo de l\'entreprise (déjà configuré)',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                FilledButton(onPressed: _save, child: const Text('Enregistrer')),
                const SizedBox(height: AppSizes.xl),
                const Divider(),
                const SizedBox(height: AppSizes.sm),
                Row(children: [
                  const Icon(Icons.dangerous_outlined, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Zone dangereuse', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red)),
                ]),
                const SizedBox(height: AppSizes.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  onPressed: _resetTransactionalData,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Réinitialiser toutes les données'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
