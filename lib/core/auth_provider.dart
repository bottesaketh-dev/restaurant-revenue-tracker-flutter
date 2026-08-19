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
  final Map<String, dynamic>? user;

  AuthState({this.isAuthenticated = false, this.isLoading = false, this.error, this.user});

  AuthState copyWith({bool? isAuthenticated, bool? isLoading, String? error, Map<String, dynamic>? user}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      user: user ?? this.user,
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
      try {
        final response = await _dio.get('/auth/session');
        state = state.copyWith(isAuthenticated: true, user: response.data);
      } catch (e) {
        // Token might be expired or invalid
        await logout();
      }
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
      final user = response.data['user'];
      await _secureStorage.write(key: 'jwt_token', value: token);
      
      state = state.copyWith(isAuthenticated: true, isLoading: false, user: user);
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
    state = state.copyWith(isAuthenticated: false, user: null);
  }
}
