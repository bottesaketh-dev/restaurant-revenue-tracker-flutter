import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';

final menuProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  try {
    final queryParams = branchId != null ? {'branch_id': branchId} : null;
    final response = await dio.get('/menu/items', queryParameters: queryParams);
    return List<Map<String, dynamic>>.from(response.data);
  } catch (e) {
    throw Exception('Failed to load menu items: $e');
  }
});

final menuNotifierProvider = StateNotifierProvider<MenuNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final branchId = ref.watch(selectedBranchProvider);
  return MenuNotifier(ref.watch(dioProvider), branchId);
});

class MenuNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final int? _branchId;

  MenuNotifier(this._dio, this._branchId) : super(const AsyncValue.loading()) {
    fetchMenu();
  }

  Future<void> fetchMenu() async {
    state = const AsyncValue.loading();
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      final response = await _dio.get('/menu/items', queryParameters: queryParams);
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response.data));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addMenuBulk(List<Map<String, dynamic>> items) async {
    try {
      await _dio.post('/menu/bulk', data: items);
      fetchMenu(); // Refresh
    } catch (e) {
      throw Exception('Failed to bulk add: $e');
    }
  }

  Future<void> addMenuItem(Map<String, dynamic> item) async {
    try {
      await _dio.post('/menu/items', data: item);
      fetchMenu(); // Refresh
    } catch (e) {
      throw Exception('Failed to add item: $e');
    }
  }

  Future<void> updateMenuItem(int itemId, Map<String, dynamic> item) async {
    try {
      await _dio.put('/menu/items/$itemId', data: item);
      fetchMenu(); // Refresh
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }

  Future<void> deleteMenuItem(int itemId) async {
    try {
      await _dio.delete('/menu/items/$itemId');
      fetchMenu(); // Refresh
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }
}

final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  try {
    final queryParams = branchId != null ? {'branch_id': branchId} : null;
    final response = await dio.get('/menu/categories', queryParameters: queryParams);
    return List<String>.from(response.data);
  } catch (e) {
    throw Exception('Failed to load categories: $e');
  }
});
