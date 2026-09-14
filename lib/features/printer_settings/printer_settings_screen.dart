import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/services/toast_service.dart';
import '../../data/models/enums.dart';
import '../../data/models/printer_config_model.dart';
import '../../shared/widgets/app_shell.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  late PrinterConnectionType? _type;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _portCtrl;
  late PrinterPaperWidth _paperWidth;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(settingsRepositoryProvider).printer;
    _type = config.connectionType;
    _addressCtrl = TextEditingController(text: config.address ?? '');
    _portCtrl = TextEditingController(text: (config.port ?? 9100).toString());
    _paperWidth = config.paperWidth;
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(settingsRepositoryProvider).savePrinter(PrinterConfigModel(
          connectionType: _type,
          address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 9100,
          paperWidth: _paperWidth,
        ));
    ToastService.success('Configuration imprimante enregistrée');
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    try {
      await _save();
      final company = ref.read(settingsRepositoryProvider).company;
      final service = ref.read(thermalPrinterServiceProvider);
      final bytes = await service.buildTestTicket(company);
      await service.printBytes(bytes);
      ToastService.success('Test d\'impression envoyé');
    } catch (e) {
      ToastService.error(e.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Paramètres imprimante',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kIsWeb)
                  Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    margin: const EdgeInsets.only(bottom: AppSizes.md),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      "L'impression thermique directe n'est pas disponible dans un navigateur web "
                      "(USB/Réseau bas niveau non accessibles). Utilisez l'application mobile ou desktop pour imprimer.",
                    ),
                  ),
                DropdownButtonFormField<PrinterConnectionType?>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type de connexion'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Non configurée')),
                    DropdownMenuItem(value: PrinterConnectionType.network, child: Text('Réseau (WiFi/Ethernet)')),
                    DropdownMenuItem(value: PrinterConnectionType.usb, child: Text('USB')),
                  ],
                  onChanged: (v) => setState(() => _type = v),
                ),
                if (_type != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  TextField(
                    controller: _addressCtrl,
                    decoration: InputDecoration(
                      labelText: _type == PrinterConnectionType.network ? 'Adresse IP' : 'Chemin USB',
                    ),
                  ),
                  if (_type == PrinterConnectionType.network) ...[
                    const SizedBox(height: AppSizes.sm),
                    TextField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  if (_type == PrinterConnectionType.usb)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSizes.xs),
                      child: Text(
                        "L'impression USB directe n'est pas encore disponible dans cette version. "
                        'Utilisez une connexion Réseau en attendant.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
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
                const SizedBox(height: AppSizes.lg),
                FilledButton(onPressed: _save, child: const Text('Enregistrer')),
                const SizedBox(height: AppSizes.sm),
                OutlinedButton.icon(
                  onPressed: _type == null || _testing ? null : _testPrint,
                  icon: _testing
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.print_outlined),
                  label: const Text("Test d'impression"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
