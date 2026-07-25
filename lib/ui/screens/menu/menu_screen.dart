import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../core/menu_provider.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final List<Map<String, dynamic>> _bulkData = List.generate(4, (index) => {
    'name': '',
    'category': 'Main Course',
    'price': '0.00',
    'is_vegetarian': true,
    'is_available': true,
  });

  void _showBulkEntryModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Item Entry'),
          content: SizedBox(
            width: double.maxFinite,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Item Name')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Price (₹)')),
                DataColumn(label: Text('Veg/Non-Veg')),
              ],
              rows: List.generate(4, (index) => DataRow(
                cells: [
                  DataCell(TextFormField(
                    onChanged: (val) => _bulkData[index]['name'] = val,
                    decoration: const InputDecoration(hintText: 'e.g. Dal Makhani')
                  )),
                  DataCell(DropdownButtonFormField<String>(
                    value: _bulkData[index]['category'],
                    items: ['Starters', 'Main Course', 'Breads', 'Rice'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) {
                      if (val != null) _bulkData[index]['category'] = val;
                    },
                    decoration: const InputDecoration(hintText: 'Category'),
                  )),
                  DataCell(TextFormField(
                    onChanged: (val) => _bulkData[index]['price'] = val,
                    decoration: const InputDecoration(hintText: '0.00'), keyboardType: TextInputType.number
                  )),
                  DataCell(Switch(
                    value: _bulkData[index]['is_vegetarian'], 
                    onChanged: (v){
                      setState(() {
                        _bulkData[index]['is_vegetarian'] = v;
                      });
                    }, 
                    activeColor: Colors.green
                  )),
                ],
              )),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final validItems = _bulkData.where((element) => element['name'].toString().isNotEmpty).toList();
                ref.read(menuNotifierProvider.notifier).addMenuBulk(validItems);
                Navigator.pop(context);
              }, 
              child: const Text('Save All')
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuAsyncValue = ref.watch(menuNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Menu Catalog',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showBulkEntryModal(context),
                    icon: const Icon(Icons.table_rows_outlined),
                    label: const Text('Bulk Item Entry'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(menuNotifierProvider.notifier).fetchMenu(),
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
              child: menuAsyncValue.when(
                data: (menuItems) {
                  if (menuItems.isEmpty) {
                    return const Center(child: Text("No menu items found."));
                  }
                  return ListView.separated(
                    itemCount: menuItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final isVeg = item['is_vegetarian'] ?? true;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: isVeg ? Colors.green : AppTheme.error,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isVeg ? Colors.green : AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        title: Text(item['name'], style: Theme.of(context).textTheme.headlineMedium),
                        subtitle: Text(item['category'], style: Theme.of(context).textTheme.labelSmall),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹ ${item['price']}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 32),
                            Switch(
                              value: item['is_available'] ?? true,
                              activeColor: AppTheme.primary,
                              onChanged: (val) {
                                // TODO: Call update API
                              },
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {},
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
          )
        ],
      ),
    );
  }
}
