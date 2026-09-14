// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleModelAdapter extends TypeAdapter<SaleModel> {
  @override
  final int typeId = 4;

  @override
  SaleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleModel(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      sellerId: fields[2] as String,
      sellerName: fields[3] as String,
      sellerRole: fields[4] as String,
      workstation: fields[5] as Workstation,
      clientId: fields[6] as String?,
      clientName: fields[7] as String,
      clientPhone: fields[8] as String,
      items: (fields[9] as List).cast<SaleItemModel>(),
      discount: fields[10] as double,
      paymentMethod: fields[11] as PaymentMethod,
      status: fields[12] as SaleStatus,
      loyaltyPointsEarned: fields[13] as int,
      createdAt: fields[14] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SaleModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.sellerId)
      ..writeByte(3)
      ..write(obj.sellerName)
      ..writeByte(4)
      ..write(obj.sellerRole)
      ..writeByte(5)
      ..write(obj.workstation)
      ..writeByte(6)
      ..write(obj.clientId)
      ..writeByte(7)
      ..write(obj.clientName)
      ..writeByte(8)
      ..write(obj.clientPhone)
      ..writeByte(9)
      ..write(obj.items)
      ..writeByte(10)
      ..write(obj.discount)
      ..writeByte(11)
      ..write(obj.paymentMethod)
      ..writeByte(12)
      ..write(obj.status)
      ..writeByte(13)
      ..write(obj.loyaltyPointsEarned)
      ..writeByte(14)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
