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
    }
  }
}
