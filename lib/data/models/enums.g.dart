// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enums.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserRoleAdapter extends TypeAdapter<UserRole> {
  @override
  final int typeId = 20;

  @override
  UserRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UserRole.superAdmin;
      case 1:
        return UserRole.admin;
      case 2:
        return UserRole.manager;
      case 3:
        return UserRole.vendeur;
      case 4:
        return UserRole.caissier;
      case 5:
        return UserRole.beautician;
      case 6:
        return UserRole.imprimeur;
      default:
        return UserRole.superAdmin;
    }
  }

  @override
  void write(BinaryWriter writer, UserRole obj) {
    switch (obj) {
      case UserRole.superAdmin:
        writer.writeByte(0);
        break;
      case UserRole.admin:
        writer.writeByte(1);
        break;
      case UserRole.manager:
        writer.writeByte(2);
        break;
      case UserRole.vendeur:
        writer.writeByte(3);
        break;
      case UserRole.caissier:
        writer.writeByte(4);
        break;
      case UserRole.beautician:
        writer.writeByte(5);
        break;
      case UserRole.imprimeur:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkstationAdapter extends TypeAdapter<Workstation> {
  @override
  final int typeId = 21;

  @override
  Workstation read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Workstation.pos;
      case 1:
        return Workstation.beauty;
      case 2:
        return Workstation.admin;
      case 3:
        return Workstation.impression;
      default:
        return Workstation.pos;
    }
  }

  @override
  void write(BinaryWriter writer, Workstation obj) {
    switch (obj) {
      case Workstation.pos:
        writer.writeByte(0);
        break;
      case Workstation.beauty:
        writer.writeByte(1);
        break;
      case Workstation.admin:
        writer.writeByte(2);
        break;
      case Workstation.impression:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkstationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductCategoryAdapter extends TypeAdapter<ProductCategory> {
  @override
  final int typeId = 22;

  @override
  ProductCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ProductCategory.papeterie;
      case 1:
        return ProductCategory.tissu;
      case 2:
        return ProductCategory.livre;
      default:
        return ProductCategory.papeterie;
    }
  }

  @override
  void write(BinaryWriter writer, ProductCategory obj) {
    switch (obj) {
      case ProductCategory.papeterie:
        writer.writeByte(0);
        break;
      case ProductCategory.tissu:
        writer.writeByte(1);
        break;
      case ProductCategory.livre:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BeautyServiceCategoryAdapter extends TypeAdapter<BeautyServiceCategory> {
  @override
  final int typeId = 23;

  @override
  BeautyServiceCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BeautyServiceCategory.coiffure;
      case 1:
        return BeautyServiceCategory.esthetique;
      case 2:
        return BeautyServiceCategory.onglerie;
      case 3:
        return BeautyServiceCategory.maquillage;
      case 4:
        return BeautyServiceCategory.soins;
      case 5:
        return BeautyServiceCategory.autre;
      default:
        return BeautyServiceCategory.coiffure;
    }
  }

  @override
  void write(BinaryWriter writer, BeautyServiceCategory obj) {
    switch (obj) {
      case BeautyServiceCategory.coiffure:
        writer.writeByte(0);
        break;
      case BeautyServiceCategory.esthetique:
        writer.writeByte(1);
        break;
      case BeautyServiceCategory.onglerie:
        writer.writeByte(2);
        break;
      case BeautyServiceCategory.maquillage:
        writer.writeByte(3);
        break;
      case BeautyServiceCategory.soins:
        writer.writeByte(4);
        break;
      case BeautyServiceCategory.autre:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeautyServiceCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SaleItemTypeAdapter extends TypeAdapter<SaleItemType> {
  @override
  final int typeId = 24;

  @override
  SaleItemType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SaleItemType.product;
      case 1:
        return SaleItemType.beautyService;
      case 2:
        return SaleItemType.printService;
      default:
        return SaleItemType.product;
    }
  }

  @override
  void write(BinaryWriter writer, SaleItemType obj) {
    switch (obj) {
      case SaleItemType.product:
        writer.writeByte(0);
        break;
      case SaleItemType.beautyService:
        writer.writeByte(1);
        break;
      case SaleItemType.printService:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItemTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrintServiceCategoryAdapter extends TypeAdapter<PrintServiceCategory> {
  @override
  final int typeId = 29;

  @override
  PrintServiceCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PrintServiceCategory.impression;
      case 1:
        return PrintServiceCategory.flyers;
      case 2:
        return PrintServiceCategory.cartesDeVisite;
      case 3:
        return PrintServiceCategory.affiches;
      case 4:
        return PrintServiceCategory.servicesInformatiques;
      case 5:
        return PrintServiceCategory.autre;
      default:
        return PrintServiceCategory.impression;
    }
  }

  @override
  void write(BinaryWriter writer, PrintServiceCategory obj) {
    switch (obj) {
      case PrintServiceCategory.impression:
        writer.writeByte(0);
        break;
      case PrintServiceCategory.flyers:
        writer.writeByte(1);
        break;
      case PrintServiceCategory.cartesDeVisite:
        writer.writeByte(2);
        break;
      case PrintServiceCategory.affiches:
        writer.writeByte(3);
        break;
      case PrintServiceCategory.servicesInformatiques:
        writer.writeByte(4);
        break;
      case PrintServiceCategory.autre:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintServiceCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SaleStatusAdapter extends TypeAdapter<SaleStatus> {
  @override
  final int typeId = 25;

  @override
  SaleStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SaleStatus.complete;
      case 1:
        return SaleStatus.annulee;
      default:
        return SaleStatus.complete;
    }
  }

  @override
  void write(BinaryWriter writer, SaleStatus obj) {
    switch (obj) {
      case SaleStatus.complete:
        writer.writeByte(0);
        break;
      case SaleStatus.annulee:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaymentMethodAdapter extends TypeAdapter<PaymentMethod> {
  @override
  final int typeId = 26;

  @override
  PaymentMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PaymentMethod.especes;
      case 1:
        return PaymentMethod.carte;
      case 2:
        return PaymentMethod.mobile;
      default:
        return PaymentMethod.especes;
    }
  }

  @override
  void write(BinaryWriter writer, PaymentMethod obj) {
    switch (obj) {
      case PaymentMethod.especes:
        writer.writeByte(0);
        break;
      case PaymentMethod.carte:
        writer.writeByte(1);
        break;
      case PaymentMethod.mobile:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrinterConnectionTypeAdapter extends TypeAdapter<PrinterConnectionType> {
  @override
  final int typeId = 27;

  @override
  PrinterConnectionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PrinterConnectionType.network;
      case 1:
        return PrinterConnectionType.usb;
      default:
        return PrinterConnectionType.network;
    }
  }

  @override
  void write(BinaryWriter writer, PrinterConnectionType obj) {
    switch (obj) {
      case PrinterConnectionType.network:
        writer.writeByte(0);
        break;
      case PrinterConnectionType.usb:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterConnectionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrinterPaperWidthAdapter extends TypeAdapter<PrinterPaperWidth> {
  @override
  final int typeId = 28;

  @override
  PrinterPaperWidth read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PrinterPaperWidth.mm58;
      case 1:
        return PrinterPaperWidth.mm80;
      default:
        return PrinterPaperWidth.mm58;
    }
  }

  @override
  void write(BinaryWriter writer, PrinterPaperWidth obj) {
    switch (obj) {
      case PrinterPaperWidth.mm58:
        writer.writeByte(0);
        break;
      case PrinterPaperWidth.mm80:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterPaperWidthAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
