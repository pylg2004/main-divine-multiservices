import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException, rootBundle;
import 'package:image/image.dart' as img;
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart' as usb_printer;

import '../../data/models/client_model.dart';
import '../../data/models/company_settings_model.dart';
import '../../data/models/enums.dart';
import '../../data/models/printer_config_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/repositories/settings_repository.dart';
import '../constants/app_strings.dart';
import '../errors/app_exception.dart';
import '../utils/date_formatter.dart';
import '../utils/money_formatter.dart';
import '../utils/qty_formatter.dart';
import 'mobiprint_channel.dart';

/// Construit les tickets ESC/POS (spec §9) et les envoie directement à
/// l'imprimante configurée — jamais de PDF (règle §5 du prompt).
///
/// Le Bluetooth n'est pas proposé : la seule lib BLE cross-platform viable
/// (flutter_blue_plus) impose une licence commerciale payante pour tout usage
/// par une entreprise à but lucratif — refusé pour ce projet. Réseau
/// (WiFi/Ethernet) et USB générique (unified_esc_pos_printer — câble, ou
/// module thermique interne câblé en USB de la plupart des terminaux Android
/// tout-en-un génériques) sont donc les deux transports principaux. Les
/// terminaux Sunmi (imprimante intégrée non exposée en USB, pas de
/// réseau/USB à configurer) sont pris en charge à part via le SDK Sunmi
/// (sunmi_printer_plus), qui accepte directement les mêmes octets ESC/POS.
/// Certains terminaux Android bas de gamme sans SDK ni USB standard
/// (constaté sur MobiWire MobiPrint 3+ / "Mobilot MP3+") exposent leur
/// imprimante via un service système propriétaire (AIDL) au lieu d'USB —
/// voir [MobiPrintChannel], qui reconstruit l'appel à ce service depuis
/// [PrinterConnectionType.mobiPrintIntegrated] et accepte directement les
/// mêmes octets ESC/POS que les autres transports (aucune limitation de
/// mise en forme contrairement à l'ancien protocole texte brut).
///
/// Limitation assumée : un navigateur web ne peut ouvrir ni socket TCP brut,
/// ni connexion USB. Sur Flutter web, [printBytes] échoue donc toujours avec
/// un message clair plutôt que de tenter silencieusement une impression qui
/// ne peut pas fonctionner.
class ThermalPrinterService {
  final SettingsRepository _settingsRepo;
  ThermalPrinterService(this._settingsRepo);

  Future<Generator> _generator() async {
    final width = _settingsRepo.printer.paperWidth;
    final paper = width == PrinterPaperWidth.mm80 ? PaperSize.mm80 : PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    return Generator(paper, profile);
  }

  /// Crée un générateur et bascule explicitement l'imprimante sur la table
  /// de caractères CP1252 (couvre tous les accents français : é, è, à, ç,
  /// ù, ê, ô, î...). Sans ça, l'imprimante reste sur son réglage d'usine
  /// (CP437 sur la plupart des modèles), qui affiche les accents comme des
  /// caractères incorrects — le texte Dart est déjà encodé en octets
  /// latin1 (voir Generator.codec) : encore faut-il dire à l'imprimante de
  /// les interpréter avec la bonne table, d'où cet appel.
  Future<(Generator, List<int>)> _newTicket() async {
    final g = await _generator();
    final bytes = <int>[...g.setGlobalCodeTable('CP1252')];
    return (g, bytes);
  }

  String _money(num amount, CompanySettingsModel company) =>
      MoneyFormatter.format(amount, symbol: company.currencySymbol);

  img.Image? _logoCache;

  /// Charge et redimensionne le logo de l'entreprise (même asset que le
  /// reste de l'app — voir AppStrings.logoAssetPath) pour l'en-tête du
  /// reçu. Mis en cache après le premier chargement. Retourne `null` en
  /// cas d'échec (asset manquant/corrompu) plutôt que de faire échouer
  /// toute l'impression — le ticket s'imprime alors sans logo.
  Future<img.Image?> _loadLogo() async {
    if (_logoCache != null) return _logoCache;
    try {
      final data = await rootBundle.load(AppStrings.logoAssetPath);
      final decoded = img.decodeImage(data.buffer.asUint8List());
      if (decoded == null) return null;
      // Largeur raisonnable pour un ticket thermique (mm58 = 384px max).
      final resized = decoded.width > 220 ? img.copyResize(decoded, width: 220) : decoded;
      _logoCache = resized;
      return resized;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────── Tickets de vente ───────────────────────────
  // Mise en page classique : en-tête entreprise (nom, adresse, téléphone),
  // infos de la vente, tableau Article/Qté/Total, totaux, formule de
  // politesse — identique quel que soit le poste (spec §9).
  Future<List<int>> buildSaleReceipt({
    required SaleModel sale,
    required CompanySettingsModel company,
  }) async {
    final (g, initial) = await _newTicket();
    List<int> bytes = initial;

    final isBeauty = sale.workstation == Workstation.beauty;
    final isSinglePoste = sale.workstation == Workstation.pos ||
        isBeauty ||
        sale.workstation == Workstation.impression;

    // ── En-tête ──
    final logo = await _loadLogo();
    if (logo != null) {
      bytes += g.imageRaster(logo, align: PosAlign.center);
    }
    bytes += g.text(
      company.name,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    if (company.address != null && company.address!.isNotEmpty) {
      bytes += g.text(company.address!, styles: const PosStyles(align: PosAlign.center));
    }
    if (company.phone != null && company.phone!.isNotEmpty) {
      bytes += g.text('Tél: ${company.phone}', styles: const PosStyles(align: PosAlign.center));
    }
    bytes += g.hr();

    // ── Infos de la vente ──
    bytes += g.text('Reçu N°: ${sale.id}');
    bytes += g.text('Date: ${DateFormatter.dateTime(sale.date)}');
    bytes += g.text('Client: ${sale.clientName}');
    if (sale.clientPhone.isNotEmpty) bytes += g.text('Tél: ${sale.clientPhone}');
    bytes += g.text(
      'Servi par: ${sale.sellerName}${isSinglePoste ? '' : ' (${sale.workstation.name})'}',
    );
    bytes += g.hr();

    // ── Articles ──
    bytes += g.row([
      PosColumn(text: 'Article', width: 6),
      PosColumn(text: 'Qté', width: 2, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: 'Total', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += g.hr(ch: '-');
    for (final item in sale.items) {
      bytes += g.row([
        PosColumn(text: item.title, width: 6),
        PosColumn(
          text: QtyFormatter.format(item.qty, fractional: QtyFormatter.isFractionalUnit(item.unit)),
          width: 2,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(text: _money(item.sum, company), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += g.hr();

    // ── Totaux ──
    bytes += g.row([
      PosColumn(text: 'Sous-total', width: 8),
      PosColumn(text: _money(sale.subtotal, company), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (sale.discount > 0) {
      bytes += g.row([
        PosColumn(text: 'Remise', width: 8),
        PosColumn(text: '-${_money(sale.discount, company)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += g.row([
      PosColumn(text: 'TOTAL', width: 8, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: _money(sale.total, company),
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]);
    bytes += g.text('Paiement: ${_paymentLabel(sale.paymentMethod)}');
    bytes += g.hr();

    // ── Formule de politesse ──
    bytes += g.text('Merci de votre visite.', styles: const PosStyles(align: PosAlign.center));
    bytes += g.text('À bientôt !', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }

  /// Point d'entrée unique pour imprimer un reçu de vente (flux ESC/POS,
  /// quel que soit le transport configuré — voir [printBytes]).
  Future<void> printSaleReceipt({required SaleModel sale, required CompanySettingsModel company}) async {
    await printBytes(await buildSaleReceipt(sale: sale, company: company));
  }

  // ─────────────────────────── Fiche client ───────────────────────────
  Future<List<int>> buildClientCard({
    required ClientModel client,
    required CompanySettingsModel company,
    required List<SaleModel> recentSales,
  }) async {
    final (g, initial) = await _newTicket();
    List<int> bytes = initial;
    bytes += g.text(company.name, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += g.text('FICHE CLIENT', styles: const PosStyles(align: PosAlign.center));
    bytes += g.hr();
    bytes += g.text('Nom: ${client.fullName}');
    bytes += g.text('Tél: ${client.phone}');
    if (client.email != null && client.email!.isNotEmpty) bytes += g.text('Email: ${client.email}');
    bytes += g.text('Client depuis: ${DateFormatter.date(client.createdAt)}');
    bytes += g.hr();
    bytes += g.text('STATISTIQUES', styles: const PosStyles(bold: true));
    bytes += g.text('Total dépensé: ${_money(client.totalSpent, company)}');
    bytes += g.text('Points fidélité: ${client.loyaltyPoints}');
    bytes += g.text('Nb visites: ${recentSales.length}');
    if (client.lastVisit != null) {
      bytes += g.text('Dernière visite: ${DateFormatter.date(client.lastVisit!)}');
    }
    bytes += g.hr();
    bytes += g.text('DERNIÈRES VISITES', styles: const PosStyles(bold: true));
    for (final sale in recentSales.take(5)) {
      bytes += g.row([
        PosColumn(text: DateFormatter.date(sale.date), width: 6),
        PosColumn(text: _money(sale.total, company), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    if (client.notes != null && client.notes!.isNotEmpty) {
      bytes += g.hr();
      bytes += g.text('NOTES / PRÉFÉRENCES', styles: const PosStyles(bold: true));
      bytes += g.text(client.notes!);
    }
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }

  Future<void> printClientCard({
    required ClientModel client,
    required CompanySettingsModel company,
    required List<SaleModel> recentSales,
  }) async {
    await printBytes(await buildClientCard(client: client, company: company, recentSales: recentSales));
  }

  // ─────────────────────── Rapport de caisse journalier ───────────────────────
  Future<List<int>> buildDailyReport({
    required CompanySettingsModel company,
    required String periodLabel,
    required int posSalesCount,
    required double posRevenue,
    required int beautySalesCount,
    required double beautyRevenue,
    required int printSalesCount,
    required double printRevenue,
    required Map<PaymentMethod, double> paymentsByMethod,
    required String editedBy,
  }) async {
    final (g, initial) = await _newTicket();
    List<int> bytes = initial;
    bytes += g.text(company.name, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += g.text('RAPPORT DE CAISSE', styles: const PosStyles(align: PosAlign.center));
    bytes += g.text(periodLabel, styles: const PosStyles(align: PosAlign.center));
    bytes += g.hr();
    bytes += g.text('POSTE PAPETERIE / POS', styles: const PosStyles(bold: true));
    bytes += g.text('Nb ventes: $posSalesCount');
    bytes += g.text('CA: ${_money(posRevenue, company)}');
    bytes += g.hr();
    bytes += g.text('POSTE SOINS & BEAUTÉ', styles: const PosStyles(bold: true));
    bytes += g.text('Nb ventes: $beautySalesCount');
    bytes += g.text('CA: ${_money(beautyRevenue, company)}');
    bytes += g.hr();
    bytes += g.text('POSTE IMPRESSION', styles: const PosStyles(bold: true));
    bytes += g.text('Nb ventes: $printSalesCount');
    bytes += g.text('CA: ${_money(printRevenue, company)}');
    bytes += g.hr();
    bytes += g.text('TOTAL CONSOLIDÉ', styles: const PosStyles(bold: true));
    final total = posRevenue + beautyRevenue + printRevenue;
    bytes += g.text('CA TOTAL JOUR: ${_money(total, company)}', styles: const PosStyles(bold: true));
    bytes += g.text('Nb ventes totales: ${posSalesCount + beautySalesCount + printSalesCount}');
    bytes += g.text('Paiements:');
    bytes += g.text(' - Espèces: ${_money(paymentsByMethod[PaymentMethod.especes] ?? 0, company)}');
    bytes += g.text(' - Carte: ${_money(paymentsByMethod[PaymentMethod.carte] ?? 0, company)}');
    bytes += g.text(' - Mobile: ${_money(paymentsByMethod[PaymentMethod.mobile] ?? 0, company)}');
    bytes += g.hr();
    bytes += g.text('Édité le ${DateFormatter.dateTime(DateTime.now())}');
    bytes += g.text('Par: $editedBy');
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }

  Future<void> printDailyReport({
    required CompanySettingsModel company,
    required String periodLabel,
    required int posSalesCount,
    required double posRevenue,
    required int beautySalesCount,
    required double beautyRevenue,
    required int printSalesCount,
    required double printRevenue,
    required Map<PaymentMethod, double> paymentsByMethod,
    required String editedBy,
  }) async {
    await printBytes(await buildDailyReport(
      company: company,
      periodLabel: periodLabel,
      posSalesCount: posSalesCount,
      posRevenue: posRevenue,
      beautySalesCount: beautySalesCount,
      beautyRevenue: beautyRevenue,
      printSalesCount: printSalesCount,
      printRevenue: printRevenue,
      paymentsByMethod: paymentsByMethod,
      editedBy: editedBy,
    ));
  }

  // ─────────────────────── Rapport personnel (non-admin) ───────────────────────
  /// Version allégée du rapport de caisse pour le personnel qui n'a que
  /// [Permission.reportsViewOwn] (vendeur, caissier, beautician, imprimeur) :
  /// juste ses propres ventes, sans détail par poste ni consolidé.
  Future<List<int>> buildPersonalReport({
    required CompanySettingsModel company,
    required String periodLabel,
    required String sellerName,
    required int salesCount,
    required double totalRevenue,
    required List<({String title, double qty})> topItems,
    required Map<PaymentMethod, double> paymentsByMethod,
  }) async {
    final (g, initial) = await _newTicket();
    List<int> bytes = initial;
    bytes += g.text(company.name, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += g.text('MON RAPPORT', styles: const PosStyles(align: PosAlign.center));
    bytes += g.text(periodLabel, styles: const PosStyles(align: PosAlign.center));
    bytes += g.hr();
    bytes += g.text('Employé: $sellerName');
    bytes += g.text('Nb ventes: $salesCount');
    bytes += g.text('CA TOTAL: ${_money(totalRevenue, company)}', styles: const PosStyles(bold: true));
    if (topItems.isNotEmpty) {
      bytes += g.hr();
      bytes += g.text('TOP ARTICLES/SERVICES', styles: const PosStyles(bold: true));
      for (final item in topItems) {
        bytes += g.row([
          PosColumn(text: item.title, width: 8),
          PosColumn(text: QtyFormatter.plain(item.qty), width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
    }
    bytes += g.hr();
    bytes += g.text('Paiements:');
    bytes += g.text(' - Espèces: ${_money(paymentsByMethod[PaymentMethod.especes] ?? 0, company)}');
    bytes += g.text(' - Carte: ${_money(paymentsByMethod[PaymentMethod.carte] ?? 0, company)}');
    bytes += g.text(' - Mobile: ${_money(paymentsByMethod[PaymentMethod.mobile] ?? 0, company)}');
    bytes += g.hr();
    bytes += g.text('Édité le ${DateFormatter.dateTime(DateTime.now())}');
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }

  Future<void> printPersonalReport({
    required CompanySettingsModel company,
    required String periodLabel,
    required String sellerName,
    required int salesCount,
    required double totalRevenue,
    required List<({String title, double qty})> topItems,
    required Map<PaymentMethod, double> paymentsByMethod,
  }) async {
    await printBytes(await buildPersonalReport(
      company: company,
      periodLabel: periodLabel,
      sellerName: sellerName,
      salesCount: salesCount,
      totalRevenue: totalRevenue,
      topItems: topItems,
      paymentsByMethod: paymentsByMethod,
    ));
  }

  Future<List<int>> buildTestTicket(CompanySettingsModel company) async {
    final (g, initial) = await _newTicket();
    List<int> bytes = initial;
    bytes += g.text(company.name, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += g.text('TEST IMPRIMANTE', styles: const PosStyles(align: PosAlign.center));
    bytes += g.hr();
    bytes += g.text('Si vous lisez ceci, la connexion');
    bytes += g.text("à l'imprimante fonctionne correctement.");
    bytes += g.text(DateFormatter.dateTime(DateTime.now()));
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }

  Future<void> printTestTicket(CompanySettingsModel company) async {
    await printBytes(await buildTestTicket(company));
  }

  String _paymentLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.especes:
        return 'Espèces';
      case PaymentMethod.carte:
        return 'Carte';
      case PaymentMethod.mobile:
        return 'Mobile';
    }
  }

  // ─────────────────────────── Transport ───────────────────────────
  Future<void> printBytes(List<int> bytes) async {
    if (kIsWeb) {
      throw const PrinterException(
        "Impression non disponible sur le web : le navigateur ne peut pas se connecter "
        "directement à une imprimante USB/Réseau. Utilisez l'application mobile ou desktop.",
      );
    }
    final config = _settingsRepo.printer;
    if (!config.isConfigured) {
      throw const PrinterException('Aucune imprimante configurée. Allez dans Paramètres imprimante.');
    }
    switch (config.connectionType!) {
      case PrinterConnectionType.network:
        await _printNetwork(config, bytes);
        break;
      case PrinterConnectionType.usb:
        await _printUsb(config, bytes);
        break;
      case PrinterConnectionType.sunmiIntegrated:
        await _printSunmi(bytes);
        break;
      case PrinterConnectionType.mobiPrintIntegrated:
        await _printMobiPrint(bytes);
        break;
    }
  }

  /// Sonde si le pilote imprimante intégré (voir [MobiPrintChannel]) est
  /// disponible sur ce terminal — utilisé pour la détection automatique
  /// dans l'écran de configuration imprimante plutôt que de forcer une
  /// sélection manuelle.
  Future<bool> isMobiPrintAvailable() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return MobiPrintChannel.isAvailable();
  }

  Future<void> _printMobiPrint(List<int> bytes) async {
    if (kIsWeb) {
      throw const PrinterException(
        "Impression non disponible sur le web : le navigateur ne peut pas parler au pilote "
        "imprimante intégré. Utilisez l'application Android.",
      );
    }
    if (!Platform.isAndroid) {
      throw const PrinterException(
        "L'imprimante intégrée (MobiPrint) n'est disponible que sur un terminal Android compatible.",
      );
    }
    try {
      await MobiPrintChannel.printBytes(bytes);
    } on PlatformException catch (e) {
      throw PrinterException("Impression sur l'imprimante intégrée impossible : ${e.message}");
    }
  }

  Future<void> _printNetwork(PrinterConfigModel config, List<int> bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        config.address!,
        config.port ?? 9100,
        timeout: const Duration(seconds: 8),
      );
      socket.add(bytes);
      await socket.flush();
    } on SocketException catch (e) {
      throw PrinterException("Connexion à l'imprimante réseau impossible : ${e.message}");
    } finally {
      socket?.destroy();
    }
  }

  /// Imprime via USB générique (câble USB, ou module thermique interne câblé
  /// en USB d'un terminal Android tout-en-un non-Sunmi). [config.address]
  /// contient l'identifiant du périphérique renvoyé par [scanUsbPrinters]
  /// (format `vendorId:productId` sur Android, port série sur desktop).
  Future<void> _printUsb(PrinterConfigModel config, List<int> bytes) async {
    if (config.address == null || config.address!.isEmpty) {
      throw const PrinterException(
        "Aucune imprimante USB sélectionnée. Allez dans Paramètres imprimante pour la détecter.",
      );
    }
    final manager = usb_printer.PrinterManager();
    try {
      final device = usb_printer.UsbPrinterDevice(
        name: config.deviceName ?? 'Imprimante USB',
        identifier: config.address!,
        usbPlatform: Platform.isAndroid ? usb_printer.UsbPlatform.android : usb_printer.UsbPlatform.desktop,
      );
      await manager.connect(device);
      await manager.printBytes(bytes);
      await manager.waitWriteComplete();
    } on usb_printer.PrinterException catch (e) {
      throw PrinterException("Impression USB impossible : ${e.message}");
    } finally {
      await manager.dispose();
    }
  }

  /// Détecte les imprimantes USB branchées (voir README du plugin : classe
  /// USB Printer 0x07 ou puce série FTDI/CP210x/CH34x — couvre la quasi
  /// totalité des imprimantes thermiques ESC/POS, y compris le module
  /// interne de la plupart des terminaux Android génériques). Utilisé par
  /// l'écran de configuration imprimante pour proposer une liste à choisir
  /// plutôt qu'une adresse à saisir à la main.
  Future<List<usb_printer.UsbPrinterDevice>> scanUsbPrinters() async {
    final manager = usb_printer.PrinterManager();
    try {
      final devices = await manager.scanPrinters(
        types: const {usb_printer.PrinterConnectionType.usb},
        timeout: const Duration(seconds: 5),
      );
      return devices.whereType<usb_printer.UsbPrinterDevice>().toList();
    } on usb_printer.PrinterException catch (e) {
      throw PrinterException('Détection USB impossible : ${e.message}');
    } finally {
      await manager.dispose();
    }
  }

  Future<void> _printSunmi(List<int> bytes) async {
    if (!Platform.isAndroid) {
      throw const PrinterException(
        "L'imprimante intégrée Sunmi n'est disponible que sur un terminal Android Sunmi.",
      );
    }
    try {
      await SunmiPrinter.printEscPos(bytes);
    } catch (e) {
      throw PrinterException("Impression sur l'imprimante intégrée impossible : $e");
    }
  }
}
