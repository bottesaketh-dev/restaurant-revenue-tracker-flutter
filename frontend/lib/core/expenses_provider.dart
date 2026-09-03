import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';

import 'package:flutter/material.dart';

final expenseDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);
final expenseCategoryFilterProvider = StateProvider<int?>((ref) => null);

final expenseCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/expenses/categories');
  return List<Map<String, dynamic>>.from(response.data);
});

Future<Map<String, dynamic>> createExpenseCategory(WidgetRef ref, String name) async {
  final dio = ref.read(dioProvider);
  final response = await dio.post('/expenses/categories', data: {'name': name});
  ref.invalidate(expenseCategoriesProvider);
  return response.data;
}

final expensesProvider = StateNotifierProvider<ExpensesNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final branchId = ref.watch(selectedBranchProvider);
  final dateRange = ref.watch(expenseDateRangeProvider);
  final categoryId = ref.watch(expenseCategoryFilterProvider);
  return ExpensesNotifier(ref.watch(dioProvider), branchId, dateRange, categoryId);
});

class ExpensesNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final int? _branchId;
  final DateTimeRange? _dateRange;
  final int? _categoryId;

  ExpensesNotifier(this._dio, this._branchId, this._dateRange, this._categoryId) : super(const AsyncValue.loading()) {
    fetchExpenses();
  }

  Future<void> fetchExpenses() async {
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{};
      if (_branchId != null) queryParams['branch_id'] = _branchId;
      if (_categoryId != null) queryParams['category_id'] = _categoryId;
      if (_dateRange != null) {
        final range = _dateRange!;
        queryParams['start_date'] = '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
        queryParams['end_date'] = '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}';
      }
      final response = await _dio.get('/expenses/', queryParameters: queryParams);
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response.data));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addExpenseBulk(List<Map<String, dynamic>> items) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.post('/expenses/bulk', data: items, queryParameters: queryParams);
      fetchExpenses();
    } catch (e) {
      throw Exception('Failed to bulk add: $e');
    }
  }

  Future<void> addExpense(Map<String, dynamic> item) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.post('/expenses/', data: item, queryParameters: queryParams);
      fetchExpenses();
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  Future<void> updateExpense(int expenseId, Map<String, dynamic> item) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.put('/expenses/$expenseId', data: item, queryParameters: queryParams);
      fetchExpenses();
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  Future<void> deleteExpense(int expenseId) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.delete('/expenses/$expenseId', queryParameters: queryParams);
      fetchExpenses();
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }
}
