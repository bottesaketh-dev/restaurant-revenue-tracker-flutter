import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'restaurant_provider.dart';

final selectedBranchProvider = StateProvider<int?>((ref) => null);

final branchListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final restaurantId = ref.watch(selectedRestaurantIdProvider);
  final queryParams = restaurantId != null ? {'restaurant_id': restaurantId} : null;
  final response = await dio.get('/branches/', queryParameters: queryParams);
  return List<Map<String, dynamic>>.from(response.data);
});

final branchManagementProvider = StateNotifierProvider<BranchManagementNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final selectedRestaurant = ref.watch(selectedRestaurantIdProvider);
  return BranchManagementNotifier(ref.watch(dioProvider), selectedRestaurant, ref);
});

class BranchManagementNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final int? _restaurantId;
  final Ref _ref;

  BranchManagementNotifier(this._dio, this._restaurantId, this._ref) : super(const AsyncValue.loading()) {
    fetchBranches();
  }

  Future<void> fetchBranches({int? overrideRestaurantId}) async {
    state = const AsyncValue.loading();
    try {
      final rId = overrideRestaurantId ?? _restaurantId;
      final queryParams = rId != null ? {'restaurant_id': rId} : null;
      final response = await _dio.get('/branches/', queryParameters: queryParams);
      final list = List<Map<String, dynamic>>.from(response.data);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createBranch(Map<String, dynamic> data) async {
    try {
      await _dio.post('/branches/', data: data);
      _ref.invalidate(branchListProvider);
      fetchBranches();
    } catch (e) {
      throw Exception('Failed to create branch: $e');
    }
  }

  Future<void> updateBranch(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/branches/$id', data: data);
      _ref.invalidate(branchListProvider);
      fetchBranches();
    } catch (e) {
      throw Exception('Failed to update branch: $e');
    }
  }

  Future<Map<String, dynamic>> deleteBranch(int id) async {
    try {
      final response = await _dio.delete('/branches/$id');
      _ref.invalidate(branchListProvider);
      fetchBranches();
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Failed to delete/deactivate branch: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAccessUsers({int? restaurantId}) async {
    try {
      final queryParams = restaurantId != null ? {'restaurant_id': restaurantId} : null;
      final response = await _dio.get('/branches/access/users', queryParameters: queryParams);
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw Exception('Failed to load branch access users: $e');
    }
  }

  Future<void> grantTabAccess(int userId, bool granted) async {
    try {
      await _dio.post('/branches/access/grant', data: {
        'user_id': userId,
        'granted': granted,
      });
    } catch (e) {
      throw Exception('Failed to update tab access: $e');
    }
  }
}
