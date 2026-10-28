import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'branch_provider.dart';
import 'restaurant_provider.dart';
import 'currency_formatter.dart';

final homeDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final homeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final selectedRestaurant = ref.watch(selectedRestaurantIdProvider);
  final selectedBranch = ref.watch(selectedBranchProvider);
  final dateRange = ref.watch(homeDateRangeProvider);
  
  final queryParams = <String, dynamic>{};
  if (selectedRestaurant != null) {
    queryParams['restaurant_id'] = selectedRestaurant;
  }
  if (selectedBranch != null) {
    queryParams['branch_id'] = selectedBranch;
  }
  if (dateRange != null) {
    queryParams['tables_start_date'] = dateRange.start.toIso8601String().split('T')[0];
    queryParams['tables_end_date'] = dateRange.end.toIso8601String().split('T')[0];
  }
  
  final response = await dio.get('/dashboard/summary', queryParameters: queryParams.isNotEmpty ? queryParams : null);
  final data = Map<String, dynamic>.from(response.data);
  
  if (data['currency_symbol'] != null) {
    CurrencyFormatter.setCurrency(
      symbol: data['currency_symbol'] ?? '₹',
      code: data['currency_code'] ?? 'INR',
    );
  }
  return data;
});

