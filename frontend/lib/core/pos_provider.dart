import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';
import 'restaurant_provider.dart';
import 'menu_provider.dart';
import 'kitchen_provider.dart';

enum OrderMode { dineIn, takeaway }

final posOrderModeProvider = StateProvider<OrderMode>((ref) => OrderMode.dineIn);
final selectedTableProvider = StateProvider<String?>((ref) => null);
final posSearchQueryProvider = StateProvider<String>((ref) => '');
final posSelectedCategoryProvider = StateProvider<String?>((ref) => null);

class PosTablesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final dio = ref.watch(dioProvider);
    final branchId = ref.watch(selectedBranchProvider);
    final restaurantId = ref.watch(selectedRestaurantIdProvider);
    final queryParams = <String, dynamic>{};
    if (branchId != null) queryParams['branch_id'] = branchId;
    if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
    final response = await dio.get('/billing/tables', queryParameters: queryParams.isNotEmpty ? queryParams : null);
    
    List<Map<String, dynamic>> tables = List<Map<String, dynamic>>.from(response.data);
    
    // Sort occupied first, then unoccupied, both by table_id numerically
    tables.sort((a, b) {
      final bool aOccupied = a['status'] == 'occupied';
      final bool bOccupied = b['status'] == 'occupied';
      
      if (aOccupied && !bOccupied) return -1;
      if (!aOccupied && bOccupied) return 1;
      
      // Extract integer from table_id string
      int getTableNum(String id) {
        final match = RegExp(r'\d+').firstMatch(id);
        return match != null ? int.parse(match.group(0)!) : 0;
      }
      
      final numA = getTableNum(a['table_id'] as String);
      final numB = getTableNum(b['table_id'] as String);
      
      if (numA != numB) {
        return numA.compareTo(numB);
      }
      
      // Fallback to string comparison if numbers are the same or not found
      return (a['table_id'] as String).compareTo(b['table_id'] as String);
    });
    
    return tables;
  }

  Future<void> fetchTables() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> addTablesBulk(List<Map<String, dynamic>> tables) async {
    final dio = ref.read(dioProvider);
    final branchId = ref.read(selectedBranchProvider);
    final restaurantId = ref.read(selectedRestaurantIdProvider);
    final queryParams = <String, dynamic>{};
    if (branchId != null) queryParams['branch_id'] = branchId;
    if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
    await dio.post('/billing/tables/bulk', data: tables, queryParameters: queryParams.isNotEmpty ? queryParams : null);
    await fetchTables();
  }

  Future<void> updateTable(String tableId, Map<String, dynamic> data) async {
    final dio = ref.read(dioProvider);
    final branchId = ref.read(selectedBranchProvider);
    final restaurantId = ref.read(selectedRestaurantIdProvider);
    final queryParams = <String, dynamic>{};
    if (branchId != null) queryParams['branch_id'] = branchId;
    if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
    await dio.put('/billing/tables/$tableId', data: data, queryParameters: queryParams.isNotEmpty ? queryParams : null);
    await fetchTables();
  }

  Future<void> deleteTable(String tableId) async {
    final dio = ref.read(dioProvider);
    final branchId = ref.read(selectedBranchProvider);
    final restaurantId = ref.read(selectedRestaurantIdProvider);
    final queryParams = <String, dynamic>{};
    if (branchId != null) queryParams['branch_id'] = branchId;
    if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
    await dio.delete('/billing/tables/$tableId', queryParameters: queryParams.isNotEmpty ? queryParams : null);
    await fetchTables();
  }
}

final posTablesProvider = AsyncNotifierProvider<PosTablesNotifier, List<Map<String, dynamic>>>(() {
  return PosTablesNotifier();
});

class CartItemModel {
  final Map<String, dynamic> menuItem;
  final int quantity;
  final bool isKotPrinted;

  CartItemModel({
    required this.menuItem,
    required this.quantity,
    this.isKotPrinted = false,
  });

  CartItemModel copyWith({
    Map<String, dynamic>? menuItem,
    int? quantity,
    bool? isKotPrinted,
  }) {
    return CartItemModel(
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      isKotPrinted: isKotPrinted ?? this.isKotPrinted,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItemModel>> {
  final Ref _ref;
  final Dio _dio;
  
  CartNotifier(this._ref) 
    : _dio = _ref.watch(dioProvider), 
      super([]);

  void addItem(Map<String, dynamic> menuItem) {
    final existingIndex = state.indexWhere((item) => item.menuItem['menu_item_id'] == menuItem['menu_item_id'] && !item.isKotPrinted);
    
    if (existingIndex >= 0) {
      // increase quantity of unprinted item
      final updated = List<CartItemModel>.from(state);
      updated[existingIndex] = updated[existingIndex].copyWith(
        quantity: updated[existingIndex].quantity + 1,
      );
      state = updated;
    } else {
      // add new
      state = [...state, CartItemModel(menuItem: menuItem, quantity: 1)];
    }
  }

  void updateQuantity(int index, int delta) {
    final updated = List<CartItemModel>.from(state);
    final newQuantity = updated[index].quantity + delta;
    
    if (newQuantity <= 0) {
      updated.removeAt(index);
    } else {
      updated[index] = updated[index].copyWith(
        quantity: newQuantity, 
        isKotPrinted: false
      );
    }
    state = updated;
  }

  Future<void> printKot(String tableId, OrderMode mode) async {
    final requestData = {
      "items": state.map((item) => {
        "menu_item_id": item.menuItem['menu_item_id'],
        "quantity": item.quantity,
        "price": double.parse(item.menuItem['price'].toString()),
        "notes": ""
      }).toList(),
      "order_type": mode == OrderMode.dineIn ? "dine_in" : "takeaway"
    };

    try {
      final branchId = _ref.read(selectedBranchProvider);
      final restaurantId = _ref.read(selectedRestaurantIdProvider);
      final queryParams = <String, dynamic>{};
      if (branchId != null) queryParams['branch_id'] = branchId;
      if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
      await _dio.post('/billing/tables/$tableId/kot', data: requestData, queryParameters: queryParams.isNotEmpty ? queryParams : null);
      
      // Mark as printed
      state = state.map((item) {
        return item.copyWith(isKotPrinted: true);
      }).toList();
      
      // Refresh tables to reflect occupancy
      _ref.invalidate(posTablesProvider);
      
    } catch (e) {
      throw Exception("Failed to send KOT: $e");
    }
  }
  
  Future<void> loadActiveOrder(String tableId) async {
    try {
      final branchId = _ref.read(selectedBranchProvider);
      final restaurantId = _ref.read(selectedRestaurantIdProvider);
      final queryParams = <String, dynamic>{};
      if (branchId != null) queryParams['branch_id'] = branchId;
      if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
      final response = await _dio.get('/billing/tables/$tableId/order', queryParameters: queryParams.isNotEmpty ? queryParams : null);
      if (response.data == null || response.data == "") {
        state = [];
        return;
      }
      final itemsList = response.data['items'] as List;
      
      final menuItemsAsync = _ref.read(menuProvider);
      if (menuItemsAsync.hasValue) {
        final allMenu = menuItemsAsync.value!;
        
        final List<CartItemModel> loadedCart = [];
        for (var item in itemsList) {
          final menuItem = allMenu.firstWhere((m) => m['menu_item_id'] == item['menu_item_id'], orElse: () => {});
          if (menuItem.isNotEmpty) {
            loadedCart.add(CartItemModel(
              menuItem: menuItem,
              quantity: item['quantity'],
              isKotPrinted: true,
            ));
          }
        }
        state = loadedCart;
      }
    } catch (e) {
      // 404 means no active order, which is fine
      state = [];
    }
  }
  
  void clearCart() {
    state = [];
  }

  Future<Map<String, dynamic>> checkout({
    required String tableId,
    required String paymentMode,
    required double tipAmount,
    required double cashAmount,
    required double upiAmount,
    required double cardAmount,
    bool autoPrint = true,
  }) async {
    try {
      final requestData = {
        "payment_mode": paymentMode,
        "tip_amount": tipAmount,
        "cash_amount": cashAmount,
        "upi_amount": upiAmount,
        "card_amount": cardAmount,
        "auto_print": autoPrint,
      };
      
      final branchId = _ref.read(selectedBranchProvider);
      final restaurantId = _ref.read(selectedRestaurantIdProvider);
      final queryParams = <String, dynamic>{};
      if (branchId != null) queryParams['branch_id'] = branchId;
      if (restaurantId != null) queryParams['restaurant_id'] = restaurantId;
      final response = await _dio.post('/billing/tables/$tableId/checkout', data: requestData, queryParameters: queryParams.isNotEmpty ? queryParams : null);
      
      // Clear cart locally
      state = [];
      // Refresh table status
      _ref.invalidate(posTablesProvider);
      // Refresh inventory stock
      _ref.invalidate(inventoryStockProvider);
      
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception("Checkout failed: $e");
    }
  }

  Future<void> reprintBill(String billId) async {
    try {
      await _dio.post('/billing/bills/$billId/print');
    } catch (e) {
      throw Exception("Print failed: $e");
    }
  }

  Future<void> testThermalPrinter() async {
    try {
      await _dio.post('/billing/printer/test');
    } catch (e) {
      throw Exception("Printer test failed: $e");
    }
  }
}

final posCartProvider = StateNotifierProvider<CartNotifier, List<CartItemModel>>((ref) {
  return CartNotifier(ref);
});
