import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../core/staff_provider.dart';
import 'package:intl/intl.dart';
import '../../../core/currency_formatter.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  List<Map<String, dynamic>> _bulkData = List.generate(1, (index) => {
    'employee_id': '',
    'first_name': '',
    'last_name': '',
    'email': '',
    'position': 'Waiter',
    'phone': '',
    'monthly_salary': '0.00',
    'join_date': '',
    'branch_id': '1',
  });

  void _showBulkOnboardingModal(BuildContext context) {
    final staffData = ref.read(staffProvider).value ?? [];
    final Set<String> rolesSet = {};
    for (final s in staffData) {
      if (s['position'] != null && s['position'].toString().isNotEmpty) {
        rolesSet.add(s['position'].toString());
      }
    }

    setState(() {
      _bulkData = List.generate(1, (index) => {
        'employee_id': '',
        'first_name': '',
        'last_name': '',
        'email': '',
        'position': 'Waiter',
        'phone': '',
        'monthly_salary': '0.00',
        'join_date': '',
        'branch_id': '1',
      });
    });
    final horizontalScrollController = ScrollController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Onboard new employee(s)'),
              content: SizedBox(
                width: 800,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Scrollbar(
                        controller: horizontalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: DataTable(
                              columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('Emp ID')),
                              DataColumn(label: Text('First Name')),
                              DataColumn(label: Text('Last Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Join Date')),
                              DataColumn(label: Text('Branch ID')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Salary (₹)')),
                              DataColumn(label: Text('')),
                            ],
                            rows: List.generate(_bulkData.length, (index) => DataRow(
                              cells: [
                                DataCell(TextFormField(
                                  initialValue: _bulkData[index]['employee_id'],
                                  onChanged: (val) => _bulkData[index]['employee_id'] = val,
                                  decoration: const InputDecoration(hintText: 'EMP-01', isDense: true)
                                )),
                                DataCell(TextFormField(
                                  initialValue: _bulkData[index]['first_name'],
                                  onChanged: (val) => _bulkData[index]['first_name'] = val,
                                  decoration: const InputDecoration(hintText: 'First Name', isDense: true)
                                )),
                                DataCell(TextFormField(
                                  initialValue: _bulkData[index]['last_name'],
                                  onChanged: (val) => _bulkData[index]['last_name'] = val,
                                  decoration: const InputDecoration(hintText: 'Last Name', isDense: true)
                                )),
                                DataCell(TextFormField(
                                  initialValue: _bulkData[index]['email'],
                                  onChanged: (val) => _bulkData[index]['email'] = val,
                                  decoration: const InputDecoration(hintText: 'Email', isDense: true)
                                )),
                                DataCell(TextFormField(
                                  initialValue: _bulkData[index]['join_date'],
                                  onChanged: (val) => _bulkData[index]['join_date'] = val,
                                  decoration: const InputDecoration(hintText: 'YYYY-MM-DD', isDense: true)
                                )),
                                DataCell(TextFormField(
                                  initialValue: _bulkData[index]['branch_id'],
                                  onChanged: (val) => _bulkData[index]['branch_id'] = val,
                                  decoration: const InputDecoration(hintText: '1', isDense: true),
                                  keyboardType: TextInputType.number
                                )),
                                DataCell(DropdownButtonFormField<String>(
                                  value: _bulkData[index]['position'],
                                  items: (rolesSet.contains(_bulkData[index]['position']) ? rolesSet : {...rolesSet, _bulkData[index]['position']}).map((e) => DropdownMenuItem(value: e as String, child: Text(e.toString()))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _bulkData[index]['position'] = val;
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(hintText: 'Role', isDense: true, border: InputBorder.none),
                                )),
                                DataCell(TextFormField(
                                  initialValue: _bulkData[index]['phone'],
                                  onChanged: (val) => _bulkData[index]['phone'] = val,
                                  decoration: const InputDecoration(hintText: '+91...', isDense: true)
                                )),
                                DataCell(TextFormField(
                                  initialValue: _bulkData[index]['monthly_salary'],
                                  onChanged: (val) => _bulkData[index]['monthly_salary'] = val,
                                  decoration: const InputDecoration(hintText: '0.00', isDense: true), 
                                  keyboardType: TextInputType.number
                                )),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _bulkData.removeAt(index);
                                      });
                                    },
                                  )
                                ),
                              ],
                            )),
                          ),
                        ),
                      ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _bulkData.add({
                              'employee_id': '',
                              'first_name': '',
                              'last_name': '',
                              'email': '',
                              'position': 'Waiter',
                              'phone': '',
                              'monthly_salary': '0.00',
                              'join_date': '',
                              'branch_id': '1',
                            });
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Row'),
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final validItems = _bulkData.where((element) => element['first_name'].toString().trim().isNotEmpty && element['employee_id'].toString().trim().isNotEmpty).map((e) {
                      final map = Map<String, dynamic>.from(e);
                      if (map['branch_id'] != null) {
                        map['branch_id'] = int.tryParse(map['branch_id'].toString()) ?? 1;
                      }
                      if (map['join_date'] == null || map['join_date'].toString().trim().isEmpty) {
                        map.remove('join_date');
                      }
                      return map;
                    }).toList();
                    if (validItems.isEmpty) return;
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
    );
  }

  void _showEditEmployeeModal(BuildContext context, Map<String, dynamic> employee) {
    final staffData = ref.read(staffProvider).value ?? [];
    final Set<String> rolesSet = {};
    for (final s in staffData) {
      if (s['position'] != null && s['position'].toString().isNotEmpty) {
        rolesSet.add(s['position'].toString());
      }
    }

    final formData = Map<String, dynamic>.from(employee);
    if (formData['position'] != null && formData['position'].toString().isNotEmpty) {
      rolesSet.add(formData['position'].toString());
    } else {
      rolesSet.add('Waiter');
      formData['position'] = 'Waiter';
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Employee'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: formData['first_name'],
                  decoration: const InputDecoration(labelText: 'First Name'),
                  onChanged: (v) => formData['first_name'] = v,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: formData['last_name'],
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  onChanged: (v) => formData['last_name'] = v,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: formData['position'],
                  decoration: const InputDecoration(labelText: 'Position'),
                  items: rolesSet.map((e) => DropdownMenuItem(value: e as String, child: Text(e.toString()))).toList(),
                  onChanged: (v) => formData['position'] = v,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: formData['phone'],
                  decoration: const InputDecoration(labelText: 'Phone'),
                  onChanged: (v) => formData['phone'] = v,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: formData['monthly_salary'].toString(),
                  decoration: const InputDecoration(labelText: 'Monthly Salary (₹)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => formData['monthly_salary'] = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(staffProvider.notifier).updateEmployee(employee['employee_id'], formData);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee updated successfully')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }, 
              child: const Text('Save Changes')
            ),
          ],
        );
      }
    );
  }

  void _showProcessSalaryModal(BuildContext context, Map<String, dynamic> employee, DateTime date) {
    Map<String, dynamic> formData = {
      'employee_id': employee['employee_id'],
      'payment_month': date.month,
      'payment_year': date.year,
      'bonus': '0',
      'deductions': '0',
      'payment_mode': 'Bank Transfer',
    };
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            double base = double.tryParse(employee['monthly_salary'].toString()) ?? 0;
            double bonus = double.tryParse(formData['bonus'].toString()) ?? 0;
            double deductions = double.tryParse(formData['deductions'].toString()) ?? 0;
            double net = base + bonus - deductions;

            return AlertDialog(
              title: Text('Process Salary - ${employee['first_name']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Base Salary: ${CurrencyFormatter.format(base)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: formData['bonus'],
                      decoration: const InputDecoration(labelText: 'Bonus (₹)'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        formData['bonus'] = v;
                        setState((){});
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: formData['deductions'],
                      decoration: const InputDecoration(labelText: 'Deductions (₹)'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        formData['deductions'] = v;
                        setState((){});
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: formData['payment_mode'],
                      decoration: const InputDecoration(labelText: 'Payment Mode'),
                      items: ['Bank Transfer', 'Cash', 'UPI', 'Cheque'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => formData['payment_mode'] = v,
                    ),
                    const SizedBox(height: 24),
                    Text('Net Salary to Pay: ${CurrencyFormatter.format(net)}', style: const TextStyle(fontSize: 18, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await processSalaryPayment(ref, formData);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salary processed successfully')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }, 
                  child: const Text('Confirm Payment')
                ),
              ],
            );
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffAsyncValue = ref.watch(staffProvider);
    final salaryPaymentsAsync = ref.watch(salaryPaymentsProvider);
    final selectedMonthYear = ref.watch(salaryMonthYearProvider);

    final currentTab = ref.watch(staffTabProvider);

    return Padding(
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
                      label: const Text('Onboard new employee(s)'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(staffProvider.notifier).fetchStaff();
                        ref.invalidate(salaryPaymentsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleBtn('Employee Register', StaffTab.register, currentTab),
                      _buildToggleBtn('Payroll Settlements', StaffTab.payroll, currentTab),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: currentTab == StaffTab.register ?
                  // Tab 1: Employee Register
                  Card(
                    child: staffAsyncValue.when(
                      data: (staff) {
                        if (staff.isEmpty) {
                          return const Center(child: Text("No employees found. Add some using Bulk Onboarding."));
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
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                child: Text(fullName.isNotEmpty ? fullName[0] : '?', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(fullName, style: Theme.of(context).textTheme.headlineMedium),
                              subtitle: Text('${employee['position']} • ${employee['phone']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${CurrencyFormatter.format(employee['monthly_salary'])}/mo', style: Theme.of(context).textTheme.bodyLarge),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppTheme.primary),
                                    onPressed: () => _showEditEmployeeModal(context, employee),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Remove Employee?'),
                                          content: const Text('Are you sure you want to deactivate this employee?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                                              onPressed: () => Navigator.pop(ctx, true), 
                                              child: const Text('Remove', style: TextStyle(color: Colors.white))
                                            ),
                                          ],
                                        )
                                      );
                                      if (confirm == true) {
                                        try {
                                          await ref.read(staffProvider.notifier).deleteEmployee(employee['employee_id']);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee removed')));
                                        } catch(e) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                        }
                                      }
                                    },
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
                  ) // Tab 1 Card
                  : // Tab 2: Payroll Settlements
                  Card(
                    child: Column(
                      children: [
                        // Month/Year Filter
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Payroll for ${DateFormat('MMMM yyyy').format(selectedMonthYear)}', style: Theme.of(context).textTheme.headlineMedium),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  // Simple month picker using standard date picker constrained to months isn't built-in perfectly, 
                                  // but we can use showDatePicker and just use the month/year.
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedMonthYear,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    ref.read(salaryMonthYearProvider.notifier).state = DateTime(picked.year, picked.month, 1);
                                  }
                                },
                                icon: const Icon(Icons.calendar_month),
                                label: const Text('Change Month'),
                              )
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: staffAsyncValue.when(
                            data: (staff) {
                              if (staff.isEmpty) {
                                return const Center(child: Text("No employees to pay."));
                              }
                              
                              return salaryPaymentsAsync.when(
                                data: (payments) {
                                  // Create a map of paid employees
                                  final paidMap = {
                                    for (var p in payments) p['employee_id']: p
                                  };
                                  
                                  return ListView.separated(
                                    itemCount: staff.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final employee = staff[index];
                                      final fullName = "${employee['first_name']} ${employee['last_name'] ?? ''}".trim();
                                      final empId = employee['employee_id'];
                                      final isPaid = paidMap.containsKey(empId);
                                      final payment = paidMap[empId];
                                      
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        leading: Icon(
                                          isPaid ? Icons.check_circle : Icons.payments_outlined, 
                                          color: isPaid ? Colors.green : AppTheme.secondaryContainer, 
                                          size: 32
                                        ),
                                        title: Text(fullName, style: Theme.of(context).textTheme.headlineMedium),
                                        subtitle: Text(isPaid ? 'Paid on ${payment!['payment_date']}' : 'Pending Salary'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isPaid ? CurrencyFormatter.format(payment!['net_salary']) : CurrencyFormatter.format(employee['monthly_salary']), 
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isPaid ? Colors.green : null
                                              )
                                            ),
                                            const SizedBox(width: 24),
                                            if (isPaid)
                                              const Chip(
                                                label: Text('Paid', style: TextStyle(color: Colors.white)),
                                                backgroundColor: Colors.green,
                                              )
                                            else
                                              OutlinedButton(
                                                onPressed: () => _showProcessSalaryModal(context, employee, selectedMonthYear),
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
                                error: (e, st) => Center(child: Text('Error loading salaries: $e')),
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, stackTrace) => Center(child: Text('Error: $error')),
                          ),
                        ),
                      ],
                    ),
                  ), // closes Card 2
            ), // closes Expanded
          ], // closes children of Column
        ), // closes Column
      ); // closes Padding
  }

  Widget _buildToggleBtn(String label, StaffTab tab, StaffTab currentTab) {
    final isSelected = tab == currentTab;
    return GestureDetector(
      onTap: () => ref.read(staffTabProvider.notifier).state = tab,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
