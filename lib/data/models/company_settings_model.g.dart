// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompanySettingsModelAdapter extends TypeAdapter<CompanySettingsModel> {
  @override
  final int typeId = 7;

  @override
  CompanySettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompanySettingsModel(
      name: fields[0] as String,
      slogan: fields[1] as String?,
      phone: fields[2] as String?,
      address: fields[3] as String?,
      currencyCode: fields[4] as String,
      currencySymbol: fields[5] as String,
      logoPath: fields[6] as String?,
      setupComplete: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CompanySettingsModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.slogan)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.currencyCode)
      ..writeByte(5)
      ..write(obj.currencySymbol)
      ..writeByte(6)
      ..write(obj.logoPath)
      ..writeByte(7)
      ..write(obj.setupComplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanySettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
