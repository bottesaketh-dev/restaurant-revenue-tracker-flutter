import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final selectedBranchProvider = StateProvider<int?>((ref) => null);

final branchListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/branches/');
  return List<Map<String, dynamic>>.from(response.data);
});
