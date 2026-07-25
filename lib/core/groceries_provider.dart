import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'branch_provider.dart';

final groceriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final queryParams = branchId != null ? {'branch_id': branchId} : null;
  final response = await dio.get('/groceries/purchases', queryParameters: queryParams);
  return List<Map<String, dynamic>>.from(response.data);
});
