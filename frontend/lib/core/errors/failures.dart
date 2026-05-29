import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure() : super('لا يوجد اتصال بالإنترنت');
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً');
}

class ValidationFailure extends Failure {
  final Map<String, List<String>> errors;
  const ValidationFailure(super.message, {this.errors = const {}});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
