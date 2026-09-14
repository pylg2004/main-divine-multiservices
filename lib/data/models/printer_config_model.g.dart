// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_config_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrinterConfigModelAdapter extends TypeAdapter<PrinterConfigModel> {
  @override
  final int typeId = 8;

  @override
  PrinterConfigModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrinterConfigModel(
      connectionType: fields[0] as PrinterConnectionType?,
      address: fields[1] as String?,
      port: fields[2] as int?,
      deviceName: fields[3] as String?,
      paperWidth: fields[4] as PrinterPaperWidth,
    );
  }

  @override
  void write(BinaryWriter writer, PrinterConfigModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.connectionType)
      ..writeByte(1)
      ..write(obj.address)
      ..writeByte(2)
      ..write(obj.port)
      ..writeByte(3)
      ..write(obj.deviceName)
      ..writeByte(4)
      ..write(obj.paperWidth);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterConfigModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
