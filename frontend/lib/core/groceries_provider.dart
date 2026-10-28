import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';
import 'restaurant_provider.dart';
import 'package:flutter/material.dart';
import 'kitchen_provider.dart';

final groceryDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);
final groceryCategoryFilterProvider = StateProvider<int?>((ref) => null);

// Categories
final groceryCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final restaurantId = ref.watch(selectedRestaurantIdProvider);
  final queryParams = restaurantId != null ? {'restaurant_id': restaurantId} : null;
  final response = await dio.get('/groceries/categories', queryParameters: queryParams);
  return List<Map<String, dynamic>>.from(response.data);
});

Future<Map<String, dynamic>> createGroceryCategory(WidgetRef ref, String name, [String? description]) async {
  final dio = ref.read(dioProvider);
  final restaurantId = ref.read(selectedRestaurantIdProvider);
  final queryParams = restaurantId != null ? {'restaurant_id': restaurantId} : null;
  final response = await dio.post('/groceries/categories', data: {
    'name': name,
    if (description != null) 'description': description,
  }, queryParameters: queryParams);
  ref.invalidate(groceryCategoriesProvider);
  return response.data;
}

// Items
final groceryItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final categoryId = ref.watch(groceryCategoryFilterProvider);
  final restaurantId = ref.watch(selectedRestaurantIdProvider);
  final queryParams = <String, dynamic>{};
  if (categoryId != null) queryParams['category_id'] = categoryId;
  if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
  
  final response = await dio.get('/groceries/items', queryParameters: queryParams.isNotEmpty ? queryParams : null);
  return List<Map<String, dynamic>>.from(response.data);
});

Future<Map<String, dynamic>> createGroceryItem(WidgetRef ref, String productName, int categoryId, String unit) async {
  final dio = ref.read(dioProvider);
  final restaurantId = ref.read(selectedRestaurantIdProvider);
  final queryParams = restaurantId != null ? {'restaurant_id': restaurantId} : null;
  final response = await dio.post('/groceries/items', data: {
    'product_name': productName,
    'category_id': categoryId,
    'unit': unit,
  }, queryParameters: queryParams);
  ref.invalidate(groceryItemsProvider);
  return response.data;
}

// Purchases
final groceriesProvider = StateNotifierProvider<GroceriesNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final branchId = ref.watch(selectedBranchProvider);
  final restaurantId = ref.watch(selectedRestaurantIdProvider);
  final dateRange = ref.watch(groceryDateRangeProvider);
  final categoryId = ref.watch(groceryCategoryFilterProvider);
  return GroceriesNotifier(ref, ref.watch(dioProvider), branchId, restaurantId, dateRange, categoryId);
});

class GroceriesNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  final Dio _dio;
  final int? _branchId;
  final int? _restaurantId;
  final DateTimeRange? _dateRange;
  final int? _categoryId;

  GroceriesNotifier(this._ref, this._dio, this._branchId, this._restaurantId, this._dateRange, this._categoryId) : super(const AsyncValue.loading()) {
    fetchGroceries();
  }

  Future<void> fetchGroceries() async {
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{};
      if (_branchId != null) queryParams['branch_id'] = _branchId;
      if (_restaurantId != null) queryParams['restaurant_id'] = _restaurantId;
      if (_categoryId != null) queryParams['category_id'] = _categoryId;
      if (_dateRange != null) {
        final range = _dateRange!;
        queryParams['start_date'] = '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
        queryParams['end_date'] = '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}';
      }
      final response = await _dio.get('/groceries/purchases', queryParameters: queryParams);
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response.data));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addGroceryBulk(List<Map<String, dynamic>> items) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.post('/groceries/purchases/bulk', data: items, queryParameters: queryParams);
      _ref.invalidate(inventoryStockProvider);
      fetchGroceries();
    } catch (e) {
      throw Exception('Failed to bulk add: $e');
    }
  }

  Future<void> addGrocery(Map<String, dynamic> item) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.post('/groceries/purchases', data: item, queryParameters: queryParams);
      _ref.invalidate(inventoryStockProvider);
      fetchGroceries();
    } catch (e) {
      throw Exception('Failed to add grocery: $e');
    }
  }

  Future<void> updateGrocery(int purchaseId, Map<String, dynamic> item) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.put('/groceries/purchases/$purchaseId', data: item, queryParameters: queryParams);
      _ref.invalidate(inventoryStockProvider);
      fetchGroceries();
    } catch (e) {
      throw Exception('Failed to update grocery: $e');
    }
  }

  Future<void> deleteGrocery(int purchaseId) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.delete('/groceries/purchases/$purchaseId', queryParameters: queryParams);
      _ref.invalidate(inventoryStockProvider);
      fetchGroceries();
    } catch (e) {
      throw Exception('Failed to delete grocery: $e');
    }
  }
}
