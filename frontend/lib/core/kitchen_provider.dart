import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';
import 'restaurant_provider.dart';

enum KitchenTab { recipes, stock }

final kitchenTabProvider = StateProvider<KitchenTab>((ref) => KitchenTab.recipes);
final kitchenSearchQueryProvider = StateProvider<String>((ref) => '');
final kitchenSelectedCategoryProvider = StateProvider<String?>((ref) => null);

final inventoryStockProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final restaurantId = ref.watch(selectedRestaurantIdProvider);
  try {
    final queryParams = <String, dynamic>{};
    if (branchId != null) queryParams['branch_id'] = branchId;
    if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
    final response = await dio.get('/kitchen/inventory', queryParameters: queryParams.isNotEmpty ? queryParams : null);
    return List<Map<String, dynamic>>.from(response.data);
  } catch (e) {
    debugPrint('Error fetching inventory: $e');
    return [];
  }
});

class RecipeNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  RecipeNotifier(this._dio) : super(const AsyncValue.loading());

  Future<void> fetchRecipe(int menuItemId) async {
    state = const AsyncValue.loading();
    try {
      final response = await _dio.get('/kitchen/recipes/$menuItemId');
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response.data));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> updateRecipe(int menuItemId, List<Map<String, dynamic>> ingredients) async {
    try {
      await _dio.post('/kitchen/recipes/$menuItemId', data: ingredients);
      await fetchRecipe(menuItemId);
      return true;
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      return false;
    }
  }
}

final recipeProvider = StateNotifierProvider.family<RecipeNotifier, AsyncValue<List<Map<String, dynamic>>>, int>((ref, menuItemId) {
  final dio = ref.watch(dioProvider);
  final notifier = RecipeNotifier(dio);
  notifier.fetchRecipe(menuItemId);
  return notifier;
});
