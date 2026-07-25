import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'branch_provider.dart';

final profitLossProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final queryParams = branchId != null ? {'branch_id': branchId} : null;
  final response = await dio.get('/reports/profit-loss', queryParameters: queryParams);
  return response.data;
});

final salesTrendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final queryParams = branchId != null ? {'branch_id': branchId} : null;
  final response = await dio.get('/reports/sales-trends', queryParameters: queryParams);
  return List<Map<String, dynamic>>.from(response.data);
});
