import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/menu_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/app_notifier.dart';

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
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
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
        AppNotifier.showError(context, 'Please fill Name, Price, and Category for all entries.');
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
      AppNotifier.showError(context, 'No valid items to save.');
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
        AppNotifier.showSuccess(context, widget.item == null ? '${validPayloads.length} item(s) added!' : 'Item updated!');
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'Error: $e');
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
              ],
            ),
            const SizedBox(height: 24),
            
            Flexible(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: DataTable(
                        columnSpacing: 16,
                        columns: [
                          const DataColumn(label: Text('Item Name *')),
                          const DataColumn(label: Text('Description')),
                          const DataColumn(label: Text('Category *')),
                          const DataColumn(label: Text('Price (₹) *')),
                          const DataColumn(label: Text('Veg?')),
                          if (!isEdit) const DataColumn(label: Text('')),
                        ],
                        rows: List.generate(_entries.length, (index) {
                          final entry = _entries[index];
                          return DataRow(
                            cells: [
                              DataCell(SizedBox(
                                width: 150,
                                child: TextField(
                                  controller: entry.name,
                                  decoration: const InputDecoration(hintText: 'e.g. Dal Makhani', isDense: true),
                                ),
                              )),
                              DataCell(SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: entry.desc,
                                  decoration: const InputDecoration(hintText: 'Description (Optional)', isDense: true),
                                ),
                              )),
                              DataCell(SizedBox(
                                width: 150,
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
                              )),
                              DataCell(SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: entry.price,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(hintText: '0.00', isDense: true),
                                ),
                              )),
                              DataCell(Switch(
                                value: entry.isVeg,
                                activeThumbColor: Colors.green,
                                inactiveThumbColor: AppTheme.error,
                                inactiveTrackColor: AppTheme.error.withValues(alpha: 0.5),
                                onChanged: (val) => setState(() => entry.isVeg = val),
                              )),
                              if (!isEdit)
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: _entries.length > 1 ? () => _removeEntryRow(index) : null,
                                  )
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            if (!isEdit) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _addNewEntryRow,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Row'),
              )
            ],
            const SizedBox(height: 16),
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
