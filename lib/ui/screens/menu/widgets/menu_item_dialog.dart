import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/menu_provider.dart';
import '../../../../theme/app_theme.dart';

class _ItemEntry {
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController category;
  final TextEditingController desc;
  bool isVeg;
  bool isAvailable;

  _ItemEntry({
    required String initialName,
    required String initialPrice,
    required String initialCategory,
    required String initialDesc,
    this.isVeg = true,
    this.isAvailable = true,
  })  : name = TextEditingController(text: initialName),
        price = TextEditingController(text: initialPrice),
        category = TextEditingController(text: initialCategory),
        desc = TextEditingController(text: initialDesc);

  void dispose() {
    name.dispose();
    price.dispose();
    category.dispose();
    desc.dispose();
  }
}

class MenuItemDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? item; // If null, it's a create (bulk capable). If provided, it's a single edit.

  const MenuItemDialog({super.key, this.item});

  @override
  ConsumerState<MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends ConsumerState<MenuItemDialog> {
  final List<_ItemEntry> _entries = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _entries.add(_ItemEntry(
        initialName: widget.item?['name'] ?? '',
        initialPrice: widget.item?['price']?.toString() ?? '',
        initialCategory: widget.item?['category'] ?? '',
        initialDesc: widget.item?['description'] ?? '',
        isVeg: widget.item?['is_vegetarian'] ?? true,
        isAvailable: widget.item?['is_available'] ?? true,
      ));
    } else {
      _addNewEntryRow();
    }
  }

  void _addNewEntryRow() {
    setState(() {
      _entries.add(_ItemEntry(
        initialName: '',
        initialPrice: '',
        initialCategory: _entries.isNotEmpty ? _entries.last.category.text : '', // Copy previous category for convenience
        initialDesc: '',
      ));
    });
  }

  void _removeEntryRow(int index) {
    if (_entries.length > 1) {
      setState(() {
        _entries[index].dispose();
        _entries.removeAt(index);
      });
    }
  }

  @override
  void dispose() {
    for (var entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // Validation
    final validPayloads = <Map<String, dynamic>>[];
    for (var entry in _entries) {
      final name = entry.name.text.trim();
      final priceStr = entry.price.text.trim();
      final category = entry.category.text.trim();

      // If it's bulk add, we skip completely empty rows. If it's a single edit, we complain.
      if (name.isEmpty && priceStr.isEmpty && category.isEmpty && widget.item == null) {
        continue;
      }

      if (name.isEmpty || priceStr.isEmpty || category.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill Name, Price, and Category for all entries.')));
        return;
      }

      validPayloads.add({
        "name": name,
        "description": entry.desc.text.trim(),
        "category": category,
        "price": double.tryParse(priceStr) ?? 0.0,
        "is_vegetarian": entry.isVeg,
        "is_available": entry.isAvailable,
        "image_url": widget.item?['image_url']
      });
    }

    if (validPayloads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid items to save.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.item == null) {
        // Bulk Add
        await ref.read(menuNotifierProvider.notifier).addMenuBulk(validPayloads);
      } else {
        // Single Edit
        await ref.read(menuNotifierProvider.notifier).updateMenuItem(widget.item!['menu_item_id'], validPayloads.first);
      }

      // Refresh categories
      ref.invalidate(categoriesProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.item == null ? '${validPayloads.length} item(s) added!' : 'Item updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isEdit = widget.item != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isEdit ? 'Edit Menu Item' : 'Add Item(s) to Menu', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (!isEdit)
                  OutlinedButton.icon(
                    onPressed: _addNewEntryRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Row'),
                  )
              ],
            ),
            const SizedBox(height: 24),
            
            // Header for columns
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, right: 48.0), // padding right for the delete button space
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Item Name *', style: Theme.of(context).textTheme.labelLarge)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: Text('Category *', style: Theme.of(context).textTheme.labelLarge)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: Text('Price (₹) *', style: Theme.of(context).textTheme.labelLarge)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: Text('Veg?', style: Theme.of(context).textTheme.labelLarge)),
                ],
              ),
            ),
            const Divider(),
            
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _entries.length,
                separatorBuilder: (_, __) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name & Desc
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            TextField(
                              controller: entry.name,
                              decoration: const InputDecoration(hintText: 'e.g. Dal Makhani', isDense: true),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: entry.desc,
                              decoration: const InputDecoration(hintText: 'Description (Optional)', isDense: true),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Category
                      Expanded(
                        flex: 2,
                        child: categoriesAsync.when(
                          data: (categories) {
                            return Autocomplete<String>(
                              initialValue: TextEditingValue(text: entry.category.text),
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return categories;
                                }
                                return categories.where((String option) {
                                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (String selection) {
                                entry.category.text = selection;
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                controller.addListener(() {
                                  entry.category.text = controller.text;
                                });
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Main Course',
                                    isDense: true,
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => TextField(
                            controller: entry.category,
                            decoration: const InputDecoration(hintText: 'Category', isDense: true),
                          )
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Price
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: entry.price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '0.00', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Veg Toggle
                      Expanded(
                        flex: 2,
                        child: Switch(
                          value: entry.isVeg,
                          activeColor: Colors.green,
                          inactiveThumbColor: AppTheme.error,
                          inactiveTrackColor: AppTheme.error.withOpacity(0.5),
                          onChanged: (val) => setState(() => entry.isVeg = val),
                        ),
                      ),
                      
                      // Delete Row Button
                      if (!isEdit)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: _entries.length > 1 ? () => _removeEntryRow(index) : null,
                        )
                      else 
                        const SizedBox(width: 48), // Spacer to align headers correctly for edit
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
