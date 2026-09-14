import 'package:flutter_test/flutter_test.dart';
import 'package:main_divine_multiservices/data/models/enums.dart';
import 'package:main_divine_multiservices/shared/permissions/permission.dart';
import 'package:main_divine_multiservices/shared/permissions/permission_service.dart';
import 'package:main_divine_multiservices/shared/permissions/workstation.dart';

void main() {
  group('Dérivation du poste de travail (spec §3)', () {
    test('superAdmin, admin et manager -> poste Administration', () {
      expect(UserRole.superAdmin.workstation, Workstation.admin);
      expect(UserRole.admin.workstation, Workstation.admin);
      expect(UserRole.manager.workstation, Workstation.admin);
    });

    test('vendeur et caissier -> poste Papeterie / POS', () {
      expect(UserRole.vendeur.workstation, Workstation.pos);
      expect(UserRole.caissier.workstation, Workstation.pos);
    });

    test('beautician -> poste Soins & Beauté', () {
      expect(UserRole.beautician.workstation, Workstation.beauty);
    });
  });

  group('Matrice des permissions (spec §6)', () {
    test('seul le Super Admin peut supprimer une vente', () {
      for (final role in UserRole.values) {
        final expected = role == UserRole.superAdmin;
        expect(PermissionService.has(role, Permission.salesDelete), expected, reason: role.name);
      }
    });

    test('vendeur et beautician ne voient que leurs propres ventes', () {
      expect(PermissionService.has(UserRole.vendeur, Permission.salesViewOwn), true);
      expect(PermissionService.has(UserRole.vendeur, Permission.salesViewAll), false);
      expect(PermissionService.has(UserRole.beautician, Permission.salesViewOwn), true);
      expect(PermissionService.has(UserRole.beautician, Permission.salesViewAll), false);
    });

    test('caissier voit toutes les ventes POS mais ne peut ni annuler ni modifier', () {
      expect(PermissionService.has(UserRole.caissier, Permission.salesViewAll), true);
      expect(PermissionService.has(UserRole.caissier, Permission.salesCancel), false);
      expect(PermissionService.has(UserRole.caissier, Permission.salesEdit), false);
    });

    test('seuls superAdmin, admin et manager gèrent le catalogue beauté', () {
      expect(PermissionService.has(UserRole.manager, Permission.beautyServicesCreateEdit), true);
      expect(PermissionService.has(UserRole.vendeur, Permission.beautyServicesCreateEdit), false);
      expect(PermissionService.has(UserRole.beautician, Permission.beautyServicesCreateEdit), false);
    });

    test('seul le Super Admin gère les utilisateurs et les paramètres', () {
      for (final role in UserRole.values) {
        final expected = role == UserRole.superAdmin;
        expect(PermissionService.has(role, Permission.usersManage), expected, reason: role.name);
        expect(PermissionService.has(role, Permission.settingsManage), expected, reason: role.name);
      }
    });

    test('seuls superAdmin et admin voient le rapport consolidé', () {
      expect(PermissionService.has(UserRole.superAdmin, Permission.reportsViewConsolidated), true);
      expect(PermissionService.has(UserRole.admin, Permission.reportsViewConsolidated), true);
      expect(PermissionService.has(UserRole.manager, Permission.reportsViewConsolidated), false);
    });
  });
}
