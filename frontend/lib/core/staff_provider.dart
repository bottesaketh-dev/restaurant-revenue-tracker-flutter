import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'branch_provider.dart';
enum StaffTab { register, payroll }

final staffTabProvider = StateProvider<StaffTab>((ref) => StaffTab.register);

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
      final allEmployees = List<Map<String, dynamic>>.from(response.data);
      final activeEmployees = allEmployees.where((e) => e['is_active'] == true).toList();
      state = AsyncValue.data(activeEmployees);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addStaffBulk(List<Map<String, dynamic>> items) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.post('/employees/bulk', data: items, queryParameters: queryParams);
      fetchStaff();
    } catch (e) {
      throw Exception('Failed to bulk add: $e');
    }
  }

  Future<void> updateEmployee(String employeeId, Map<String, dynamic> data) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.put('/employees/$employeeId', data: data, queryParameters: queryParams);
      fetchStaff();
    } catch (e) {
      throw Exception('Failed to update employee: $e');
    }
  }

  Future<void> deleteEmployee(String employeeId) async {
    try {
      final queryParams = _branchId != null ? {'branch_id': _branchId} : null;
      await _dio.delete('/employees/$employeeId', queryParameters: queryParams);
      fetchStaff();
    } catch (e) {
      throw Exception('Failed to delete employee: $e');
    }
  }
}

// -------------------------
// Salary Providers
// -------------------------

final salaryMonthYearProvider = StateProvider<DateTime>((ref) => DateTime.now());

final salaryPaymentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final branchId = ref.watch(selectedBranchProvider);
  final date = ref.watch(salaryMonthYearProvider);
  
  try {
    Map<String, dynamic> queryParams = {
      'month': date.month,
      'year': date.year,
    };
    if (branchId != null) queryParams['branch_id'] = branchId;

    final response = await dio.get('/employees/salary/all', queryParameters: queryParams);
    return List<Map<String, dynamic>>.from(response.data);
  } catch (e) {
    throw Exception('Failed to fetch salary payments: $e');
  }
});

Future<void> processSalaryPayment(WidgetRef ref, Map<String, dynamic> data) async {
  final dio = ref.read(dioProvider);
  final branchId = ref.read(selectedBranchProvider);
  try {
    final queryParams = branchId != null ? {'branch_id': branchId} : null;
    await dio.post('/employees/salary', data: data, queryParameters: queryParams);
    ref.invalidate(salaryPaymentsProvider);
  } catch (e) {
    throw Exception('Failed to process salary payment: $e');
  }
}
