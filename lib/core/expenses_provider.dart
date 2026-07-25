import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';

final expensesProvider = StateNotifierProvider<ExpensesNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final branchId = ref.watch(selectedBranchProvider);
  return ExpensesNotifier(ref.watch(dioProvider), branchId);
});

class ExpensesNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final int? _branchId;

  ExpensesNotifier(this._dio, this._branchId) : super(const AsyncValue.loading()) {
    fetchExpenses();
  }

  Future<void> fetchExpenses() async {
    state = const AsyncValue.loading();
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      final response = await _dio.get('/expenses/', queryParameters: queryParams);
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response.data));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addExpenseBulk(List<Map<String, dynamic>> items) async {
    try {
      await _dio.post('/expenses/bulk', data: items);
      fetchExpenses();
    } catch (e) {
      throw Exception('Failed to bulk add: $e');
    }
  }
}
