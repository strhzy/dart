import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

final service = GetIt.instance;

class TextService {
  Future<String> fetchText({String text = "базовый текст"}) async {
    try {
      final response = await service<Dio>().get('/textlanguage?text=${text}');
      final data = response.data as Map<String, dynamic>;
      return data['language'] as String;
    } on DioException catch (e) {
      print("Ошибка: ${e.message}");
      return "";
    } catch (e) {
      print("Ошибка: $e");
      return "";
    }
  }
}
