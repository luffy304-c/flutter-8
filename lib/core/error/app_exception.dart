import 'package:dio/dio.dart';

enum AppErrorType { noConnection, timeout, client, server, parse, unknown }

/// Единый тип ошибки приложения. Технические детали ([technical]) идут
/// только в логи, пользователю показывается [message].
class AppException implements Exception {
  const AppException(this.type, {this.statusCode, this.technical});

  final AppErrorType type;
  final int? statusCode;
  final String? technical;

  String get message {
    switch (type) {
      case AppErrorType.noConnection:
        return 'Нет подключения к интернету. Проверьте сеть и повторите попытку.';
      case AppErrorType.timeout:
        return 'Сервер отвечает слишком долго. Попробуйте ещё раз.';
      case AppErrorType.client:
        if (statusCode == 404) return 'Данные не найдены (404).';
        return 'Некорректный запрос (код ${statusCode ?? '4xx'}).';
      case AppErrorType.server:
        return 'Ошибка сервера (код ${statusCode ?? '5xx'}). Попробуйте позже.';
      case AppErrorType.parse:
        return 'Не удалось обработать ответ сервера.';
      case AppErrorType.unknown:
        return 'Произошла неизвестная ошибка.';
    }
  }

  /// Преобразует DioException в [AppException].
  factory AppException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return AppException(AppErrorType.timeout, technical: e.message);
      case DioExceptionType.connectionError:
        return AppException(AppErrorType.noConnection, technical: e.message);
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code >= 500) {
          return AppException(AppErrorType.server,
              statusCode: code, technical: e.message);
        }
        return AppException(AppErrorType.client,
            statusCode: code, technical: e.message);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return AppException(AppErrorType.unknown,
            technical: '${e.error ?? e.message}');
    }
  }

  @override
  String toString() => 'AppException($type, $statusCode, $technical)';
}
