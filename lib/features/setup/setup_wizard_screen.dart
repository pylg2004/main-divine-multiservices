import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/validators.dart';
import '../../data/models/company_settings_model.dart';
import '../../data/models/enums.dart';
import '../../data/models/printer_config_model.dart';

/// Configuration optionnelle des informations de l'entreprise et de
/// l'imprimante — accessible manuellement (route /setup), plus jamais
/// imposée au démarrage. Le tout premier compte Super Admin n'est plus créé
/// ici : il se crée automatiquement à la première connexion réussie sur
/// l'écran de login (voir AuthRepository.login / _bootstrapFirstAdmin).
class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  int _step = 0;
  bool _submitting = false;

  // Étape 1
  final _companyNameCtrl = TextEditingController(text: AppStrings.appName);
  final _sloganCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _currencyCode = 'HTG';
  String _currencySymbol = 'G';

  // Étape 2
  PrinterConnectionType? _printerType;
  final _printerAddressCtrl = TextEditingController();
  final _printerPortCtrl = TextEditingController(text: '9100');
  PrinterPaperWidth _paperWidth = PrinterPaperWidth.mm58;

  final _step1FormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _sloganCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _printerAddressCtrl.dispose();
    _printerPortCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !(_step1FormKey.currentState?.validate() ?? false)) return;
    setState(() => _step++);
  }

  void _back() => setState(() => _step--);

  Future<void> _finish() async {
    setState(() => _submitting = true);
    try {
      final settingsRepo = ref.read(settingsRepositoryProvider);

      if (_printerType == PrinterConnectionType.sunmiIntegrated) {
        await settingsRepo.savePrinter(PrinterConfigModel(
          connectionType: _printerType,
          paperWidth: _paperWidth,
        ));
      } else if (_printerType != null && _printerAddressCtrl.text.trim().isNotEmpty) {
        await settingsRepo.savePrinter(PrinterConfigModel(
          connectionType: _printerType,
          address: _printerAddressCtrl.text.trim(),
          port: int.tryParse(_printerPortCtrl.text.trim()) ?? 9100,
          paperWidth: _paperWidth,
        ));
      }

      await settingsRepo.saveCompany(CompanySettingsModel(
        name: _companyNameCtrl.text.trim().isEmpty ? AppStrings.appName : _companyNameCtrl.text.trim(),
        slogan: _sloganCtrl.text.trim().isEmpty ? null : _sloganCtrl.text.trim(),
        phone: _companyPhoneCtrl.text.trim().isEmpty ? null : _companyPhoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        currencyCode: _currencyCode,
        currencySymbol: _currencySymbol,
        logoPath: AppStrings.logoAssetPath,
        setupComplete: true,
      ));

      ref.read(setupCompleteProvider.notifier).state = true;
      if (mounted) ToastService.success('Configuration terminée. Connectez-vous.');
    } catch (e) {
      ToastService.error(e.toString());
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.appName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    const Text('Configuration initiale', textAlign: TextAlign.center),
                    const SizedBox(height: AppSizes.lg),
                    _StepIndicator(step: _step),
                    const SizedBox(height: AppSizes.lg),
                    _buildStep(),
                    const SizedBox(height: AppSizes.lg),
                    Row(
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: _submitting ? null : _back,
                            child: const Text('Retour'),
                          ),
                        const Spacer(),
                        if (_step < 2)
                          FilledButton(
                            onPressed: _next,
                            child: Text(_step == 1 ? 'Continuer' : 'Suivant'),
                          )
                        else
                          FilledButton(
                            onPressed: _submitting ? null : _finish,
                            child: _submitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Terminer'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildCompanyStep();
      case 1:
        return _buildPrinterStep();
      default:
        return _buildConfirmStep();
    }
  }

  Widget _buildCompanyStep() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Étape 1 — Informations entreprise'),
          const SizedBox(height: AppSizes.md),
          TextFormField(
            controller: _companyNameCtrl,
            decoration: const InputDecoration(labelText: "Nom de l'entreprise"),
            validator: (v) => Validators.required(v, field: 'Le nom'),
          ),
          const SizedBox(height: AppSizes.sm),
          TextFormField(
            controller: _sloganCtrl,
            decoration: const InputDecoration(labelText: 'Slogan / sous-titre (optionnel)'),
          ),
          const SizedBox(height: AppSizes.sm),
          TextFormField(
            controller: _companyPhoneCtrl,
            decoration: const InputDecoration(labelText: 'Téléphone'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSizes.sm),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Adresse'),
          ),
          const SizedBox(height: AppSizes.sm),
          DropdownButtonFormField<String>(
            initialValue: _currencyCode,
            decoration: const InputDecoration(labelText: 'Devise'),
            items: const [
              DropdownMenuItem(value: 'HTG', child: Text('Gourde haïtienne (HTG)')),
              DropdownMenuItem(value: 'USD', child: Text('Dollar américain (USD)')),
            ],
            onChanged: (v) {
              setState(() {
                _currencyCode = v ?? 'HTG';
                _currencySymbol = _currencyCode == 'USD' ? '\$' : 'G';
              });
            },
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
        ],
      ),
    );
  }

  Widget _buildPrinterStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Étape 2 — Configuration imprimante POS (optionnel)'),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Vous pourrez configurer ou modifier ceci plus tard dans Paramètres imprimante.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSizes.md),
        DropdownButtonFormField<PrinterConnectionType?>(
          initialValue: _printerType,
          decoration: const InputDecoration(labelText: 'Type de connexion'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Configurer plus tard')),
            DropdownMenuItem(value: PrinterConnectionType.network, child: Text('Réseau (WiFi/Ethernet)')),
            DropdownMenuItem(value: PrinterConnectionType.usb, child: Text('USB')),
            DropdownMenuItem(
              value: PrinterConnectionType.sunmiIntegrated,
              child: Text('Imprimante intégrée (terminal Sunmi)'),
            ),
            DropdownMenuItem(
              value: PrinterConnectionType.mobiPrintIntegrated,
              child: Text('Imprimante intégrée (autre terminal)'),
            ),
          ],
          onChanged: (v) => setState(() => _printerType = v),
        ),
        if (_printerType == PrinterConnectionType.mobiPrintIntegrated)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.xs),
            child: Text(
              'Rien à saisir. Une « Détection automatique » est disponible dans '
              'Paramètres imprimante — préférez-la à ce réglage manuel.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_printerType != null) ...[
          if (_printerType != PrinterConnectionType.sunmiIntegrated &&
              _printerType != PrinterConnectionType.mobiPrintIntegrated) ...[
            const SizedBox(height: AppSizes.sm),
            TextFormField(
              controller: _printerAddressCtrl,
              decoration: InputDecoration(
                labelText: _printerType == PrinterConnectionType.network ? 'Adresse IP' : 'Identifiant USB',
              ),
            ),
            if (_printerType == PrinterConnectionType.usb)
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.xs),
                child: Text(
                  'Vous pourrez détecter automatiquement une imprimante USB branchée '
                  '(y compris l\'imprimante intégrée de nombreux terminaux Android) '
                  'depuis Paramètres imprimante.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
          if (_printerType == PrinterConnectionType.network) ...[
            const SizedBox(height: AppSizes.sm),
            TextFormField(
              controller: _printerPortCtrl,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          DropdownButtonFormField<PrinterPaperWidth>(
            initialValue: _paperWidth,
            decoration: const InputDecoration(labelText: 'Largeur du papier'),
            items: const [
              DropdownMenuItem(value: PrinterPaperWidth.mm58, child: Text('58 mm (32 caractères)')),
              DropdownMenuItem(value: PrinterPaperWidth.mm80, child: Text('80 mm (48 caractères)')),
            ],
            onChanged: (v) => setState(() => _paperWidth = v ?? PrinterPaperWidth.mm58),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Étape 3 — Confirmation'),
        const SizedBox(height: AppSizes.md),
        _SummaryRow('Entreprise', _companyNameCtrl.text),
        _SummaryRow('Devise', _currencyCode),
        _SummaryRow('Imprimante', _printerTypeLabel(_printerType)),
        const SizedBox(height: AppSizes.md),
        Text(
          'Le compte Super Admin se crée automatiquement à la première connexion : sur l\'écran '
          "de connexion, saisissez l'email et le mot de passe voulus pour ce compte fondateur. "
          "Il pourra ensuite créer tous les autres utilisateurs depuis Utilisateurs.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

String _printerTypeLabel(PrinterConnectionType? type) {
  switch (type) {
    case null:
      return 'À configurer plus tard';
    case PrinterConnectionType.network:
      return 'Réseau (WiFi/Ethernet)';
    case PrinterConnectionType.usb:
      return 'USB';
    case PrinterConnectionType.sunmiIntegrated:
      return 'Imprimante intégrée (Sunmi)';
    case PrinterConnectionType.mobiPrintIntegrated:
      return 'Imprimante intégrée (autre terminal)';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
