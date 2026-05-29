import 'package:dio/dio.dart';
import 'failures.dart';

Failure handleDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode;
      if (status == 401) return const UnauthorizedFailure();
      if (status == 422) {
        final errors = _parseValidationErrors(e.response?.data);
        return ValidationFailure(
          e.response?.data?['message'] ?? 'بيانات غير صحيحة',
          errors: errors,
        );
      }
      return ServerFailure(
        e.response?.data?['message'] ?? 'حدث خطأ في الخادم',
        statusCode: status,
      );
    default:
      return ServerFailure(e.message ?? 'حدث خطأ غير متوقع');
  }
}

Map<String, List<String>> _parseValidationErrors(dynamic data) {
  if (data == null || data['errors'] == null) return {};
  final raw = data['errors'] as Map<String, dynamic>;
  return raw.map((k, v) => MapEntry(k, List<String>.from(v as List)));
}
