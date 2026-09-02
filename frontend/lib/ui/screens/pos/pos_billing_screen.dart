import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pos_provider.dart';
import '../../../core/menu_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../core/responsive.dart';
import 'widgets/checkout_dialog.dart';
import 'widgets/manage_tables_dialog.dart';
import '../../../core/currency_formatter.dart';
import '../../../core/app_notifier.dart';

class PosBillingScreen extends ConsumerStatefulWidget {
  const PosBillingScreen({super.key});

  @override
  ConsumerState<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends ConsumerState<PosBillingScreen> {

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(posOrderModeProvider);
    final selectedTable = ref.watch(selectedTableProvider);
    final cartItems = ref.watch(posCartProvider);

    final showMenu = mode == OrderMode.takeaway || (mode == OrderMode.dineIn && selectedTable != null);

    final isMobile = Responsive.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(mode, isMobile),
                const SizedBox(height: 24),
                Expanded(
                  child: showMenu ? const _MenuOrderingView() : const _TablesGridView(),
                ),
                if (mode != OrderMode.dineIn || selectedTable != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 350, // Fixed height for cart on mobile to avoid overflow
                    child: _CartPanel(
                      mode: mode, 
                      selectedTable: selectedTable, 
                      cartItems: cartItems
                    ),
                  ),
                ]
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Main Content
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(mode, isMobile),
                      const SizedBox(height: 24),
                      Expanded(
                        child: showMenu ? const _MenuOrderingView() : const _TablesGridView(),
                      ),
                    ],
                  ),
                ),
                
                // Right Side: Live Cart Panel
                if (mode == OrderMode.dineIn && selectedTable == null)
                  const SizedBox.shrink()
                else ...[
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 1,
                    child: _CartPanel(
                      mode: mode, 
                      selectedTable: selectedTable, 
                      cartItems: cartItems
                    ),
                  ),
                ]
              ],
            ),
    );
  }

  Widget _buildHeader(OrderMode currentMode, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleBtn('Dine In', OrderMode.dineIn, currentMode),
                _buildToggleBtn('Takeaway', OrderMode.takeaway, currentMode),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(posTablesProvider);
                  ref.invalidate(menuProvider);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const ManageTablesDialog(),
                    );
                  },
                  icon: const Icon(Icons.table_restaurant),
                  label: const Text('Manage Tables'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleBtn('Dine In', OrderMode.dineIn, currentMode),
              _buildToggleBtn('Takeaway', OrderMode.takeaway, currentMode),
            ],
          ),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(posTablesProvider);
                ref.invalidate(menuProvider);
              },
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ManageTablesDialog(),
                );
              },
              icon: const Icon(Icons.table_restaurant),
              label: const Text('Manage Tables'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleBtn(String label, OrderMode mode, OrderMode currentMode) {
    final isSelected = mode == currentMode;
    return GestureDetector(
      onTap: () {
        ref.read(posOrderModeProvider.notifier).state = mode;
        ref.read(posCartProvider.notifier).clearCart(); // clear cart on mode switch
        if (mode == OrderMode.takeaway) {
          ref.read(selectedTableProvider.notifier).state = null;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _TablesGridView extends ConsumerWidget {
  const _TablesGridView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(posTablesProvider).when(skipLoadingOnRefresh: false, 
      data: (tables) {
        if (tables.isEmpty) {
          return const Center(child: Text("No tables found."));
        }
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.isMobile(context) ? 2 : 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            final isOccupied = table['status'] == 'occupied';

            return InkWell(
              onTap: () {
                ref.read(selectedTableProvider.notifier).state = table['table_id'] as String;
                ref.read(posCartProvider.notifier).clearCart(); 
                ref.read(posCartProvider.notifier).loadActiveOrder(table['table_id'] as String);
              },
              child: Card(
                color: AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE9ECEF), width: 1),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOccupied ? AppTheme.error : Colors.green,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            table['table_id'] as String,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${table['capacity']} Seats',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _MenuOrderingView extends ConsumerWidget {
  const _MenuOrderingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(posOrderModeProvider);
    final selectedCategory = ref.watch(posSelectedCategoryProvider);
    final searchQuery = ref.watch(posSearchQueryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mode == OrderMode.dineIn)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: TextButton.icon(
              onPressed: () {
                ref.read(selectedTableProvider.notifier).state = null;
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Tables'),
            ),
          ),
        
        // Search Bar
        TextField(
          decoration: InputDecoration(
            hintText: 'Search dishes...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) {
            ref.read(posSearchQueryProvider.notifier).state = val;
          },
        ),
        const SizedBox(height: 16),

        // Categories
        ref.watch(menuProvider).when(skipLoadingOnRefresh: false, 
          data: (items) {
            final activeItems = items.where((i) => i['is_available'] == true || i['is_available'] == 1).toList();
            final categories = activeItems.map((i) => i['category'] as String).toSet().toList();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('All', selectedCategory == null, () {
                    ref.read(posSelectedCategoryProvider.notifier).state = null;
                  }),
                  ...categories.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: _buildCategoryChip(c, selectedCategory == c, () {
                          ref.read(posSelectedCategoryProvider.notifier).state = c;
                        }),
                      )),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        
        const SizedBox(height: 16),
        
        // Menu Grid
        Expanded(
          child: ref.watch(menuProvider).when(skipLoadingOnRefresh: false, 
            data: (items) {
              final filtered = items.where((item) {
                final isActive = item['is_available'] == true || item['is_available'] == 1;
                final matchCat = selectedCategory == null || item['category'] == selectedCategory;
                final matchSearch = item['name'].toString().toLowerCase().contains(searchQuery.toLowerCase());
                return isActive && matchCat && matchSearch;
              }).toList();

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Responsive.isMobile(context) ? 2 : 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: Responsive.isMobile(context) ? 0.9 : 1.1,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                CurrencyFormatter.format(item['price']),
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                                onPressed: () {
                                  ref.read(posCartProvider.notifier).addItem(item);
                                },
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceDim,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  final OrderMode mode;
  final String? selectedTable;
  final List<CartItemModel> cartItems;

  const _CartPanel({
    required this.mode,
    required this.selectedTable,
    required this.cartItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double subtotal = 0;
    for (var item in cartItems) {
      subtotal += double.parse(item.menuItem['price'].toString()) * item.quantity;
    }
    double taxes = subtotal * 0.05;

    String title = 'Cart';
    if (mode == OrderMode.dineIn) {
      title = selectedTable != null ? 'Cart - Table $selectedTable' : 'Select a table';
    } else {
      title = 'Takeaway Cart';
    }

    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const Divider(height: 32),
            Expanded(
              child: cartItems.isEmpty
                  ? Center(
                      child: Text(
                        'Cart is empty',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return _CartItemWidget(index: index, item: item);
                      },
                    ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: Theme.of(context).textTheme.bodyLarge),
                Text(CurrencyFormatter.format(subtotal), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Taxes (5%)', style: Theme.of(context).textTheme.bodyLarge),
                Text(CurrencyFormatter.format(taxes), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: (selectedTable != null || mode == OrderMode.takeaway)
                          ? () async {
                              final tableId = mode == OrderMode.dineIn ? selectedTable! : "TAKEAWAY";
                              try {
                                await ref.read(posCartProvider.notifier).printKot(tableId, mode);
                                if (context.mounted) AppNotifier.showSuccess(context, 'KOT Sent & Synced to Kitchen!');
                              } catch(e) {
                                if (context.mounted) AppNotifier.showError(context, 'Error: $e');
                              }
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: (selectedTable != null || mode == OrderMode.takeaway) ? AppTheme.primary : Colors.grey),
                        foregroundColor: AppTheme.primary
                      ),
                      child: const Text('KOT', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: cartItems.any((item) => item.isKotPrinted)
                          ? () async {
                              final tableId = mode == OrderMode.dineIn ? selectedTable! : "TAKEAWAY";
                              
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => CheckoutDialog(
                                  tableId: tableId,
                                  items: cartItems.where((item) => item.isKotPrinted).toList(),
                                )
                              );
                              
                              if (result == true) {
                                // Deselect table if dine in
                                if (mode == OrderMode.dineIn) {
                                  ref.read(selectedTableProvider.notifier).state = null;
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Checkout', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemWidget extends ConsumerWidget {
  final int index;
  final CartItemModel item;

  const _CartItemWidget({required this.index, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(item.menuItem['name'], style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    if (item.isKotPrinted)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                      )
                  ],
                ),
                Text('${item.quantity} x ${CurrencyFormatter.format(item.menuItem['price'])}', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  ref.read(posCartProvider.notifier).updateQuantity(index, -1);
                }, 
                icon: const Icon(Icons.remove_circle_outline, size: 20)
              ),
              Text('${item.quantity}', style: Theme.of(context).textTheme.bodyLarge),
              IconButton(
                onPressed: () {
                  ref.read(posCartProvider.notifier).updateQuantity(index, 1);
                }, 
                icon: const Icon(Icons.add_circle_outline, size: 20)
              ),
            ],
          )
        ],
      ),
    );
  }
}

