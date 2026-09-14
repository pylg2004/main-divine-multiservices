// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_service_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrintServiceModelAdapter extends TypeAdapter<PrintServiceModel> {
  @override
  final int typeId = 9;

  @override
  PrintServiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrintServiceModel(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as PrintServiceCategory,
      price: fields[3] as double,
      description: fields[4] as String?,
      active: fields[5] as bool,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PrintServiceModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.active)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintServiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
