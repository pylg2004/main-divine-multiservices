/// Rôle attribué à un utilisateur. Détermine automatiquement son poste de
/// travail via [WorkstationExtension.workstation] (shared/permissions).
enum UserRole {
  superAdmin,
  admin,
  manager,
  vendeur,
  caissier,
  beautician,
  imprimeur,
  /// Vendeur polyvalent : vend indifféremment produits (papeterie, tissu,
  /// boissons...), services beauté et services impression depuis une
  /// caisse unifiée — sans les permissions de gestion de l'Administrateur.
  vendeurGeneral,
  /// Vendeur dédié aux boissons uniquement (catégorie Boisson) — même
  /// principe que Vendeur (papeterie) ou Beautician, mais pour ce rayon.
  vendeurBoisson,
}

/// Poste de travail — jamais choisi directement par l'utilisateur, toujours
/// dérivé de son [UserRole].
enum Workstation {
  pos,
  beauty,
  admin,
  impression,
  general,
  boisson,
}

enum ProductCategory {
  papeterie,
  tissu,
  livre,
  boisson,
}

enum BeautyServiceCategory {
  coiffure,
  esthetique,
  onglerie,
  maquillage,
  soins,
  autre,
}

enum SaleItemType {
  product,
  beautyService,
  printService,
}

/// Catégories libres : "Impression" couvre le travail générique, les autres
/// valeurs les cas mentionnés explicitement (flyers, services informatiques).
/// [PrintServiceModel.description] reste le champ texte libre pour préciser
/// une commande particulière.
enum PrintServiceCategory {
  impression,
  flyers,
  cartesDeVisite,
  affiches,
  servicesInformatiques,
  autre,
}

enum SaleStatus {
  complete,
  annulee,
}

enum PaymentMethod {
  especes,
  carte,
  mobile,
}

/// Le Bluetooth n'est volontairement pas proposé : la lib BLE cross-platform
/// (flutter_blue_plus) impose une licence commerciale payante pour tout
/// usage par une entreprise à but lucratif, ce que l'utilisateur a refusé.
/// Réseau (WiFi/Ethernet) est donc le transport recommandé.
enum PrinterConnectionType {
  network,
  /// Imprimante USB générique (câble, ou imprimante intégrée d'un terminal
  /// tout-en-un dont le module thermique est câblé en USB interne — le cas
  /// de la plupart des terminaux Android génériques). Fonctionne avec toute
  /// imprimante ESC/POS classe USB Printer (0x07) ou puce série courante
  /// (FTDI/CP210x/CH34x...), sans SDK propriétaire — voir
  /// ThermalPrinterService._printUsb. Un terminal Sunmi doit utiliser
  /// [sunmiIntegrated] à la place (son imprimante n'est pas exposée en USB).
  usb,
  /// Imprimante thermique intégrée d'un terminal tout-en-un Sunmi
  /// spécifiquement — pas d'adresse à configurer, l'app parle directement
  /// au SDK Sunmi (voir ThermalPrinterService.printBytes).
  sunmiIntegrated,
  /// Imprimante intégrée de terminaux Android bas de gamme sans SDK ni
  /// service AIDL (constaté sur MobiWire MobiPrint 3+ / "Mobilot MP3+") :
  /// le pilote noyau du terminal accepte un fichier de commande texte
  /// déposé sur le disque puis un signal écrit dans /proc/printer — pas
  /// d'ESC/POS, texte brut uniquement (voir
  /// ThermalPrinterService._printMobiPrintText et
  /// android/.../MobiPrintChannel.kt). Détectable automatiquement (sonde
  /// /proc/printer) — voir ThermalPrinterService.isMobiPrintAvailable.
  mobiPrintIntegrated,
}

enum PrinterPaperWidth {
  mm58,
  mm80,
}
