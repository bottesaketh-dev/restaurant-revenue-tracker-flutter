import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../core/menu_provider.dart';
import '../../../core/kitchen_provider.dart';
import '../../../core/groceries_provider.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Inventory & Recipes'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Recipes'),
            Tab(text: 'Kitchen Stock'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RecipesTab(),
          _InventoryTab(),
        ],
      ),
    );
  }
}

class _RecipesTab extends ConsumerWidget {
  const _RecipesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuItemsAsync = ref.watch(menuProvider);

    return menuItemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (menuItems) {
        if (menuItems.isEmpty) {
          return const Center(child: Text('No menu items found. Add some in the Menu Catalog.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: const Icon(Icons.restaurant_menu, color: AppTheme.primary),
                ),
                title: Text(item['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Price: ₹${item['price']}'),
                trailing: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _RecipeDialog(menuItem: item),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Manage Recipe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryStockProvider);
    final groceriesAsync = ref.watch(groceryItemsProvider);

    return inventoryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (inventory) {
        return groceriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (groceries) {
            if (inventory.isEmpty) {
              return const Center(child: Text('No stock data. Stock is updated when purchases are made.'));
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(AppTheme.primary.withOpacity(0.1)),
                      columns: const [
                        DataColumn(label: Text('Grocery Item', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: inventory.map((stock) {
                        final grocery = groceries.firstWhere(
                          (g) => g['grocery_item_id'] == stock['grocery_item_id'],
                          orElse: () => {'product_name': 'Unknown', 'unit': '-'},
                        );

                        return DataRow(
                          cells: [
                            DataCell(Text(grocery['product_name'] ?? 'Unknown')),
                            DataCell(Text('${stock['current_stock']}')),
                            DataCell(Text(grocery['unit'] ?? '-')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RecipeDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> menuItem;
  const _RecipeDialog({required this.menuItem});

  @override
  ConsumerState<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends ConsumerState<_RecipeDialog> {
  List<Map<String, dynamic>> _ingredients = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingRecipe();
  }

  void _loadExistingRecipe() {
    final recipeAsync = ref.read(recipeProvider(widget.menuItem['menu_item_id']));
    recipeAsync.whenData((recipe) {
      setState(() {
        _ingredients = List<Map<String, dynamic>>.from(recipe);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final groceriesAsync = ref.watch(groceryItemsProvider);
    final recipeAsync = ref.watch(recipeProvider(widget.menuItem['menu_item_id']));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recipe for ${widget.menuItem['name']}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            
            recipeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading recipe: $err'),
              data: (_) {
                return groceriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Error loading groceries: $err'),
                  data: (groceries) {
                    if (groceries.isEmpty) {
                      return const Text('No groceries available to pick from.');
                    }

                    return Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (_ingredients.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No ingredients added to this recipe yet.'),
                              ),
                            ..._ingredients.asMap().entries.map((entry) {
                              final index = entry.key;
                              final ingredient = entry.value;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<String>(
                                          decoration: const InputDecoration(
                                            labelText: 'Ingredient',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          value: ingredient['grocery_item_id'],
                                          items: groceries.map((g) {
                                            return DropdownMenuItem<String>(
                                              value: g['grocery_item_id'],
                                              child: Text('${g['product_name']} (${g['unit']})'),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _ingredients[index]['grocery_item_id'] = val;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          decoration: const InputDecoration(
                                            labelText: 'Quantity',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          initialValue: ingredient['quantity_required']?.toString() ?? '',
                                          onChanged: (val) {
                                            setState(() {
                                              _ingredients[index]['quantity_required'] = double.tryParse(val) ?? 0.0;
                                            });
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _ingredients.removeAt(index);
                                          });
                                        },
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _ingredients.add({
                                    'grocery_item_id': groceries.first['grocery_item_id'],
                                    'quantity_required': 0.0,
                                  });
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Ingredient'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    setState(() => _isSaving = true);
                    final success = await ref.read(recipeProvider(widget.menuItem['menu_item_id']).notifier)
                        .updateRecipe(widget.menuItem['menu_item_id'], _ingredients);
                    setState(() => _isSaving = false);
                    
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recipe saved successfully')),
                      );
                      Navigator.pop(context);
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to save recipe')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Recipe'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
