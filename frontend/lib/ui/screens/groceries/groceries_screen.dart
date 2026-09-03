import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../core/groceries_provider.dart';
import '../../../core/branch_provider.dart';
import 'package:intl/intl.dart';
import '../../../core/currency_formatter.dart';
import '../../../core/responsive.dart';
import '../../../core/app_notifier.dart';

class GroceriesScreen extends ConsumerStatefulWidget {
  const GroceriesScreen({super.key});

  @override
  ConsumerState<GroceriesScreen> createState() => _GroceriesScreenState();
}

class _GroceriesScreenState extends ConsumerState<GroceriesScreen> {
  // We need items and categories available
  void _showEditGroceryModal(BuildContext context, Map<String, Map<String, dynamic>> itemsMap, Map<int, String> categoriesMap, Map<String, dynamic> purchaseToEdit) {
    Map<String, dynamic> formData = {
      'purchase_date': purchaseToEdit['purchase_date'],
      'grocery_item_id': purchaseToEdit['grocery_item_id'],
      'quantity': purchaseToEdit['quantity'].toString(),
      'total_price': purchaseToEdit['total_price'].toString(),
      'vendor_name': purchaseToEdit['vendor_name'] ?? '',
      'notes': purchaseToEdit['notes'] ?? '',
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Grocery Purchase'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: formData['purchase_date'],
                        decoration: const InputDecoration(labelText: 'Date'),
                        readOnly: true,
                        onTap: () async {
                          final initialDate = DateTime.tryParse(formData['purchase_date']) ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              formData['purchase_date'] = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: itemsMap.containsKey(formData['grocery_item_id']) ? formData['grocery_item_id'] : null,
                        decoration: const InputDecoration(labelText: 'Item'),
                        items: itemsMap.entries.map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value['product_name']),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => formData['grocery_item_id'] = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: formData['quantity'],
                              decoration: const InputDecoration(labelText: 'Quantity'),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => formData['quantity'] = v,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              initialValue: formData['total_price'],
                              decoration: const InputDecoration(labelText: 'Total Price (₹)'),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => formData['total_price'] = v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: formData['vendor_name'],
                        decoration: const InputDecoration(labelText: 'Vendor Name'),
                        onChanged: (v) => formData['vendor_name'] = v,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: formData['notes'],
                        decoration: const InputDecoration(labelText: 'Notes'),
                        onChanged: (v) => formData['notes'] = v,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formData['grocery_item_id'] == null || formData['grocery_item_id'] == '') return;
                    double? qty = double.tryParse(formData['quantity']);
                    double? total = double.tryParse(formData['total_price']);
                    if (qty == null || total == null || qty <= 0) {
                      AppNotifier.showError(context, 'Please enter valid quantity and total price.');
                      return;
                    }
                    // Calculate unit price
                    formData['unit_price'] = (total / qty).toString();
                    
                    try {
                      await ref.read(groceriesProvider.notifier).updateGrocery(purchaseToEdit['grocery_purchase_id'], formData);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        AppNotifier.showSuccess(context, 'Purchase updated successfully');
                      }
                    } catch (e) {
                      if (context.mounted) AppNotifier.showError(context, 'Error: $e');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBulkAddGroceryModal(BuildContext context, Map<String, Map<String, dynamic>> itemsMap, Map<int, String> categoriesMap) {
    String globalDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int? selectedCatId = categoriesMap.isNotEmpty ? categoriesMap.keys.first : null;
    
    // State map: item_id -> { quantity, total_price, vendor_name, notes }
    Map<String, Map<String, String>> inputData = {};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final categoryItems = itemsMap.entries.where((e) => e.value['category_id'] == selectedCatId).toList();

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Groceries (Bulk)'),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(globalDate),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => globalDate = DateFormat('yyyy-MM-dd').format(picked));
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(globalDate),
                  )
                ],
              ),
              content: SizedBox(
                width: 1000,
                height: 600,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Pane: Categories
                    Container(
                      width: 250,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: categoriesMap.length,
                              itemBuilder: (context, index) {
                                final catId = categoriesMap.keys.elementAt(index);
                                final catName = categoriesMap.values.elementAt(index);
                                final isSelected = selectedCatId == catId;
                                return ListTile(
                                  title: Text(catName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                  selected: isSelected,
                                  selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
                                  onTap: () => setState(() => selectedCatId = catId),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                String? newCatName;
                                await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Add New Category'),
                                    content: TextFormField(
                                      decoration: const InputDecoration(labelText: 'Category Name'),
                                      onChanged: (v) => newCatName = v,
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Add'),
                                      ),
                                    ],
                                  )
                                );
                                if (newCatName != null && newCatName!.trim().isNotEmpty) {
                                  try {
                                    final createdCat = await createGroceryCategory(ref, newCatName!.trim());
                                    if (!context.mounted) return;
                                    setState(() {
                                      categoriesMap[createdCat['grocery_category_id']] = createdCat['name'];
                                      selectedCatId = createdCat['grocery_category_id'];
                                    });
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    AppNotifier.showError(context, 'Failed to add category: $e');
                                  }
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('New Category'),
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    // Right Pane: Items
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Items in Category', style: Theme.of(context).textTheme.headlineMedium),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    if (selectedCatId == null) return;
                                    String? newItemName;
                                    String? newUnit;
                                    await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Add New Item'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextFormField(
                                              decoration: const InputDecoration(labelText: 'Product Name'),
                                              onChanged: (v) => newItemName = v,
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              decoration: const InputDecoration(labelText: 'Unit (e.g. kg, L, pcs)'),
                                              onChanged: (v) => newUnit = v,
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                          ElevatedButton(
                                            onPressed: (newItemName?.isNotEmpty ?? false) && (newUnit?.isNotEmpty ?? false)
                                                ? () => Navigator.pop(context)
                                                : null,
                                            child: const Text('Add'),
                                          ),
                                        ],
                                      )
                                    );
                                    if (newItemName != null && newItemName!.trim().isNotEmpty && newUnit != null && newUnit!.trim().isNotEmpty) {
                                      try {
                                        final newItem = await createGroceryItem(ref, newItemName!.trim(), selectedCatId!, newUnit!.trim());
                                        if (!context.mounted) return;
                                        setState(() {
                                          itemsMap[newItem['grocery_item_id']] = newItem;
                                        });
                                      } catch (e) {
                                        if (context.mounted) AppNotifier.showError(context, 'Failed to add item: $e');
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('New Item'),
                                )
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: categoryItems.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final itemEntry = categoryItems[index];
                                final itemId = itemEntry.key;
                                final item = itemEntry.value;
                                
                                inputData[itemId] ??= {'quantity': '', 'total_price': '', 'vendor_name': ''};
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text('${item['product_name']} (${item['unit']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          key: ValueKey('qty_$itemId'),
                                          initialValue: inputData[itemId]!['quantity'],
                                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                                          keyboardType: TextInputType.number,
                                          onChanged: (v) => inputData[itemId]!['quantity'] = v,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          key: ValueKey('total_$itemId'),
                                          initialValue: inputData[itemId]!['total_price'],
                                          decoration: const InputDecoration(labelText: 'Total ₹', isDense: true),
                                          keyboardType: TextInputType.number,
                                          onChanged: (v) => inputData[itemId]!['total_price'] = v,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          key: ValueKey('vendor_$itemId'),
                                          initialValue: inputData[itemId]!['vendor_name'],
                                          decoration: const InputDecoration(labelText: 'Vendor Name', isDense: true),
                                          onChanged: (v) => inputData[itemId]!['vendor_name'] = v,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    List<Map<String, dynamic>> finalData = [];
                    for (var entry in inputData.entries) {
                      final itemId = entry.key;
                      final data = entry.value;
                      if (data['quantity']!.trim().isNotEmpty && data['total_price']!.trim().isNotEmpty) {
                        double? qty = double.tryParse(data['quantity']!);
                        double? total = double.tryParse(data['total_price']!);
                        if (qty != null && total != null && qty > 0) {
                          finalData.add({
                            'purchase_date': globalDate,
                            'grocery_item_id': itemId,
                            'quantity': qty.toString(),
                            'unit_price': (total / qty).toString(),
                            'vendor_name': data['vendor_name'],
                            'notes': '',
                          });
                        }
                      }
                    }
                    
                    if (finalData.isEmpty) {
                      AppNotifier.showError(context, 'No valid items entered. Please enter quantity and total price.');
                      return;
                    }
                    
                    try {
                      await ref.read(groceriesProvider.notifier).addGroceryBulk(finalData);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        AppNotifier.showSuccess(context, '${finalData.length} purchases added successfully');
                      }
                    } catch (e) {
                      if (context.mounted) AppNotifier.showError(context, 'Error: $e');
                    }
                  },
                  child: const Text('Submit Groceries'),
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
    final groceriesAsync = ref.watch(groceriesProvider);
    final categoriesAsync = ref.watch(groceryCategoriesProvider);
    final itemsAsync = ref.watch(groceryItemsProvider);
    
    final currentCatFilter = ref.watch(groceryCategoryFilterProvider);
    final currentDateRange = ref.watch(groceryDateRangeProvider);
    final branchId = ref.watch(selectedBranchProvider);
    final canAdd = branchId != null;

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (categoriesData) {
        final categoriesMap = {
          for (var c in categoriesData) c['grocery_category_id'] as int: c['name'] as String
        };
        
        return itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (itemsData) {
            final itemsMap = {
              for (var i in itemsData) i['grocery_item_id'] as String: i
            };
            
            final isMobile = Responsive.isMobile(context);
            
            return Padding(
              padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      Text(
                        'Groceries Management',
                        style: isMobile 
                            ? Theme.of(context).textTheme.headlineMedium 
                            : Theme.of(context).textTheme.displayLarge,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: isMobile ? const Text('') : const Text('Refresh'),
                            onPressed: () {
                              ref.invalidate(groceriesProvider);
                              ref.invalidate(groceryCategoriesProvider);
                              ref.invalidate(groceryItemsProvider);
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: canAdd ? () => _showBulkAddGroceryModal(context, itemsMap, categoriesMap) : null,
                            icon: const Icon(Icons.add),
                            label: isMobile ? const Text('Add') : const Text('Add Grocery(s)'),
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
                            initialDateRange: currentDateRange,
                          );
                          if (newRange != null) {
                            ref.read(groceryDateRangeProvider.notifier).state = newRange;
                          }
                        },
                        icon: const Icon(Icons.calendar_month, color: Color(0xFF2575FC)),
                        label: Text(currentDateRange == null 
                          ? 'All Dates' 
                          : '${DateFormat('MMM d').format(currentDateRange.start)} - ${DateFormat('MMM d').format(currentDateRange.end)}'
                        ),
                      ),
                      
                      if (currentDateRange != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => ref.read(groceryDateRangeProvider.notifier).state = null,
                        )
                      ],
                      
                      const SizedBox(width: 24),
                      
                      // Category Filter
                      DropdownButton<int?>(
                        value: currentCatFilter,
                        hint: const Text('All Categories'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Categories')),
                          ...categoriesMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        ],
                        onChanged: (val) {
                          ref.read(groceryCategoryFilterProvider.notifier).state = val;
                        },
                      ),
                      
                      // TOTAL COST KPI
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Color(0xFF6A11CB)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Filtered Cost', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                groceriesAsync.when(
                                  data: (purchases) {
                                    double total = 0;
                                    for (var p in purchases) {
                                      total += double.tryParse(p['total_price'].toString()) ?? 0;
                                    }
                                    return Text(CurrencyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
                                  },
                                  loading: () => const Text('Loading...'),
                                  error: (e, st) => const Text('Error', style: TextStyle(color: Colors.red)),
                                )
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Table
                  Expanded(
                    child: Card(
                      child: groceriesAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Text('Error: $e')),
                        data: (purchases) {
                          if (purchases.isEmpty) {
                            return const Center(child: Text('No groceries recorded for the selected criteria.'));
                          }
                          return ListView.separated(
                            itemCount: purchases.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = purchases[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryContainer.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shopping_cart_outlined, color: AppTheme.secondary),
                                ),
                                title: Text('${p['product_name']} (${p['unit']})', style: Theme.of(context).textTheme.headlineMedium),
                                subtitle: Text('${p['purchase_date']} • Vendor: ${p['vendor_name'] ?? '-'} • Qty: ${p['quantity']} @ ${CurrencyFormatter.format(p['unit_price'])}'),
                                trailing: isMobile ? Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, color: canAdd ? Colors.blue : Colors.grey),
                                      onPressed: canAdd ? () => _showEditGroceryModal(context, itemsMap, categoriesMap, p) : null,
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: canAdd ? Colors.red : Colors.grey),
                                      onPressed: canAdd ? () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Purchase?'),
                                            content: const Text('Are you sure you want to delete this grocery purchase?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                                                onPressed: () => Navigator.pop(ctx, true), 
                                                child: const Text('Delete')
                                              ),
                                            ],
                                          )
                                        );
                                        if (confirm == true) {
                                          try {
                                            await ref.read(groceriesProvider.notifier).deleteGrocery(p['grocery_purchase_id']);
                                            if (context.mounted) AppNotifier.showSuccess(context, 'Deleted successfully');
                                          } catch (e) {
                                            if (context.mounted) AppNotifier.showError(context, 'Failed to delete: $e');
                                          }
                                        }
                                      } : null,
                                    ),
                                  ],
                                ) : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(CurrencyFormatter.format(p['total_price']), style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.onBackground,
                                    )),
                                    const SizedBox(width: 32),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: canAdd ? Colors.blue : Colors.grey),
                                      onPressed: canAdd ? () => _showEditGroceryModal(context, itemsMap, categoriesMap, p) : null,
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: canAdd ? Colors.red : Colors.grey),
                                      onPressed: canAdd ? () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Purchase?'),
                                            content: const Text('Are you sure you want to delete this grocery purchase?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                                                onPressed: () => Navigator.pop(ctx, true), 
                                                child: const Text('Delete')
                                              ),
                                            ],
                                          )
                                        );
                                        if (confirm == true) {
                                          try {
                                            await ref.read(groceriesProvider.notifier).deleteGrocery(p['grocery_purchase_id']);
                                            if (context.mounted) AppNotifier.showSuccess(context, 'Deleted successfully');
                                          } catch (e) {
                                            if (context.mounted) AppNotifier.showError(context, 'Failed to delete: $e');
                                          }
                                        }
                                      } : null,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }
                      ),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }
}
