import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';

final usersProvider = StateNotifierProvider<UsersNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return UsersNotifier(ref.watch(dioProvider));
});

class UsersNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;

  UsersNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    state = const AsyncValue.loading();
    try {
      final response = await _dio.get('/users/');
      final allUsers = List<Map<String, dynamic>>.from(response.data);
      state = AsyncValue.data(allUsers);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addUser(Map<String, dynamic> data) async {
    try {
      await _dio.post('/users/', data: data);
      fetchUsers();
    } catch (e) {
      throw Exception('Failed to add user: $e');
    }
  }

  Future<void> updateUser(int userId, Map<String, dynamic> data) async {
    try {
      await _dio.put('/users/$userId', data: data);
      fetchUsers();
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> updateAccess(int userId, String accessLevel, List<String>? allowedTabs) async {
    try {
      await _dio.put('/users/$userId/access', data: {
        'access_level': accessLevel,
        'allowed_tabs': allowedTabs,
      });
      fetchUsers();
    } catch (e) {
      throw Exception('Failed to update access: $e');
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await _dio.delete('/users/$userId');
      fetchUsers();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}
