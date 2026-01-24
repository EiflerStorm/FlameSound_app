// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaItemModelAdapter extends TypeAdapter<MediaItemModel> {
  @override
  final int typeId = 0;

  @override
  MediaItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaItemModel(
      id: fields[0] as String,
      title: fields[1] as String,
      artist: fields[2] as String?,
      artUri: fields[3] as String?,
      durationMs: fields[4] as int?,
      filePath: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MediaItemModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.artUri)
      ..writeByte(4)
      ..write(obj.durationMs)
      ..writeByte(5)
      ..write(obj.filePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
