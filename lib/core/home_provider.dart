import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'branch_provider.dart';

final homeDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final homeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final selectedBranch = ref.watch(selectedBranchProvider);
  final dateRange = ref.watch(homeDateRangeProvider);
  
  final queryParams = <String, dynamic>{};
  if (selectedBranch != null) {
    queryParams['branch_id'] = selectedBranch;
  }
  if (dateRange != null) {
    queryParams['tables_start_date'] = dateRange.start.toIso8601String().split('T')[0];
    queryParams['tables_end_date'] = dateRange.end.toIso8601String().split('T')[0];
  }
  
  final response = await dio.get('/dashboard/summary', queryParameters: queryParams.isNotEmpty ? queryParams : null);
  return response.data;
});

