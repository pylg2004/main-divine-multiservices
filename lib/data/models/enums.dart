import 'package:hive/hive.dart';

part 'enums.g.dart';

/// Rôle attribué à un utilisateur. Détermine automatiquement son poste de
/// travail via [WorkstationExtension.workstation] (shared/permissions).
@HiveType(typeId: 20)
enum UserRole {
  @HiveField(0)
  superAdmin,
  @HiveField(1)
  admin,
  @HiveField(2)
  manager,
  @HiveField(3)
  vendeur,
  @HiveField(4)
  caissier,
  @HiveField(5)
  beautician,
  @HiveField(6)
  imprimeur,
}

/// Poste de travail — jamais choisi directement par l'utilisateur, toujours
/// dérivé de son [UserRole].
@HiveType(typeId: 21)
enum Workstation {
  @HiveField(0)
  pos,
  @HiveField(1)
  beauty,
  @HiveField(2)
  admin,
  @HiveField(3)
  impression,
}

@HiveType(typeId: 22)
enum ProductCategory {
  @HiveField(0)
  papeterie,
  @HiveField(1)
  tissu,
  @HiveField(2)
  livre,
}

@HiveType(typeId: 23)
enum BeautyServiceCategory {
  @HiveField(0)
  coiffure,
  @HiveField(1)
  esthetique,
  @HiveField(2)
  onglerie,
  @HiveField(3)
  maquillage,
  @HiveField(4)
  soins,
  @HiveField(5)
  autre,
}

@HiveType(typeId: 24)
enum SaleItemType {
  @HiveField(0)
  product,
  @HiveField(1)
  beautyService,
  @HiveField(2)
  printService,
}

/// Catégories libres : "Impression" couvre le travail générique, les autres
/// valeurs les cas mentionnés explicitement (flyers, services informatiques).
/// [PrintServiceModel.description] reste le champ texte libre pour préciser
/// une commande particulière.
@HiveType(typeId: 29)
enum PrintServiceCategory {
  @HiveField(0)
  impression,
  @HiveField(1)
  flyers,
  @HiveField(2)
  cartesDeVisite,
  @HiveField(3)
  affiches,
  @HiveField(4)
  servicesInformatiques,
  @HiveField(5)
  autre,
}

@HiveType(typeId: 25)
enum SaleStatus {
  @HiveField(0)
  complete,
  @HiveField(1)
  annulee,
}

@HiveType(typeId: 26)
enum PaymentMethod {
  @HiveField(0)
  especes,
  @HiveField(1)
  carte,
  @HiveField(2)
  mobile,
}

/// Le Bluetooth n'est volontairement pas proposé : la lib BLE cross-platform
/// (flutter_blue_plus) impose une licence commerciale payante pour tout
/// usage par une entreprise à but lucratif, ce que l'utilisateur a refusé.
/// Réseau (WiFi/Ethernet) est donc le transport recommandé.
@HiveType(typeId: 27)
enum PrinterConnectionType {
  @HiveField(0)
  network,
  @HiveField(1)
  usb,
}

@HiveType(typeId: 28)
enum PrinterPaperWidth {
  @HiveField(0)
  mm58,
  @HiveField(1)
  mm80,
}
