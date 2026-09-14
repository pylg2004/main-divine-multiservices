import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/client_model.dart';
import '../../data/models/company_settings_model.dart';
import '../../data/models/enums.dart';
import '../../data/models/printer_config_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/repositories/settings_repository.dart';
import '../errors/app_exception.dart';
import '../utils/date_formatter.dart';
import '../utils/money_formatter.dart';

/// Construit les tickets ESC/POS (spec §9) et les envoie directement à
/// l'imprimante configurée — jamais de PDF (règle §5 du prompt).
///
/// Le Bluetooth n'est pas proposé : la seule lib BLE cross-platform viable
/// (flutter_blue_plus) impose une licence commerciale payante pour tout usage
/// par une entreprise à but lucratif — refusé pour ce projet. Réseau
/// (WiFi/Ethernet) est donc le transport principal ; USB reste un placeholder
/// (voir printBytes).
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

    bytes += g.text(
      company.name,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    if (isPos) {
      bytes += g.text('Papeterie · Livres · Tissus', styles: const PosStyles(align: PosAlign.center));
    } else if (isBeauty) {
      bytes += g.text('STUDIO DE BEAUTÉ', styles: const PosStyles(align: PosAlign.center));
    } else {
      bytes += g.text('Papeterie · Beauté · Multiservices', styles: const PosStyles(align: PosAlign.center));
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
      'Servi par: ${sale.sellerName}${isPos || isBeauty ? '' : ' (${sale.workstation.name})'}',
    );
    bytes += g.hr();

    bytes += g.row([
      PosColumn(text: isBeauty ? 'Service' : 'Article', width: 6),
      PosColumn(text: 'Qté', width: 2, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: 'Total', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += g.hr(ch: '-');
    for (final item in sale.items) {
      bytes += g.row([
        PosColumn(text: item.title, width: 6),
        PosColumn(text: '${item.qty}', width: 2, styles: const PosStyles(align: PosAlign.center)),
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

  // ─────────────────────── Rapport de caisse journalier ───────────────────────
  Future<List<int>> buildDailyReport({
    required CompanySettingsModel company,
    required String periodLabel,
    required int posSalesCount,
    required double posRevenue,
    required int beautySalesCount,
    required double beautyRevenue,
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
    bytes += g.text('TOTAL CONSOLIDÉ', styles: const PosStyles(bold: true));
    final total = posRevenue + beautyRevenue;
    bytes += g.text('CA TOTAL JOUR: ${_money(total, company)}', styles: const PosStyles(bold: true));
    bytes += g.text('Nb ventes totales: ${posSalesCount + beautySalesCount}');
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
        throw const PrinterException(
          "L'impression USB directe n'est pas encore disponible dans cette version. "
          'Utilisez une connexion Réseau (WiFi/Ethernet).',
        );
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

}
