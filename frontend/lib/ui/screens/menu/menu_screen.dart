import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../core/menu_provider.dart';
import 'widgets/menu_item_dialog.dart';
import '../../../core/currency_formatter.dart';
import '../../../core/responsive.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  bool _onlyVeg = false;
  bool _onlyNonVeg = false;

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? AppTheme.primary : Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuAsyncValue = ref.watch(menuNotifierProvider);
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
                'Menu Catalog',
                style: isMobile 
                    ? Theme.of(context).textTheme.headlineMedium 
                    : Theme.of(context).textTheme.displayLarge,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const MenuItemDialog(),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: isMobile ? const Text('Add') : const Text('Add Item(s) to Menu'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(menuNotifierProvider.notifier).fetchMenu(),
                    icon: const Icon(Icons.refresh),
                    label: isMobile ? const Text('') : const Text('Refresh'),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          
          // Filters
          isMobile 
            ? Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search menu items...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('Only Veg'),
                        selected: _onlyVeg,
                        onSelected: (val) {
                          setState(() {
                            _onlyVeg = val;
                            if (val) _onlyNonVeg = false;
                          });
                        },
                        selectedColor: Colors.green.withValues(alpha: 0.2),
                        checkmarkColor: Colors.green,
                      ),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Only Non-Veg'),
                        selected: _onlyNonVeg,
                        onSelected: (val) {
                          setState(() {
                            _onlyNonVeg = val;
                            if (val) _onlyVeg = false;
                          });
                        },
                        selectedColor: AppTheme.error.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.error,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search menu items...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  FilterChip(
                    label: const Text('Only Veg'),
                    selected: _onlyVeg,
                    onSelected: (val) {
                      setState(() {
                        _onlyVeg = val;
                        if (val) _onlyNonVeg = false;
                      });
                    },
                    selectedColor: Colors.green.withValues(alpha: 0.2),
                    checkmarkColor: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Only Non-Veg'),
                    selected: _onlyNonVeg,
                    onSelected: (val) {
                      setState(() {
                        _onlyNonVeg = val;
                        if (val) _onlyVeg = false;
                      });
                    },
                    selectedColor: AppTheme.error.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.error,
                  ),
                ],
              ),
          const SizedBox(height: 16),
          
          // Categories
          menuAsyncValue.when(
            data: (menuItems) {
              final categories = menuItems.map((i) => i['category'] as String).toSet().toList();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('All', _selectedCategory == null, () {
                      setState(() { _selectedCategory = null; });
                    }),
                    ...categories.map((c) => Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: _buildCategoryChip(c, _selectedCategory == c, () {
                            setState(() { _selectedCategory = c; });
                          }),
                        )),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),
          
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: menuAsyncValue.when(
                data: (menuItems) {
                  // Apply filters
                  var filtered = menuItems.where((item) {
                    // Search Filter
                    if (_searchQuery.isNotEmpty) {
                      final name = item['name'].toString().toLowerCase();
                      if (!name.contains(_searchQuery.toLowerCase())) return false;
                    }
                    // Category Filter
                    if (_selectedCategory != null && item['category'] != _selectedCategory) {
                      return false;
                    }
                    // Veg/Non-Veg Filter
                    final isVeg = item['is_vegetarian'] ?? true;
                    if (_onlyVeg && !isVeg) return false;
                    if (_onlyNonVeg && isVeg) return false;
                    
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text("No menu items found."));
                  }
                  
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isVeg = item['is_vegetarian'] ?? true;
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                image: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                                    ? DecorationImage(image: NetworkImage(item['image_url']), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: item['image_url'] == null || item['image_url'].toString().isEmpty
                                  ? const Icon(Icons.fastfood, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Container(
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
                          ],
                        ),
                        title: Text(item['name'], style: Theme.of(context).textTheme.headlineMedium),
                        subtitle: Text(item['category'], style: Theme.of(context).textTheme.labelSmall),
                        trailing: isMobile ? Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(CurrencyFormatter.format(item['price']), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                            Switch(
                              value: item['is_available'] ?? true,
                              activeThumbColor: Colors.green,
                              onChanged: (val) async {
                                final updated = Map<String, dynamic>.from(item);
                                updated['is_available'] = val;
                                await ref.read(menuNotifierProvider.notifier).updateMenuItem(item['menu_item_id'], updated);
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => MenuItemDialog(item: item),
                                  );
                                } else if (val == 'delete') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Item'),
                                      content: Text('Are you sure you want to delete ${item['name']}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () {
                                            ref.read(menuNotifierProvider.notifier).deleteMenuItem(item['menu_item_id']);
                                            Navigator.pop(context);
                                          }, 
                                          child: const Text('Delete', style: TextStyle(color: AppTheme.error))
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ) : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(CurrencyFormatter.format(item['price']), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 32),
                            Switch(
                              value: item['is_available'] ?? true,
                              activeThumbColor: Colors.green,
                              onChanged: (val) async {
                                final updated = Map<String, dynamic>.from(item);
                                updated['is_available'] = val;
                                await ref.read(menuNotifierProvider.notifier).updateMenuItem(item['menu_item_id'], updated);
                              },
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => MenuItemDialog(item: item),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppTheme.error),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Item'),
                                    content: Text('Are you sure you want to delete ${item['name']}?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () {
                                          ref.read(menuNotifierProvider.notifier).deleteMenuItem(item['menu_item_id']);
                                          Navigator.pop(context);
                                        }, 
                                        child: const Text('Delete', style: TextStyle(color: AppTheme.error))
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
