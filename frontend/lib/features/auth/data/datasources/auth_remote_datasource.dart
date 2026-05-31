import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

// Wired through Riverpod (authDatasourceProvider), not get_it/injectable —
// it depends on ApiClient which is a Riverpod provider, so an @injectable
// annotation here would make injectable_generator emit code that can't resolve
// ApiClient from get_it.
class AuthRemoteDatasource {
  final ApiClient _client;

  AuthRemoteDatasource(this._client);

  Future<({String token, UserModel user})> login(String email, String password) async {
    try {
      final response = await _client.dio.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );
      final data = response.data['data'];
      return (
        token: data['token'] as String,
        user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _client.dio.post(ApiEndpoints.logout);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<UserModel> getMe() async {
    try {
      final response = await _client.dio.get(ApiEndpoints.me);
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }
}
