import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'text_widget.dart';
import 'loggingInterceptor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setup();
  runApp(const MainApp());
}

void setup() {
  GetIt.instance.registerLazySingleton(
    () => Dio(
      BaseOptions(
        baseUrl: 'https://api.api-ninjas.com/v1/',
        headers: {'X-Api-Key': 'wqPGD0MpWEcZlp3KVi0Ivy3shogvmfMvuSN8dZMX'},
      ),
    )..interceptors.addAll([Logginginterceptor(), PrettyDioLogger()]),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: TextWidget());
  }
}
