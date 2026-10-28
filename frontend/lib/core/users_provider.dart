import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'restaurant_provider.dart';

final usersProvider = StateNotifierProvider<UsersNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final restaurantId = ref.watch(selectedRestaurantIdProvider);
  return UsersNotifier(ref.watch(dioProvider), restaurantId);
});

class UsersNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final int? _restaurantId;

  UsersNotifier(this._dio, this._restaurantId) : super(const AsyncValue.loading()) {
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{};
      if (_restaurantId != null) queryParams['restaurant_id'] = _restaurantId;
      final response = await _dio.get('/users/', queryParameters: queryParams.isNotEmpty ? queryParams : null);
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
