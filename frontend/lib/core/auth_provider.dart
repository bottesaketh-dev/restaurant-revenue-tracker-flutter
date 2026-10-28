import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'nav_tabs.dart';
import 'currency_formatter.dart';

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

  String? get role => (user?['role'] as String?)?.toUpperCase();
  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isRestaurantAdmin => role == 'RESTAURANT_ADMIN' || isSuperAdmin || role == 'ADMIN';
  bool get isBranchManager => role == 'BRANCH_MANAGER';
  bool get isAdmin => isRestaurantAdmin;

  int? get restaurantId => user?['restaurant_id'] as int?;
  String get restaurantName => (user?['restaurant_name'] as String?) ?? 'Restaurant';
  String get currencyCode => (user?['currency_code'] as String?) ?? 'INR';
  String get currencySymbol => (user?['currency_symbol'] as String?) ?? '₹';
  double get taxRate => (user?['tax_rate'] as num?)?.toDouble() ?? 0.05;
  int? get branchId => user?['branch_id'] as int?;

  String get accessLevel => (user?['access_level'] as String?) ?? 'FULL';

  /// Explicit permission grants assigned to this user from backend
  List<String> get permissions {
    final perms = user?['permissions'];
    if (perms is List) return perms.map((e) => e.toString()).toList();
    return const [];
  }

  bool get canManageRestaurants => isSuperAdmin || permissions.contains('manage:restaurants');
  bool get canManageBranches => isSuperAdmin || isRestaurantAdmin || isBranchManager || permissions.contains('manage:branches');

  /// Tab keys the current user is allowed to see. Null/FULL access means all standard tabs.
  List<String>? get allowedTabs {
    if (accessLevel != 'PARTIAL') return null;
    final tabs = user?['allowed_tabs'];
    if (tabs is List) return tabs.map((e) => e.toString()).toList();
    return const [];
  }

  bool canAccessTab(String tabKey) {
    // Restaurants tab: Privileged tab accessible only to Super Admin or explicitly granted users
    if (tabKey == 'restaurants') {
      if (isSuperAdmin) return true;
      if (permissions.contains('tab:restaurants')) return true;
      final rawTabs = user?['allowed_tabs'];
      if (rawTabs is List && rawTabs.contains('restaurants')) return true;
      return false;
    }

    // Branches tab: Accessible to Super Admins, Restaurant Admins, and Branch Managers by default; other users need explicit grant
    if (tabKey == 'branches') {
      if (isSuperAdmin || isRestaurantAdmin || isBranchManager) return true;
      if (permissions.contains('tab:branches')) return true;
      final rawTabs = user?['allowed_tabs'];
      if (rawTabs is List && rawTabs.contains('branches')) return true;
      return false;
    }

    final tabs = allowedTabs;
    if (tabs == null) return true; // FULL access
    return tabs.contains(tabKey);
  }

  /// The route the user should land on after login/app start: their first
  /// accessible tab, falling back to '/home' if they somehow have none.
  String get landingRoute {
    final accessible = kNavTabs.where((t) => canAccessTab(t.key));
    return accessible.isEmpty ? '/home' : accessible.first.route;
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;
  final dynamic _secureStorage;

  AuthNotifier(this._dio, this._secureStorage) : super(AuthState()) {
    checkAuthStatus();
  }

  void _syncCurrency(Map<String, dynamic>? userData) {
    if (userData != null) {
      CurrencyFormatter.setCurrency(
        symbol: userData['currency_symbol'] ?? '₹',
        code: userData['currency_code'] ?? 'INR',
      );
    }
  }

  Future<void> checkAuthStatus() async {
    final token = await _secureStorage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final response = await _dio.get('/auth/session');
        final userData = response.data as Map<String, dynamic>?;
        _syncCurrency(userData);
        state = state.copyWith(isAuthenticated: true, user: userData);
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
      final user = response.data['user'] as Map<String, dynamic>?;
      await _secureStorage.write(key: 'jwt_token', value: token);
      
      _syncCurrency(user);
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
    CurrencyFormatter.setCurrency(symbol: '₹', code: 'INR');
    state = state.copyWith(isAuthenticated: false, user: null);
  }
}
