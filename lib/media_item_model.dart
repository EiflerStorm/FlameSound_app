import 'package:hive/hive.dart';
import 'package:audio_service/audio_service.dart';

part 'media_item_model.g.dart';

@HiveType(typeId: 0)
class MediaItemModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? artist;

  @HiveField(3)
  String? artUri;

  @HiveField(4)
  int? durationMs;

  // 🔥 NOVO: caminho do arquivo local
  @HiveField(5)
  String filePath;

  MediaItemModel({
    required this.id,
    required this.title,
    this.artist,
    this.artUri,
    this.durationMs,
    required this.filePath,
  });

  /// Converte MediaItem → Hive
  factory MediaItemModel.fromMediaItem(MediaItem item) => MediaItemModel(
        id: item.id,
        title: item.title,
        artist: item.artist,
        artUri: item.artUri?.toString(),
        durationMs: item.duration?.inMilliseconds,
        filePath: item.extras?['filePath'] ?? '',
      );

  /// Converte Hive → MediaItem
  MediaItem toMediaItem() => MediaItem(
        id: id,
        title: title,
        artist: artist,
        artUri: artUri != null ? Uri.parse(artUri!) : null,
        duration:
            durationMs != null ? Duration(milliseconds: durationMs!) : null,
        extras: {
          'filePath': filePath, // 🔑 ESSENCIAL
        },
      );
}
