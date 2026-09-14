// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'beauty_service_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BeautyServiceModelAdapter extends TypeAdapter<BeautyServiceModel> {
  @override
  final int typeId = 2;

  @override
  BeautyServiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BeautyServiceModel(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as BeautyServiceCategory,
      price: fields[3] as double,
      durationMinutes: fields[4] as int,
      description: fields[5] as String?,
      active: fields[6] as bool,
      createdAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BeautyServiceModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.active)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeautyServiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
