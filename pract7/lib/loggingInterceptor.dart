import 'package:dio/dio.dart';

class Logginginterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('ЗАПРОС[${options.method}] - ПУТЬ: ${options.path}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print(
      'ОТВЕТ[${response.statusCode}] - ПУТЬ: ${response.requestOptions.path}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('ОШИБКА[${err.message}] - ПУТЬ: ${err.requestOptions.path}');
    super.onError(err, handler);
  }
}
