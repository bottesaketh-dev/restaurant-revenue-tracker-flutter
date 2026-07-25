import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';

final staffProvider = StateNotifierProvider<StaffNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final branchId = ref.watch(selectedBranchProvider);
  return StaffNotifier(ref.watch(dioProvider), branchId);
});

class StaffNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final int? _branchId;

  StaffNotifier(this._dio, this._branchId) : super(const AsyncValue.loading()) {
    fetchStaff();
  }

  Future<void> fetchStaff() async {
    state = const AsyncValue.loading();
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      final response = await _dio.get('/employees/', queryParameters: queryParams);
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response.data));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addStaffBulk(List<Map<String, dynamic>> items) async {
    try {
      await _dio.post('/employees/bulk', data: items);
      fetchStaff();
    } catch (e) {
      throw Exception('Failed to bulk add: $e');
    }
  }
}
