import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart' as usb_printer;

import '../../data/models/client_model.dart';
import '../../data/models/company_settings_model.dart';
import '../../data/models/enums.dart';
import '../../data/models/printer_config_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/repositories/settings_repository.dart';
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
/// imprimante via un pilote noyau texte brut (pas d'ESC/POS) — voir
/// [MobiPrintChannel] et les méthodes printXxx (printSaleReceipt,
/// printClientCard...) qui basculent automatiquement vers ce canal texte
/// au lieu de buildXxx+printBytes quand ce type est configuré.
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

  String _money(num amount, CompanySettingsModel company) =>
      MoneyFormatter.format(amount, symbol: company.currencySymbol);

  // ─────────────────────────── Tickets de vente ───────────────────────────
  // Couvre les 3 formats du spec §9 (POS / Beauté / Mixte) : la structure
  // est identique, seuls l'en-tête, le libellé de colonne et le pied
  // changent selon le poste de la vente.
  Future<List<int>> buildSaleReceipt({
    required SaleModel sale,
    required CompanySettingsModel company,
  }) async {
    final g = await _generator();
    List<int> bytes = [];

    final isPos = sale.workstation == Workstation.pos;
    final isBeauty = sale.workstation == Workstation.beauty;
    final isImpression = sale.workstation == Workstation.impression;
    final isSinglePoste = isPos || isBeauty || isImpression;

    bytes += g.text(
      company.name,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    if (isPos) {
      bytes += g.text('Papeterie · Livres · Tissus', styles: const PosStyles(align: PosAlign.center));
    } else if (isBeauty) {
      bytes += g.text('STUDIO DE BEAUTÉ', styles: const PosStyles(align: PosAlign.center));
    } else if (isImpression) {
      bytes += g.text('SERVICES D\'IMPRESSION', styles: const PosStyles(align: PosAlign.center));
    } else {
      bytes += g.text('Papeterie · Beauté · Impression', styles: const PosStyles(align: PosAlign.center));
    }
    if (company.phone != null && company.phone!.isNotEmpty) {
      bytes += g.text('Tél: ${company.phone}', styles: const PosStyles(align: PosAlign.center));
    }
    bytes += g.hr();

    bytes += g.text('Reçu N°: ${sale.id}');
    bytes += g.text('Date: ${DateFormatter.dateTime(sale.date)}');
    bytes += g.text('Client: ${sale.clientName}');
    if (sale.clientPhone.isNotEmpty) bytes += g.text('Tél: ${sale.clientPhone}');
    bytes += g.text(
      'Servi par: ${sale.sellerName}${isSinglePoste ? '' : ' (${sale.workstation.name})'}',
    );
    bytes += g.hr();

    bytes += g.row([
      PosColumn(text: isBeauty || isImpression ? 'Service' : 'Article', width: 6),
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
    bytes += g.text(
      isBeauty ? 'Merci de votre confiance !' : 'Merci de votre visite !',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }

  /// Point d'entrée unique pour imprimer un reçu de vente : bascule vers le
  /// canal texte MobiPrint si configuré (celui-ci ne comprend pas l'ESC/POS
  /// des [buildSaleReceipt]), sinon flux ESC/POS classique. Les écrans
  /// appelants utilisent cette méthode plutôt que build+printBytes
  /// directement pour ne pas avoir à connaître ce détail de transport.
  Future<void> printSaleReceipt({required SaleModel sale, required CompanySettingsModel company}) async {
    if (_isMobiPrint) {
      await _printMobiPrintText(_saleReceiptText(sale: sale, company: company));
      return;
    }
    await printBytes(await buildSaleReceipt(sale: sale, company: company));
  }

  String _saleReceiptText({required SaleModel sale, required CompanySettingsModel company}) {
    final isPos = sale.workstation == Workstation.pos;
    final isBeauty = sale.workstation == Workstation.beauty;
    final isImpression = sale.workstation == Workstation.impression;
    final isSinglePoste = isPos || isBeauty || isImpression;

    final b = StringBuffer();
    b.writeln(company.name);
    if (isPos) {
      b.writeln('Papeterie . Livres . Tissus');
    } else if (isBeauty) {
      b.writeln('STUDIO DE BEAUTE');
    } else if (isImpression) {
      b.writeln("SERVICES D'IMPRESSION");
    } else {
      b.writeln('Papeterie . Beaute . Impression');
    }
    if (company.phone != null && company.phone!.isNotEmpty) b.writeln('Tel: ${company.phone}');
    b.writeln(_hrText());
    b.writeln('Recu N: ${sale.id}');
    b.writeln('Date: ${DateFormatter.dateTime(sale.date)}');
    b.writeln('Client: ${sale.clientName}');
    if (sale.clientPhone.isNotEmpty) b.writeln('Tel: ${sale.clientPhone}');
    b.writeln('Servi par: ${sale.sellerName}${isSinglePoste ? '' : ' (${sale.workstation.name})'}');
    b.writeln(_hrText());
    for (final item in sale.items) {
      b.writeln(item.title);
      final qty = QtyFormatter.format(item.qty, fractional: QtyFormatter.isFractionalUnit(item.unit));
      b.writeln(_padCols('  x$qty', _money(item.sum, company)));
    }
    b.writeln(_hrText());
    b.writeln(_padCols('Sous-total', _money(sale.subtotal, company)));
    if (sale.discount > 0) b.writeln(_padCols('Remise', '-${_money(sale.discount, company)}'));
    b.writeln(_padCols('TOTAL', _money(sale.total, company)));
    b.writeln('Paiement: ${_paymentLabel(sale.paymentMethod)}');
    b.writeln(_hrText());
    b.writeln(isBeauty ? 'Merci de votre confiance !' : 'Merci de votre visite !');
    return b.toString();
  }

  // ─────────────────────────── Fiche client ───────────────────────────
  Future<List<int>> buildClientCard({
    required ClientModel client,
    required CompanySettingsModel company,
    required List<SaleModel> recentSales,
  }) async {
    final g = await _generator();
    List<int> bytes = [];
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
    if (_isMobiPrint) {
      await _printMobiPrintText(_clientCardText(client: client, company: company, recentSales: recentSales));
      return;
    }
    await printBytes(await buildClientCard(client: client, company: company, recentSales: recentSales));
  }

  String _clientCardText({
    required ClientModel client,
    required CompanySettingsModel company,
    required List<SaleModel> recentSales,
  }) {
    final b = StringBuffer();
    b.writeln(company.name);
    b.writeln('FICHE CLIENT');
    b.writeln(_hrText());
    b.writeln('Nom: ${client.fullName}');
    b.writeln('Tel: ${client.phone}');
    if (client.email != null && client.email!.isNotEmpty) b.writeln('Email: ${client.email}');
    b.writeln('Client depuis: ${DateFormatter.date(client.createdAt)}');
    b.writeln(_hrText());
    b.writeln('STATISTIQUES');
    b.writeln('Total depense: ${_money(client.totalSpent, company)}');
    b.writeln('Points fidelite: ${client.loyaltyPoints}');
    b.writeln('Nb visites: ${recentSales.length}');
    if (client.lastVisit != null) b.writeln('Derniere visite: ${DateFormatter.date(client.lastVisit!)}');
    b.writeln(_hrText());
    b.writeln('DERNIERES VISITES');
    for (final sale in recentSales.take(5)) {
      b.writeln(_padCols(DateFormatter.date(sale.date), _money(sale.total, company)));
    }
    if (client.notes != null && client.notes!.isNotEmpty) {
      b.writeln(_hrText());
      b.writeln('NOTES / PREFERENCES');
      b.writeln(client.notes!);
    }
    return b.toString();
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
    final g = await _generator();
    List<int> bytes = [];
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
    if (_isMobiPrint) {
      await _printMobiPrintText(_dailyReportText(
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
      return;
    }
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

  String _dailyReportText({
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
  }) {
    final b = StringBuffer();
    b.writeln(company.name);
    b.writeln('RAPPORT DE CAISSE');
    b.writeln(periodLabel);
    b.writeln(_hrText());
    b.writeln('POSTE PAPETERIE / POS');
    b.writeln('Nb ventes: $posSalesCount');
    b.writeln('CA: ${_money(posRevenue, company)}');
    b.writeln(_hrText());
    b.writeln('POSTE SOINS & BEAUTE');
    b.writeln('Nb ventes: $beautySalesCount');
    b.writeln('CA: ${_money(beautyRevenue, company)}');
    b.writeln(_hrText());
    b.writeln('POSTE IMPRESSION');
    b.writeln('Nb ventes: $printSalesCount');
    b.writeln('CA: ${_money(printRevenue, company)}');
    b.writeln(_hrText());
    b.writeln('TOTAL CONSOLIDE');
    final total = posRevenue + beautyRevenue + printRevenue;
    b.writeln('CA TOTAL JOUR: ${_money(total, company)}');
    b.writeln('Nb ventes totales: ${posSalesCount + beautySalesCount + printSalesCount}');
    b.writeln('Paiements:');
    b.writeln(' - Especes: ${_money(paymentsByMethod[PaymentMethod.especes] ?? 0, company)}');
    b.writeln(' - Carte: ${_money(paymentsByMethod[PaymentMethod.carte] ?? 0, company)}');
    b.writeln(' - Mobile: ${_money(paymentsByMethod[PaymentMethod.mobile] ?? 0, company)}');
    b.writeln(_hrText());
    b.writeln('Edite le ${DateFormatter.dateTime(DateTime.now())}');
    b.writeln('Par: $editedBy');
    return b.toString();
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
    final g = await _generator();
    List<int> bytes = [];
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
    if (_isMobiPrint) {
      await _printMobiPrintText(_personalReportText(
        company: company,
        periodLabel: periodLabel,
        sellerName: sellerName,
        salesCount: salesCount,
        totalRevenue: totalRevenue,
        topItems: topItems,
        paymentsByMethod: paymentsByMethod,
      ));
      return;
    }
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

  String _personalReportText({
    required CompanySettingsModel company,
    required String periodLabel,
    required String sellerName,
    required int salesCount,
    required double totalRevenue,
    required List<({String title, double qty})> topItems,
    required Map<PaymentMethod, double> paymentsByMethod,
  }) {
    final b = StringBuffer();
    b.writeln(company.name);
    b.writeln('MON RAPPORT');
    b.writeln(periodLabel);
    b.writeln(_hrText());
    b.writeln('Employe: $sellerName');
    b.writeln('Nb ventes: $salesCount');
    b.writeln('CA TOTAL: ${_money(totalRevenue, company)}');
    if (topItems.isNotEmpty) {
      b.writeln(_hrText());
      b.writeln('TOP ARTICLES/SERVICES');
      for (final item in topItems) {
        b.writeln(_padCols(item.title, QtyFormatter.plain(item.qty)));
      }
    }
    b.writeln(_hrText());
    b.writeln('Paiements:');
    b.writeln(' - Especes: ${_money(paymentsByMethod[PaymentMethod.especes] ?? 0, company)}');
    b.writeln(' - Carte: ${_money(paymentsByMethod[PaymentMethod.carte] ?? 0, company)}');
    b.writeln(' - Mobile: ${_money(paymentsByMethod[PaymentMethod.mobile] ?? 0, company)}');
    b.writeln(_hrText());
    b.writeln('Edite le ${DateFormatter.dateTime(DateTime.now())}');
    return b.toString();
  }

  Future<List<int>> buildTestTicket(CompanySettingsModel company) async {
    final g = await _generator();
    List<int> bytes = [];
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
    if (_isMobiPrint) {
      await _printMobiPrintText(_testTicketText(company));
      return;
    }
    await printBytes(await buildTestTicket(company));
  }

  String _testTicketText(CompanySettingsModel company) {
    final b = StringBuffer();
    b.writeln(company.name);
    b.writeln('TEST IMPRIMANTE');
    b.writeln(_hrText());
    b.writeln('Si vous lisez ceci, la connexion');
    b.writeln("a l'imprimante fonctionne correctement.");
    b.writeln(DateFormatter.dateTime(DateTime.now()));
    return b.toString();
  }

  static const _mobiPrintWidth = 32;

  String _padCols(String left, String right, {int width = _mobiPrintWidth}) {
    final space = width - right.length;
    if (space <= 0) return right;
    final l = left.length >= space ? left.substring(0, space - 1) : left;
    return l.padRight(space) + right;
  }

  String _hrText([int width = _mobiPrintWidth]) => ''.padRight(width, '-');

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
        // Ce transport ne comprend pas l'ESC/POS : les écrans appelants
        // doivent utiliser printSaleReceipt/printClientCard/etc. (qui
        // basculent vers _printMobiPrintText), jamais buildXxx+printBytes.
        throw const PrinterException(
          "Erreur interne : ce type d'imprimante utilise un canal texte dédié, pas printBytes.",
        );
    }
  }

  bool get _isMobiPrint =>
      !kIsWeb && _settingsRepo.printer.connectionType == PrinterConnectionType.mobiPrintIntegrated;

  /// Sonde si le pilote imprimante intégré (voir [MobiPrintChannel]) est
  /// disponible sur ce terminal — utilisé pour la détection automatique
  /// dans l'écran de configuration imprimante plutôt que de forcer une
  /// sélection manuelle.
  Future<bool> isMobiPrintAvailable() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return MobiPrintChannel.isAvailable();
  }

  Future<void> _printMobiPrintText(String text) async {
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
      await MobiPrintChannel.printText(text);
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
