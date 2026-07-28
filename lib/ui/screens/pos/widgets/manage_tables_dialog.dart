import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/pos_provider.dart';
import '../../../../theme/app_theme.dart';

class _TableEntry {
  final TextEditingController tableId;
  final TextEditingController capacity;
  final bool isExisting;
  final String originalCapacity;

  _TableEntry({
    required String initialTableId,
    required String initialCapacity,
    this.isExisting = false,
  })  : tableId = TextEditingController(text: initialTableId),
        capacity = TextEditingController(text: initialCapacity),
        originalCapacity = initialCapacity;

  void dispose() {
    tableId.dispose();
    capacity.dispose();
  }

  bool get isModified => isExisting && capacity.text.trim() != originalCapacity;
}

class ManageTablesDialog extends ConsumerStatefulWidget {
  const ManageTablesDialog({super.key});

  @override
  ConsumerState<ManageTablesDialog> createState() => _ManageTablesDialogState();
}

class _ManageTablesDialogState extends ConsumerState<ManageTablesDialog> {
  final ScrollController _scrollController = ScrollController();
  final List<_TableEntry> _existingEntries = [];
  final List<_TableEntry> _newEntries = [];
  bool _isLoading = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _addNewEntryRow();
  }

  void _addNewEntryRow() {
    setState(() {
      _newEntries.add(_TableEntry(initialTableId: '', initialCapacity: '4'));
    });
  }

  void _removeNewEntryRow(int index) {
    if (_newEntries.length > 1) {
      setState(() {
        _newEntries[index].dispose();
        _newEntries.removeAt(index);
      });
    }
  }

  @override
  void dispose() {
    for (var entry in _existingEntries) {
      entry.dispose();
    }
    for (var entry in _newEntries) {
      entry.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteExisting(int index) async {
    final entry = _existingEntries[index];
    try {
      await ref.read(posTablesProvider.notifier).deleteTable(entry.tableId.text);
      setState(() {
        entry.dispose();
        _existingEntries.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Table ${entry.tableId.text} deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    try {
      // 1. Save new tables
      final validPayloads = <Map<String, dynamic>>[];
      for (var entry in _newEntries) {
        final tid = entry.tableId.text.trim();
        final capStr = entry.capacity.text.trim();

        if (tid.isNotEmpty && capStr.isNotEmpty) {
          validPayloads.add({
            "table_id": tid,
            "capacity": int.tryParse(capStr) ?? 4,
          });
        }
      }

      if (validPayloads.isNotEmpty) {
        await ref.read(posTablesProvider.notifier).addTablesBulk(validPayloads);
      }

      // 2. Update existing modified tables
      for (var entry in _existingEntries) {
        if (entry.isModified) {
          final tid = entry.tableId.text.trim();
          final capStr = entry.capacity.text.trim();
          await ref.read(posTablesProvider.notifier).updateTable(tid, {
            "capacity": int.tryParse(capStr) ?? 4,
          });
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tables saved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DataRow _buildRow(_TableEntry entry, bool isExisting, int index) {
    final inputDecoration = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
    );

    return DataRow(
      cells: [
        DataCell(
          isExisting
              ? Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    entry.tableId.text,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                )
              : SizedBox(
                  width: 150,
                  child: TextField(
                    controller: entry.tableId,
                    decoration: inputDecoration.copyWith(hintText: 'e.g. T1, V1'),
                  ),
                ),
        ),
        DataCell(
          SizedBox(
            width: 100,
            child: TextField(
              controller: entry.capacity,
              keyboardType: TextInputType.number,
              decoration: inputDecoration.copyWith(hintText: '4'),
            ),
          ),
        ),
        DataCell(
          isExisting
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete Table',
                  onPressed: () => _deleteExisting(index),
                )
              : IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  tooltip: 'Remove Row',
                  onPressed: _newEntries.length > 1 ? () => _removeNewEntryRow(index) : null,
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(posTablesProvider);

    // Initialize existing entries once the data is loaded
    if (!_dataLoaded && tablesAsync.hasValue) {
      final tables = tablesAsync.value!;
      for (var t in tables) {
        _existingEntries.add(_TableEntry(
          initialTableId: t['table_id'],
          initialCapacity: t['capacity'].toString(),
          isExisting: true,
        ));
      }
      _dataLoaded = true;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_restaurant_outlined, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 16),
                  Text(
                    'Manage Tables',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: tablesAsync.when(
                data: (_) {
                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                                dataRowMinHeight: 64,
                                dataRowMaxHeight: 64,
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text('Table ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                                  DataColumn(label: Text('Capacity', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                                ],
                                rows: [
                                  for (int i = 0; i < _existingEntries.length; i++)
                                    _buildRow(_existingEntries[i], true, i),
                                  for (int i = 0; i < _newEntries.length; i++)
                                    _buildRow(_newEntries[i], false, i),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _addNewEntryRow,
                                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                                label: const Text('Add Another Row', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: Text("Error loading tables: $e", style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
