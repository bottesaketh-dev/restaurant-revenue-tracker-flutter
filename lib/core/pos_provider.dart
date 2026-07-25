import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';
import 'menu_provider.dart';

enum OrderMode { dineIn, takeaway }

final posOrderModeProvider = StateProvider<OrderMode>((ref) => OrderMode.dineIn);
final selectedTableProvider = StateProvider<String?>((ref) => null);
final posSearchQueryProvider = StateProvider<String>((ref) => '');
final posSelectedCategoryProvider = StateProvider<String?>((ref) => null);

final posTablesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final queryParams = branchId != null ? {'branch_id': branchId} : null;
  final response = await dio.get('/billing/tables', queryParameters: queryParams);
  
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
      // We also need a way to trigger KOT when an item is removed.
      // But if the cart has no unprinted items after removal, KOT button won't activate!
      // The easiest fix is to just let KOT button be active if there's any pending changes.
      // For now, let's just make the KOT button logic in UI check if we need sync.
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
      await _dio.post('/billing/tables/$tableId/kot', data: requestData);
      
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
      final response = await _dio.get('/billing/tables/$tableId/order');
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
}

final posCartProvider = StateNotifierProvider<CartNotifier, List<CartItemModel>>((ref) {
  return CartNotifier(ref);
});
