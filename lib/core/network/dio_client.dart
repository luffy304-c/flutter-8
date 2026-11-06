import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_interceptor.dart';

/// Единственный экземпляр Dio на всё приложение.
class DioClient {
  DioClient({Dio? dio}) : dio = dio ?? _build();

  static const baseUrl = 'https://jsonplaceholder.typicode.com';

  final Dio dio;

  static Dio _build() {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ));
    dio.interceptors.addAll([
      ApiInterceptor(),
      ErrorInterceptor(),
      if (kDebugMode)
        LogInterceptor(
          requestBody: true,
          responseBody: false,
          logPrint: (o) => debugPrint(o.toString()),
        ),
    ]);
    return dio;
  }
}
