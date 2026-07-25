import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../core/staff_provider.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  final List<Map<String, dynamic>> _bulkData = List.generate(3, (index) => {
    'employee_id': '',
    'first_name': '',
    'last_name': '',
    'position': 'Waiter',
    'phone': '',
    'monthly_salary': '0.00',
  });

  void _showBulkOnboardingModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Employee Onboarding'),
          content: SizedBox(
            width: double.maxFinite,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Emp ID')),
                DataColumn(label: Text('Full Name')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Salary')),
              ],
              rows: List.generate(3, (index) => DataRow(
                cells: [
                  DataCell(TextFormField(
                    onChanged: (val) => _bulkData[index]['employee_id'] = val,
                    decoration: const InputDecoration(hintText: 'EMP-01')
                  )),
                  DataCell(TextFormField(
                    onChanged: (val) {
                      final parts = val.split(' ');
                      _bulkData[index]['first_name'] = parts.first;
                      _bulkData[index]['last_name'] = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                    },
                    decoration: const InputDecoration(hintText: 'John Doe')
                  )),
                  DataCell(DropdownButtonFormField<String>(
                    value: _bulkData[index]['position'],
                    items: ['Chef', 'Waiter', 'Cashier', 'Cleaner'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) {
                      if (val != null) _bulkData[index]['position'] = val;
                    },
                    decoration: const InputDecoration(hintText: 'Role'),
                  )),
                  DataCell(TextFormField(
                    onChanged: (val) => _bulkData[index]['phone'] = val,
                    decoration: const InputDecoration(hintText: '+91...')
                  )),
                  DataCell(TextFormField(
                    onChanged: (val) => _bulkData[index]['monthly_salary'] = val,
                    decoration: const InputDecoration(hintText: '0.00'), keyboardType: TextInputType.number
                  )),
                ],
              )),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final validItems = _bulkData.where((element) => element['first_name'].toString().isNotEmpty && element['employee_id'].toString().isNotEmpty).toList();
                ref.read(staffProvider.notifier).addStaffBulk(validItems);
                Navigator.pop(context);
              }, 
              child: const Text('Save All Employees')
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffAsyncValue = ref.watch(staffProvider);

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Staff Directory',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showBulkOnboardingModal(context),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Bulk Onboarding'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.read(staffProvider.notifier).fetchStaff(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: TabBar(
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey.shade600,
                tabs: const [
                  Tab(text: 'Employee Register'),
                  Tab(text: 'Payroll Settlements'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Employee Register
                  Card(
                    child: staffAsyncValue.when(
                      data: (staff) {
                        if (staff.isEmpty) {
                          return const Center(child: Text("No employees found."));
                        }
                        return ListView.separated(
                          itemCount: staff.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final employee = staff[index];
                            final fullName = "${employee['first_name']} ${employee['last_name'] ?? ''}".trim();
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withOpacity(0.1),
                                child: Text(fullName.isNotEmpty ? fullName[0] : '?', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(fullName, style: Theme.of(context).textTheme.headlineMedium),
                              subtitle: Text('${employee['position']} • ${employee['phone']}'),
                              trailing: Text('₹ ${employee['monthly_salary']}/mo', style: Theme.of(context).textTheme.bodyLarge),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) => Center(child: Text('Error: $error')),
                    ),
                  ),
                  // Tab 2: Payroll Settlements
                  Card(
                    child: staffAsyncValue.when(
                      data: (staff) {
                        if (staff.isEmpty) {
                          return const Center(child: Text("No employees to pay."));
                        }
                        return ListView.separated(
                          itemCount: staff.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final employee = staff[index];
                            final fullName = "${employee['first_name']} ${employee['last_name'] ?? ''}".trim();
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              leading: const Icon(Icons.payments_outlined, color: AppTheme.secondaryContainer, size: 32),
                              title: Text(fullName, style: Theme.of(context).textTheme.headlineMedium),
                              subtitle: const Text('Pending Salary - October 2023'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('₹ ${employee['monthly_salary']}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 24),
                                  OutlinedButton(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primary,
                                      side: const BorderSide(color: AppTheme.primary),
                                    ),
                                    child: const Text('Process Payment'),
                                  )
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) => Center(child: Text('Error: $error')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
