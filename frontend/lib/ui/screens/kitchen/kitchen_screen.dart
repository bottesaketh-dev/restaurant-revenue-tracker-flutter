import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../core/menu_provider.dart';
import '../../../core/kitchen_provider.dart';
import '../../../core/groceries_provider.dart';
import '../../../core/currency_formatter.dart';
import '../../../core/responsive.dart';

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(kitchenTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Inventory & Recipes'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(inventoryStockProvider);
                ref.invalidate(menuProvider);
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0, left: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToggleBtn('Recipes', KitchenTab.recipes, currentTab, ref),
                          _buildToggleBtn('Kitchen Stock', KitchenTab.stock, currentTab, ref),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: currentTab == KitchenTab.recipes ? const _RecipesTab() : const _InventoryTab(),
    );
  }

  Widget _buildToggleBtn(String label, KitchenTab tab, KitchenTab currentTab, WidgetRef ref) {
    final isSelected = tab == currentTab;
    return GestureDetector(
      onTap: () => ref.read(kitchenTabProvider.notifier).state = tab,
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

class _RecipesTab extends ConsumerWidget {
  const _RecipesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuItemsAsync = ref.watch(menuProvider);
    final searchQuery = ref.watch(kitchenSearchQueryProvider);
    final selectedCategory = ref.watch(kitchenSelectedCategoryProvider);

    return menuItemsAsync.when(skipLoadingOnRefresh: false, 
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (menuItems) {
        if (menuItems.isEmpty) {
          return const Center(child: Text('No menu items found. Add some in the Menu Catalog.'));
        }

        // Get unique categories
        final categories = menuItems.map((item) => item['category'] as String).toSet().toList();

        // Filter items
        final filteredItems = menuItems.where((item) {
          final matchesSearch = (item['name'] as String? ?? '').toLowerCase().contains(searchQuery.toLowerCase());
          final matchesCategory = selectedCategory == null || item['category'] == selectedCategory;
          return matchesSearch && matchesCategory;
        }).toList();

        return Column(
          children: [
            // Search & Category Filters
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search menu items...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (val) => ref.read(kitchenSearchQueryProvider.notifier).state = val,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryBtn('All', null, selectedCategory, ref),
                        ...categories.map((cat) => _buildCategoryBtn(cat, cat, selectedCategory, ref)).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Recipe List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.restaurant_menu, color: AppTheme.primary),
                        ),
                        title: Text(item['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Price: ${CurrencyFormatter.format(item['price'])} • ${item['category']}'),
                        children: [
                          _RecipeDetailsView(menuItem: item),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryBtn(String label, String? category, String? selectedCategory, WidgetRef ref) {
    final isSelected = category == selectedCategory;
    return GestureDetector(
      onTap: () => ref.read(kitchenSelectedCategoryProvider.notifier).state = category,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeDetailsView extends ConsumerWidget {
  final Map<String, dynamic> menuItem;
  const _RecipeDetailsView({required this.menuItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeProvider(menuItem['menu_item_id']));
    final groceriesAsync = ref.watch(groceryItemsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ingredients Required',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _RecipeDialog(menuItem: menuItem),
                  );
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Manage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          recipeAsync.when(skipLoadingOnRefresh: false, 
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error: $err'),
            data: (ingredients) {
              if (ingredients.isEmpty) {
                return const Text('No ingredients defined. Click Manage to add some.',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
              }

              return groceriesAsync.when(skipLoadingOnRefresh: false, 
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => const Text('Error loading groceries'),
                data: (groceries) {
                  return Column(
                    children: ingredients.map((ing) {
                      final grocery = groceries.firstWhere(
                        (g) => g['grocery_item_id'] == ing['grocery_item_id'],
                        orElse: () => {'product_name': 'Unknown', 'unit': '-'},
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 8, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(grocery['product_name'] ?? 'Unknown')),
                            Text('${ing['quantity_required']} ${grocery['unit']}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryStockProvider);
    final groceriesAsync = ref.watch(groceryItemsProvider);

    return inventoryAsync.when(skipLoadingOnRefresh: false, 
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (inventory) {
        return groceriesAsync.when(skipLoadingOnRefresh: false, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (groceries) {
            if (inventory.isEmpty) {
              return const Center(child: Text('No stock data. Stock is updated when purchases are made.'));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                final stock = inventory[index];
                final grocery = groceries.firstWhere(
                  (g) => g['grocery_item_id'] == stock['grocery_item_id'],
                  orElse: () => {'product_name': 'Unknown', 'unit': '-'},
                );

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.inventory_2, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                grocery['product_name'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text('Current Stock', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${stock['current_stock']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                grocery['unit'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
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
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final groceriesAsync = ref.watch(groceryItemsProvider);
    final recipeAsync = ref.watch(recipeProvider(widget.menuItem['menu_item_id']));

    if (recipeAsync.hasValue && !_initialized) {
      // Defer state update till after build to avoid errors, or just set it locally since it's used in the build below
      _ingredients = List<Map<String, dynamic>>.from(recipeAsync.value!);
      _initialized = true;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: Responsive.isMobile(context) ? MediaQuery.of(context).size.width * 0.9 : 600,
        padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 24),
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
            
            recipeAsync.when(skipLoadingOnRefresh: false, 
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading recipe: $err'),
              data: (_) {
                return groceriesAsync.when(skipLoadingOnRefresh: false, 
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
                                          initialValue: ingredient['grocery_item_id'],
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
                    
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recipe saved successfully')),
                      );
                      Navigator.pop(context);
                    } else if (context.mounted) {
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

