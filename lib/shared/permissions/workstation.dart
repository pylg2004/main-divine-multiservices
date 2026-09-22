import 'package:flutter/material.dart';

import '../../data/models/enums.dart';

/// Le poste de travail n'est JAMAIS choisi directement par l'utilisateur :
/// il est toujours dérivé de son [UserRole] à la connexion.
extension WorkstationExtension on UserRole {
  Workstation get workstation {
    switch (this) {
      case UserRole.superAdmin:
      case UserRole.admin:
      case UserRole.manager:
        return Workstation.admin;
      case UserRole.vendeur:
      case UserRole.caissier:
        return Workstation.pos;
      case UserRole.beautician:
        return Workstation.beauty;
      case UserRole.imprimeur:
        return Workstation.impression;
      case UserRole.vendeurGeneral:
        return Workstation.general;
      case UserRole.vendeurBoisson:
        return Workstation.boisson;
    }
  }
}

/// Départements concrets qu'un admin peut cocher/décocher pour un compte
/// vendeur (voir UserModel.departments) — Administration et Vente Générale
/// ne sont pas des cases à cocher : Administration est un rôle de gestion à
/// part, et Vente Générale équivaut à cocher les 4 cases ci-dessous.
const kAssignableDepartments = [
  Workstation.pos,
  Workstation.beauty,
  Workstation.impression,
  Workstation.boisson,
];

/// Ordre de priorité utilisé pour choisir le poste "principal" (couleur de
/// la barre d'app, tableau de bord d'accueil) quand un compte a plusieurs
/// départements assignés.
const kDepartmentOrder = [
  Workstation.pos,
  Workstation.beauty,
  Workstation.impression,
  Workstation.boisson,
  Workstation.general,
  Workstation.admin,
];

extension UserRoleAssignment on UserRole {
  /// Rôles "vendeur" dont les départements peuvent être personnalisés
  /// (plusieurs rayons à la fois) — par opposition aux rôles de gestion
  /// (superAdmin/admin/manager), toujours rattachés au poste Administration.
  bool get isDepartmentAssignable {
    switch (this) {
      case UserRole.superAdmin:
      case UserRole.admin:
      case UserRole.manager:
        return false;
      case UserRole.vendeur:
      case UserRole.caissier:
      case UserRole.beautician:
      case UserRole.imprimeur:
      case UserRole.vendeurGeneral:
      case UserRole.vendeurBoisson:
        return true;
    }
  }
}

extension WorkstationInfo on Workstation {
  String get label {
    switch (this) {
      case Workstation.pos:
        return 'Papeterie / POS';
      case Workstation.beauty:
        return 'Soins & Beauté';
      case Workstation.admin:
        return 'Administration';
      case Workstation.impression:
        return 'Impression';
      case Workstation.general:
        return 'Vente Générale';
      case Workstation.boisson:
        return 'Boissons';
    }
  }

  Color get color {
    switch (this) {
      case Workstation.pos:
        return const Color(0xFF0F5A42);
      case Workstation.beauty:
        return const Color(0xFFD4788F);
      case Workstation.admin:
        return const Color(0xFF2D6CDF);
      case Workstation.impression:
        return const Color(0xFFE08A2E);
      case Workstation.general:
        return const Color(0xFF7C3AED);
      case Workstation.boisson:
        return const Color(0xFF0EA5B7);
    }
  }

  IconData get icon {
    switch (this) {
      case Workstation.pos:
        return Icons.storefront;
      case Workstation.beauty:
        return Icons.spa;
      case Workstation.admin:
        return Icons.admin_panel_settings;
      case Workstation.impression:
        return Icons.local_printshop_outlined;
      case Workstation.general:
        return Icons.shopping_bag_outlined;
      case Workstation.boisson:
        return Icons.local_drink_outlined;
    }
  }

  String get homeRoute {
    switch (this) {
      case Workstation.pos:
        return '/dashboard/pos';
      case Workstation.beauty:
        return '/dashboard/beauty';
      case Workstation.admin:
        return '/dashboard/admin';
      case Workstation.impression:
        return '/dashboard/impression';
      case Workstation.general:
        return '/dashboard/general';
      case Workstation.boisson:
        return '/dashboard/boisson';
    }
  }
}

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Administrateur';
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.manager:
        return 'Gestionnaire';
      case UserRole.vendeur:
        return 'Vendeur';
      case UserRole.caissier:
        return 'Caissier';
      case UserRole.beautician:
        return 'Beautician';
      case UserRole.imprimeur:
        return 'Imprimeur';
      case UserRole.vendeurGeneral:
        return 'Vendeur Général';
      case UserRole.vendeurBoisson:
        return 'Vendeur Boissons';
    }
  }
}
