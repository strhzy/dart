import 'package:hive/hive.dart';

part 'movie.g.dart';

@HiveType(typeId: 0)
class Movie extends HiveObject {
  @HiveField(0)
  String name = "";
  @HiveField(1)
  String description = "";
  @HiveField(2)
  int year = 0;
  @HiveField(3)
  double rating = 0.0;
}
