import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(dioProvider), ref.watch(secureStorageProvider));
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  AuthState({this.isAuthenticated = false, this.isLoading = false, this.error});

  AuthState copyWith({bool? isAuthenticated, bool? isLoading, String? error}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;
  final dynamic _secureStorage;

  AuthNotifier(this._dio, this._secureStorage) : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final token = await _secureStorage.read(key: 'jwt_token');
    if (token != null) {
      state = state.copyWith(isAuthenticated: true);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': username,
          'password': password,
        },
      );

      final token = response.data['token'];
      await _secureStorage.write(key: 'jwt_token', value: token);
      
      state = state.copyWith(isAuthenticated: true, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false, 
        error: e.response?.data['detail'] ?? 'Login failed'
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'jwt_token');
    state = state.copyWith(isAuthenticated: false);
  }
}
