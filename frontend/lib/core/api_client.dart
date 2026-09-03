import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    connectTimeout: const Duration(seconds: 120),
    receiveTimeout: const Duration(seconds: 120),
  ));

  final secureStorage = ref.watch(secureStorageProvider);

  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
    final token = await secureStorage.read(key: 'jwt_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }, onError: (DioException e, handler) async {
    if (e.response?.statusCode == 401) {
      // Token expired or invalid, trigger logout logic here
      await secureStorage.delete(key: 'jwt_token');
    }
    return handler.next(e);
  }));

  return dio;
});
