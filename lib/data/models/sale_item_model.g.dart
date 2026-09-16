// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleItemModelAdapter extends TypeAdapter<SaleItemModel> {
  @override
  final int typeId = 5;

  @override
  SaleItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleItemModel(
      id: fields[0] as String,
      type: fields[1] as SaleItemType,
      referenceId: fields[2] as String,
      title: fields[3] as String,
      category: fields[4] as String?,
      unit: fields[5] as String,
      color: fields[6] as String?,
      qty: (fields[7] as num).toDouble(),
      unitPrice: fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SaleItemModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.referenceId)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.color)
      ..writeByte(7)
      ..write(obj.qty)
      ..writeByte(8)
      ..write(obj.unitPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
