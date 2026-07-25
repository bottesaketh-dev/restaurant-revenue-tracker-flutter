import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'branch_provider.dart';

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final selectedBranch = ref.watch(selectedBranchProvider);
  
  final queryParams = selectedBranch != null ? {'branch_id': selectedBranch} : null;
  final response = await dio.get('/dashboard/summary', queryParameters: queryParams);
  return response.data;
});
