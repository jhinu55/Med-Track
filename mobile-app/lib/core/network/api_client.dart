import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../auth/token_storage.dart';

/// Singleton Dio client with a JWT interceptor.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final TokenStorage _tokenStorage = TokenStorage();

  late final Dio dio = _buildDio();

  Dio _buildDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          return handler.next(error);
        },
      ),
    );

    return d;
  }
}
