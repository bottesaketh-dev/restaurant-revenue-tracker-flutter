import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';
import 'restaurant_provider.dart';

final menuProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final restaurantId = ref.watch(selectedRestaurantIdProvider);
  try {
    final queryParams = <String, dynamic>{};
    if (branchId != null) queryParams['branch_id'] = branchId;
    if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
    final response = await dio.get('/menu/items', queryParameters: queryParams.isNotEmpty ? queryParams : null);
    return List<Map<String, dynamic>>.from(response.data);
  } catch (e) {
    throw Exception('Failed to load menu items: $e');
  }
});

final menuNotifierProvider = StateNotifierProvider<MenuNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final branchId = ref.watch(selectedBranchProvider);
  final restaurantId = ref.watch(selectedRestaurantIdProvider);
  return MenuNotifier(ref.watch(dioProvider), branchId, restaurantId);
});

class MenuNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final int? _branchId;
  final int? _restaurantId;

  MenuNotifier(this._dio, this._branchId, this._restaurantId) : super(const AsyncValue.loading()) {
    fetchMenu();
  }

  Map<String, dynamic>? _getQueryParams() {
    final queryParams = <String, dynamic>{};
    if (_branchId != null) queryParams['branch_id'] = _branchId;
    if (_restaurantId != null) queryParams['restaurant_id'] = _restaurantId;
    return queryParams.isNotEmpty ? queryParams : null;
  }

  Future<void> fetchMenu() async {
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final response = await _dio.get('/menu/items', queryParameters: _getQueryParams());
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response.data));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addMenuBulk(List<Map<String, dynamic>> items) async {
    try {
      await _dio.post('/menu/bulk', data: items, queryParameters: _getQueryParams());
      fetchMenu(); // Refresh
    } catch (e) {
      throw Exception('Failed to bulk add: $e');
    }
  }

  Future<void> addMenuItem(Map<String, dynamic> item) async {
    try {
      await _dio.post('/menu/items', data: item, queryParameters: _getQueryParams());
      fetchMenu(); // Refresh
    } catch (e) {
      throw Exception('Failed to add item: $e');
    }
  }

  Future<void> updateMenuItem(int itemId, Map<String, dynamic> item) async {
    try {
      await _dio.put('/menu/items/$itemId', data: item, queryParameters: _getQueryParams());
      fetchMenu(); // Refresh
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }

  Future<void> deleteMenuItem(int itemId) async {
    try {
      await _dio.delete('/menu/items/$itemId', queryParameters: _getQueryParams());
      fetchMenu(); // Refresh
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }
}

final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final restaurantId = ref.watch(selectedRestaurantIdProvider);
  try {
    final queryParams = <String, dynamic>{};
    if (branchId != null) queryParams['branch_id'] = branchId;
    if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
    final response = await dio.get('/menu/categories', queryParameters: queryParams.isNotEmpty ? queryParams : null);
    return List<String>.from(response.data);
  } catch (e) {
    throw Exception('Failed to load categories: $e');
  }
});
