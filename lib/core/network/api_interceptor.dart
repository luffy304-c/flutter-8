import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../error/app_exception.dart';

/// Добавляет технические заголовки ко всем запросам.
class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('Accept', () => 'application/json');
    options.headers['X-Client'] = 'post-explorer';
    options.headers['X-Platform'] = defaultTargetPlatform.name;
    handler.next(options);
  }
}

/// Централизованная обработка HTTP-ошибок: любая DioException превращается
/// в DioException, внутри которой лежит [AppException].
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is AppException) return handler.next(err);
    if (err.type == DioExceptionType.cancel) return handler.next(err);
    handler.next(err.copyWith(error: AppException.fromDio(err)));
  }
}
