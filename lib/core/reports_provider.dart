import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'branch_provider.dart';

// State provider for global date range filter
final dateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

Map<String, dynamic> _buildQueryParams(int? branchId, DateTimeRange? dateRange) {
  final queryParams = <String, dynamic>{};
  if (branchId != null) queryParams['branch_id'] = branchId;
  if (dateRange != null) {
    queryParams['start_date'] = '${dateRange.start.year}-${dateRange.start.month.toString().padLeft(2, '0')}-${dateRange.start.day.toString().padLeft(2, '0')}';
    queryParams['end_date'] = '${dateRange.end.year}-${dateRange.end.month.toString().padLeft(2, '0')}-${dateRange.end.day.toString().padLeft(2, '0')}';
  }
  return queryParams;
}

final profitLossProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final dateRange = ref.watch(dateRangeProvider);
  final response = await dio.get('/reports/profit-loss', queryParameters: _buildQueryParams(branchId, dateRange));
  return response.data;
});

final salesTrendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final dateRange = ref.watch(dateRangeProvider);
  final response = await dio.get('/reports/sales-trends', queryParameters: _buildQueryParams(branchId, dateRange));
  return List<Map<String, dynamic>>.from(response.data);
});

final metricsSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final dateRange = ref.watch(dateRangeProvider);
  final response = await dio.get('/reports/metrics-summary', queryParameters: _buildQueryParams(branchId, dateRange));
  return response.data;
});

final categoryRevenueProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final dateRange = ref.watch(dateRangeProvider);
  final response = await dio.get('/reports/category-revenue', queryParameters: _buildQueryParams(branchId, dateRange));
  return List<Map<String, dynamic>>.from(response.data);
});

final topItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final dateRange = ref.watch(dateRangeProvider);
  final response = await dio.get('/reports/top-items', queryParameters: _buildQueryParams(branchId, dateRange));
  return List<Map<String, dynamic>>.from(response.data);
});

final expenseBreakdownProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final dateRange = ref.watch(dateRangeProvider);
  final response = await dio.get('/reports/expense-breakdown', queryParameters: _buildQueryParams(branchId, dateRange));
  return List<Map<String, dynamic>>.from(response.data);
});

final branchComparisonProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final dateRange = ref.watch(dateRangeProvider);
  // Do not pass branchId since this is for all branches
  final response = await dio.get('/reports/branch-comparison', queryParameters: _buildQueryParams(null, dateRange));
  return List<Map<String, dynamic>>.from(response.data);
});

