import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../core/expenses_provider.dart';
import 'package:intl/intl.dart';
import '../../../core/currency_formatter.dart';
import '../../../core/responsive.dart';
import '../../../core/app_notifier.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  // Common Expense Modal for Add (Single/Bulk) and Edit
  void _showExpenseModal(BuildContext context, Map<int, String> categoriesMap, {Map<String, dynamic>? expenseToEdit}) {
    // If editing, we just have 1 row. If adding, we can start with 1 row and allow adding more.
    final bool isEditing = expenseToEdit != null;
    
    List<Map<String, dynamic>> formData = [
      if (isEditing)
        {
          'expense_date': expenseToEdit['expense_date'],
          'category_id': expenseToEdit['category_id'],
          'description': expenseToEdit['description'],
          'amount': expenseToEdit['amount'].toString(),
          'payment_mode': expenseToEdit['payment_mode'] ?? 'Cash',
          'vendor_name': expenseToEdit['vendor_name'] ?? '',
          'receipt_number': expenseToEdit['receipt_number'] ?? '',
        }
      else
        {
          'expense_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'category_id': categoriesMap.isNotEmpty ? categoriesMap.keys.first : 1,
          'description': '',
          'amount': '0.00',
          'payment_mode': 'Cash',
          'vendor_name': '',
          'receipt_number': '',
        }
    ];
    
    final ScrollController horizontalScrollController = ScrollController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Expense' : 'Add Expense(s)'),
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
                          columns: [
                            const DataColumn(label: Text('Date')),
                            const DataColumn(label: Text('Category')),
                            const DataColumn(label: Text('Description')),
                            const DataColumn(label: Text('Amount (₹)')),
                            const DataColumn(label: Text('Vendor Name')),
                            const DataColumn(label: Text('Receipt #')),
                            if (!isEditing) const DataColumn(label: Text('')), // for delete row button
                          ],
                          rows: List.generate(formData.length, (index) {
                            return DataRow(
                              cells: [
                                DataCell(TextFormField(
                                  initialValue: formData[index]['expense_date'],
                                  onChanged: (val) => formData[index]['expense_date'] = val,
                                  decoration: const InputDecoration(hintText: 'YYYY-MM-DD', isDense: true),
                                )),
                                DataCell(DropdownButtonFormField<int>(
                                  initialValue: categoriesMap.containsKey(formData[index]['category_id']) ? formData[index]['category_id'] : (categoriesMap.isNotEmpty ? categoriesMap.keys.first : null),
                                  items: [
                                    ...categoriesMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                                    const DropdownMenuItem(value: -1, child: Text('+ Add New Category', style: TextStyle(color: Colors.blue))),
                                  ],
                                  onChanged: (val) async {
                                    if (val == -1) {
                                      String? newCategoryName;
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Add Category'),
                                          content: TextField(
                                            autofocus: true,
                                            onChanged: (v) => newCategoryName = v,
                                            decoration: const InputDecoration(hintText: 'Category Name'),
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Add'),
                                            ),
                                          ],
                                        )
                                      );
                                      if (newCategoryName != null && newCategoryName!.trim().isNotEmpty) {
                                        try {
                                          final newCat = await createExpenseCategory(ref, newCategoryName!.trim());
                                          setState(() {
                                            categoriesMap[newCat['expense_category_id']] = newCat['name'];
                                            formData[index]['category_id'] = newCat['expense_category_id'];
                                          });
                                        } catch (e) {
                                          if (context.mounted) AppNotifier.showError(context, 'Failed to add category: $e');
                                          setState(() {
                                            formData[index]['category_id'] = categoriesMap.isNotEmpty ? categoriesMap.keys.first : 1;
                                          });
                                        }
                                      } else {
                                        setState(() {
                                          formData[index]['category_id'] = categoriesMap.isNotEmpty ? categoriesMap.keys.first : 1;
                                        });
                                      }
                                    } else if (val != null) {
                                      setState(() {
                                        formData[index]['category_id'] = val;
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                                )),
                                DataCell(TextFormField(
                                  initialValue: formData[index]['description'],
                                  onChanged: (val) => formData[index]['description'] = val,
                                  decoration: const InputDecoration(hintText: 'Description', isDense: true),
                                )),
                                DataCell(TextFormField(
                                  initialValue: formData[index]['amount'],
                                  onChanged: (val) => formData[index]['amount'] = val,
                                  decoration: const InputDecoration(hintText: '0.00', isDense: true),
                                  keyboardType: TextInputType.number,
                                )),
                                DataCell(TextFormField(
                                  initialValue: formData[index]['vendor_name'],
                                  onChanged: (val) => formData[index]['vendor_name'] = val,
                                  decoration: const InputDecoration(hintText: 'Vendor Name', isDense: true),
                                )),
                                DataCell(TextFormField(
                                  initialValue: formData[index]['receipt_number'],
                                  onChanged: (val) => formData[index]['receipt_number'] = val,
                                  decoration: const InputDecoration(hintText: 'Receipt #', isDense: true),
                                )),
                                if (!isEditing)
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          formData.removeAt(index);
                                        });
                                      },
                                    )
                                  ),
                              ],
                            );
                          }),
                        ),
                      ),
                      ),
                      ),
                      if (!isEditing) ...[
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              formData.add({
                                'expense_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                                'category_id': categoriesMap.isNotEmpty ? categoriesMap.keys.first : 1,
                                'description': '',
                                'amount': '0.00',
                                'payment_mode': 'Cash',
                                'vendor_name': '',
                                'receipt_number': '',
                              });
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Another Row'),
                        )
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final validItems = formData.where((element) => element['description'].toString().trim().isNotEmpty).toList();
                    if (validItems.isEmpty) return;

                    if (isEditing) {
                      ref.read(expensesProvider.notifier).updateExpense(expenseToEdit['expense_id'], validItems.first);
                    } else {
                      if (validItems.length == 1) {
                        ref.read(expensesProvider.notifier).addExpense(validItems.first);
                      } else {
                        ref.read(expensesProvider.notifier).addExpenseBulk(validItems);
                      }
                    }
                    Navigator.pop(context);
                  }, 
                  child: Text(isEditing ? 'Save Changes' : 'Submit Expenses')
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _confirmDelete(BuildContext context, int expenseId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(expensesProvider.notifier).deleteExpense(expenseId);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsyncValue = ref.watch(expensesProvider);
    final dateRange = ref.watch(expenseDateRangeProvider);
    final categoryId = ref.watch(expenseCategoryFilterProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    final Map<int, String> categoriesMap = categoriesAsync.maybeWhen(
      data: (cats) => {for (var c in cats) c['expense_category_id'] as int: c['name'] as String},
      orElse: () => {1: 'Utilities', 2: 'Maintenance', 3: 'Marketing', 4: 'Miscellaneous'},
    );

    final isMobile = Responsive.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Text(
                'General Expenses',
                style: isMobile 
                    ? Theme.of(context).textTheme.headlineMedium 
                    : Theme.of(context).textTheme.displayLarge,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showExpenseModal(context, Map.from(categoriesMap)),
                    icon: const Icon(Icons.add),
                    label: isMobile ? const Text('Add') : const Text('Add Expense(s)'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(expenseCategoriesProvider);
                      ref.read(expensesProvider.notifier).fetchExpenses();
                    },
                    icon: const Icon(Icons.refresh),
                    label: isMobile ? const Text('') : const Text('Refresh'),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),

          // FILTER BAR & KPI
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date Filter
              OutlinedButton.icon(
                onPressed: () async {
                  final newRange = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: dateRange,
                  );
                  if (newRange != null) {
                    ref.read(expenseDateRangeProvider.notifier).state = newRange;
                  }
                },
                icon: const Icon(Icons.calendar_month, color: Color(0xFF2575FC)),
                label: Text(dateRange == null 
                  ? 'All Dates' 
                  : '${DateFormat('MMM d').format(dateRange.start)} - ${DateFormat('MMM d').format(dateRange.end)}'
                ),
              ),
              if (dateRange != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => ref.read(expenseDateRangeProvider.notifier).state = null,
                )
              ],
              
              const SizedBox(width: 24),
              
              // Category Filter
              DropdownButton<int?>(
                value: categoryId,
                hint: const Text('All Categories'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ...categoriesMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                ],
                onChanged: (val) {
                  ref.read(expenseCategoryFilterProvider.notifier).state = val;
                },
              ),
              
              // TOTAL COST KPI
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF6A11CB)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Filtered Cost', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        expensesAsyncValue.when(skipLoadingOnRefresh: false, 
                          data: (expenses) {
                            double total = 0;
                            for (var e in expenses) {
                              total += double.tryParse(e['amount'].toString()) ?? 0;
                            }
                            return Text(CurrencyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
                          },
                          loading: () => const Text('Loading...'),
                          error: (_, __) => const Text('Error'),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
          
          const SizedBox(height: 24),
          
          // DATA LIST
          Expanded(
            child: Card(
              child: expensesAsyncValue.when(skipLoadingOnRefresh: false, 
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const Center(child: Text("No expenses found matching the current filters."));
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
                            color: AppTheme.secondaryContainer.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.payments_outlined, color: AppTheme.secondary),
                        ),
                        title: Text(exp['description'], style: Theme.of(context).textTheme.headlineMedium),
                        subtitle: Text('${exp['expense_date']} • ${categoriesMap[exp['category_id']] ?? 'Category ${exp['category_id']}'}'),
                        trailing: isMobile ? Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showExpenseModal(context, Map.from(categoriesMap), expenseToEdit: exp),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(context, exp['expense_id']),
                            ),
                          ],
                        ) : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(CurrencyFormatter.format(exp['amount']), style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onBackground,
                            )),
                            const SizedBox(width: 32),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showExpenseModal(context, Map.from(categoriesMap), expenseToEdit: exp),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(context, exp['expense_id']),
                            ),
                          ],
                        ),
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

