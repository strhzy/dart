import 'package:hive/hive.dart';

part 'audio_item.g.dart';

@HiveType(typeId: 0)
class AudioItem extends HiveObject {
  @HiveField(0)
  final String url;

  @HiveField(1)
  final String localPath;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final DateTime addedAt;

  AudioItem({
    required this.url,
    required this.localPath,
    required this.title,
    DateTime? addedAt,
  }) : this.addedAt = addedAt ?? DateTime.now();
}
