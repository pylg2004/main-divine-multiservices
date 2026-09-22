import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart' as usb_printer;

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
  String? _deviceName;
  bool _testing = false;
  bool _scanningUsb = false;
  bool _autoDetecting = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(settingsRepositoryProvider).printer;
    _type = config.connectionType;
    _addressCtrl = TextEditingController(text: config.address ?? '');
    _portCtrl = TextEditingController(text: (config.port ?? 9100).toString());
    _paperWidth = config.paperWidth;
    _deviceName = config.deviceName;
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
          deviceName: _deviceName,
          paperWidth: _paperWidth,
        ));
    ToastService.success('Configuration imprimante enregistrée');
  }

  Future<void> _scanUsbPrinters() async {
    setState(() => _scanningUsb = true);
    try {
      final service = ref.read(thermalPrinterServiceProvider);
      final devices = await service.scanUsbPrinters();
      if (!mounted) return;
      if (devices.isEmpty) {
        ToastService.error('Aucune imprimante USB détectée. Vérifiez le branchement.');
        return;
      }
      final selected = await showDialog<usb_printer.UsbPrinterDevice>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Imprimantes USB détectées'),
          children: [
            for (final d in devices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, d),
                child: Text('${d.name} (${d.identifier})'),
              ),
          ],
        ),
      );
      if (selected != null) {
        setState(() {
          _addressCtrl.text = selected.identifier;
          _deviceName = selected.name;
        });
      }
    } catch (e) {
      ToastService.error(e.toString());
    } finally {
      if (mounted) setState(() => _scanningUsb = false);
    }
  }

  /// Sonde dans l'ordre les transports qui n'exigent aucune saisie manuelle
  /// (pilote imprimante intégré type MobiPrint, puis imprimante USB
  /// branchée) plutôt que de forcer l'admin à connaître d'avance le type de
  /// terminal. Réseau et Sunmi restent à sélectionner à la main (aucune
  /// méthode de détection fiable sans configuration côté app).
  Future<void> _autoDetect() async {
    setState(() => _autoDetecting = true);
    try {
      final service = ref.read(thermalPrinterServiceProvider);
      if (!kIsWeb && await service.isMobiPrintAvailable()) {
        if (!mounted) return;
        setState(() {
          _type = PrinterConnectionType.mobiPrintIntegrated;
          _addressCtrl.clear();
          _deviceName = null;
        });
        await _save();
        if (mounted) ToastService.success('Imprimante intégrée détectée et configurée.');
        return;
      }
      if (!kIsWeb) {
        final devices = await service.scanUsbPrinters();
        if (devices.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _type = PrinterConnectionType.usb;
            _addressCtrl.text = devices.first.identifier;
            _deviceName = devices.first.name;
          });
          await _save();
          if (mounted) ToastService.success('Imprimante USB détectée et configurée : ${devices.first.name}');
          return;
        }
      }
      if (mounted) {
        ToastService.error(
          'Aucune imprimante détectée automatiquement. Configurez Réseau ou Sunmi manuellement ci-dessous.',
        );
      }
    } catch (e) {
      if (mounted) ToastService.error(e.toString());
    } finally {
      if (mounted) setState(() => _autoDetecting = false);
    }
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    try {
      await _save();
      final company = ref.read(settingsRepositoryProvider).company;
      final service = ref.read(thermalPrinterServiceProvider);
      await service.printTestTicket(company);
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
                if (!kIsWeb) ...[
                  FilledButton.icon(
                    onPressed: _autoDetecting ? null : _autoDetect,
                    icon: _autoDetecting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(_autoDetecting ? 'Détection en cours...' : 'Détection automatique'),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: AppSizes.xs, bottom: AppSizes.md),
                    child: Text(
                      'Essaie de trouver et configurer automatiquement l\'imprimante de ce terminal '
                      '(intégrée ou USB). Sinon, configurez manuellement ci-dessous.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
                DropdownButtonFormField<PrinterConnectionType?>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type de connexion'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Non configurée')),
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
                  onChanged: (v) => setState(() => _type = v),
                ),
                if (_type != null) ...[
                  if (_type != PrinterConnectionType.sunmiIntegrated &&
                      _type != PrinterConnectionType.mobiPrintIntegrated) ...[
                    const SizedBox(height: AppSizes.sm),
                    TextField(
                      controller: _addressCtrl,
                      decoration: InputDecoration(
                        labelText: _type == PrinterConnectionType.network ? 'Adresse IP' : 'Identifiant USB',
                      ),
                    ),
                  ],
                  if (_type == PrinterConnectionType.network) ...[
                    const SizedBox(height: AppSizes.sm),
                    TextField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  if (_type == PrinterConnectionType.usb) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: AppSizes.xs),
                      child: Text(
                        'Fonctionne avec la plupart des imprimantes thermiques USB — y compris '
                        "l'imprimante intégrée de nombreux terminaux Android tout-en-un (hors Sunmi, "
                        'voir ci-dessus). Branchez/allumez l\'imprimante puis détectez-la.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(height: AppSizes.xs),
                      OutlinedButton.icon(
                        onPressed: _scanningUsb ? null : _scanUsbPrinters,
                        icon: _scanningUsb
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.usb),
                        label: Text(_scanningUsb ? 'Détection en cours...' : 'Détecter une imprimante USB'),
                      ),
                      if (_deviceName != null && _deviceName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSizes.xs),
                          child: Text(
                            'Sélectionnée : $_deviceName',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                    ],
                  ],
                  if (_type == PrinterConnectionType.sunmiIntegrated)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSizes.xs),
                      child: Text(
                        'Rien à saisir : les reçus sont envoyés directement à l\'imprimante '
                        "intégrée de ce terminal. Fonctionne uniquement sur un appareil Sunmi.",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  if (_type == PrinterConnectionType.mobiPrintIntegrated)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSizes.xs),
                      child: Text(
                        'Rien à saisir : pour les terminaux Android sans SDK ni USB standard '
                        '(ex. MobiPrint 3+ / Mobilot MP3+). Texte simple uniquement (pas de mise '
                        'en forme avancée). Utilisez plutôt « Détection automatique » ci-dessus.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
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
