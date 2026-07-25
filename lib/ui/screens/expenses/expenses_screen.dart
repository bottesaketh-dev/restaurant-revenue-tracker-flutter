import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../core/expenses_provider.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final List<Map<String, dynamic>> _bulkData = List.generate(4, (index) => {
    'expense_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    'category_id': 1,
    'description': '',
    'amount': '0.00',
    'payment_mode': 'Cash',
    'vendor_name': '',
  });

  void _showBulkExpenseModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Expense Entry'),
          content: SizedBox(
            width: double.maxFinite,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Category ID')),
                DataColumn(label: Text('Description')),
                DataColumn(label: Text('Amount (₹)')),
              ],
              rows: List.generate(4, (index) => DataRow(
                cells: [
                  DataCell(TextFormField(
                    initialValue: _bulkData[index]['expense_date'],
                    onChanged: (val) => _bulkData[index]['expense_date'] = val,
                    decoration: const InputDecoration(hintText: 'YYYY-MM-DD')
                  )),
                  DataCell(TextFormField(
                    onChanged: (val) => _bulkData[index]['category_id'] = int.tryParse(val) ?? 1,
                    decoration: const InputDecoration(hintText: '1'), keyboardType: TextInputType.number
                  )),
                  DataCell(TextFormField(
                    onChanged: (val) => _bulkData[index]['description'] = val,
                    decoration: const InputDecoration(hintText: 'Desc...')
                  )),
                  DataCell(TextFormField(
                    onChanged: (val) => _bulkData[index]['amount'] = val,
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
                final validItems = _bulkData.where((element) => element['description'].toString().isNotEmpty).toList();
                ref.read(expensesProvider.notifier).addExpenseBulk(validItems);
                Navigator.pop(context);
              }, 
              child: const Text('Submit Expenses')
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsyncValue = ref.watch(expensesProvider);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'General Expenses',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showBulkExpenseModal(context),
                    icon: const Icon(Icons.playlist_add_outlined),
                    label: const Text('Bulk Expense Entry'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(expensesProvider.notifier).fetchExpenses(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Card(
              child: expensesAsyncValue.when(
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const Center(child: Text("No expenses found."));
                  }
                  return ListView.separated(
                    itemCount: expenses.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final exp = expenses[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryContainer.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.payments_outlined, color: AppTheme.secondary),
                        ),
                        title: Text(exp['description'], style: Theme.of(context).textTheme.headlineMedium),
                        subtitle: Text('${exp['expense_date']} • ID: ${exp['category_id']}'),
                        trailing: Text('₹ ${exp['amount']}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onBackground,
                        )),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
          )
        ],
      ),
    );
  }
}
