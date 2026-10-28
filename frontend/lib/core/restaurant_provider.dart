import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'currency_formatter.dart';

final selectedRestaurantIdProvider = StateProvider<int?>((ref) => null);

/// List of all restaurants (available to Super Admin)
final restaurantListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/restaurants');
    return List<Map<String, dynamic>>.from(response.data);
  } catch (e) {
    return [];
  }
});

/// Current active restaurant profile
final currentRestaurantProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final dio = ref.watch(dioProvider);
  final authState = ref.watch(authStateProvider);
  if (!authState.isAuthenticated) return null;
  
  final selectedRestaurantId = ref.watch(selectedRestaurantIdProvider);

  try {
    if (selectedRestaurantId != null) {
      final response = await dio.get('/restaurants/$selectedRestaurantId');
      final data = Map<String, dynamic>.from(response.data);
      if (data['currency_symbol'] != null) {
        CurrencyFormatter.setCurrency(
          symbol: data['currency_symbol'] ?? '₹',
          code: data['currency_code'] ?? 'INR',
        );
      }
      return data;
    } else {
      final response = await dio.get('/restaurants/current');
      if (response.data == null) return null;
      final data = Map<String, dynamic>.from(response.data);
      if (data['currency_symbol'] != null) {
        CurrencyFormatter.setCurrency(
          symbol: data['currency_symbol'] ?? '₹',
          code: data['currency_code'] ?? 'INR',
        );
      }
      return data;
    }
  } catch (e) {
    return null;
  }
});

/// Active Tenant metadata (reactive for App Bar, Sidebar, and Currency indicator)
class ActiveTenantInfo {
  final int? restaurantId;
  final String name;
  final String currencySymbol;
  final String currencyCode;

  const ActiveTenantInfo({
    required this.restaurantId,
    required this.name,
    required this.currencySymbol,
    required this.currencyCode,
  });
}

final activeTenantInfoProvider = Provider<ActiveTenantInfo>((ref) {
  final authState = ref.watch(authStateProvider);
  final selectedRestaurantId = ref.watch(selectedRestaurantIdProvider);
  final restaurantListAsync = ref.watch(restaurantListProvider);

  if (selectedRestaurantId == null) {
    return ActiveTenantInfo(
      restaurantId: null,
      name: authState.isSuperAdmin ? 'All Tenants (Global)' : authState.restaurantName,
      currencySymbol: authState.currencySymbol,
      currencyCode: authState.currencyCode,
    );
  }

  final restaurants = restaurantListAsync.asData?.value ?? [];
  final matched = restaurants.firstWhere(
    (r) => r['restaurant_id'] == selectedRestaurantId,
    orElse: () => {
      'name': 'Restaurant #$selectedRestaurantId',
      'currency_symbol': authState.currencySymbol,
      'currency_code': authState.currencyCode,
    },
  );

  final symbol = matched['currency_symbol']?.toString() ?? '₹';
  final code = matched['currency_code']?.toString() ?? 'INR';

  return ActiveTenantInfo(
    restaurantId: selectedRestaurantId,
    name: matched['name']?.toString() ?? 'Restaurant #$selectedRestaurantId',
    currencySymbol: symbol,
    currencyCode: code,
  );
});

final restaurantManagementProvider = StateNotifierProvider<RestaurantManagementNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return RestaurantManagementNotifier(ref.watch(dioProvider), ref);
});

class RestaurantManagementNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final Ref _ref;

  RestaurantManagementNotifier(this._dio, this._ref) : super(const AsyncValue.loading()) {
    fetchRestaurants();
  }

  Future<void> fetchRestaurants() async {
    state = const AsyncValue.loading();
    try {
      final response = await _dio.get('/restaurants');
      final list = List<Map<String, dynamic>>.from(response.data);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createRestaurant(Map<String, dynamic> data) async {
    try {
      await _dio.post('/restaurants', data: data);
      _ref.invalidate(restaurantListProvider);
      fetchRestaurants();
    } catch (e) {
      throw Exception('Failed to create restaurant: $e');
    }
  }

  Future<void> updateRestaurant(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/restaurants/$id', data: data);
      _ref.invalidate(restaurantListProvider);
      _ref.invalidate(currentRestaurantProvider);
      fetchRestaurants();
    } catch (e) {
      throw Exception('Failed to update restaurant: $e');
    }
  }

  Future<Map<String, dynamic>> deleteRestaurant(int id) async {
    try {
      final response = await _dio.delete('/restaurants/$id');
      _ref.invalidate(restaurantListProvider);
      _ref.invalidate(currentRestaurantProvider);
      fetchRestaurants();
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Failed to delete/deactivate restaurant: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAccessUsers() async {
    try {
      final response = await _dio.get('/restaurants/access/users');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw Exception('Failed to load user access list: $e');
    }
  }

  Future<void> grantTabAccess(int userId, bool granted) async {
    try {
      await _dio.post('/restaurants/access/grant', data: {
        'user_id': userId,
        'granted': granted,
      });
    } catch (e) {
      throw Exception('Failed to update tab access: $e');
    }
  }
}



