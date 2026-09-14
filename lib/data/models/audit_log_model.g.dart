// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AuditLogModelAdapter extends TypeAdapter<AuditLogModel> {
  @override
  final int typeId = 6;

  @override
  AuditLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuditLogModel(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      userId: fields[2] as String,
      userName: fields[3] as String,
      action: fields[4] as String,
      details: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AuditLogModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.userName)
      ..writeByte(4)
      ..write(obj.action)
      ..writeByte(5)
      ..write(obj.details);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditLogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
