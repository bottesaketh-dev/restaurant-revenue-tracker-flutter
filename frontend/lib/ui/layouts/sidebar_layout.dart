import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../core/branch_provider.dart';
import '../../core/restaurant_provider.dart';
import '../../core/nav_tabs.dart';
import '../../core/home_provider.dart';
import '../../core/users_provider.dart';
import '../../core/pos_provider.dart';
import '../../core/menu_provider.dart';
import '../../core/kitchen_provider.dart';
import '../../core/expenses_provider.dart';
import '../../core/groceries_provider.dart';
import '../../core/staff_provider.dart';
import '../../core/reports_provider.dart';
import '../../core/currency_formatter.dart';
import '../../core/support_provider.dart';

// Providers for Sidebar State
final isSidebarCollapsedProvider = StateProvider<bool>((ref) => false);
final sidebarWidthProvider = StateProvider<double>((ref) => 260.0);

class SidebarLayout extends ConsumerWidget {
  final Widget child;

  const SidebarLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = GoRouterState.of(context).uri;
    final currentPath = uri.path;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    
    final isCollapsed = ref.watch(isSidebarCollapsedProvider);
    final width = ref.watch(sidebarWidthProvider);
    final authState = ref.watch(authStateProvider);
    final activeTenant = ref.watch(activeTenantInfoProvider);
    final visibleTabs = kNavTabs.where((tab) => authState.canAccessTab(tab.key)).toList();
    
    final currentWidth = isCollapsed ? 80.0 : width;

    Widget sidebarContent = Container(
      width: currentWidth,
      color: AppTheme.primary,
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Toggle & Title Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 16.0),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!isCollapsed)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IOR 360',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.secondaryContainer,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeTenant.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    isCollapsed ? Icons.menu : Icons.menu_open,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    ref.read(isSidebarCollapsedProvider.notifier).state = !isCollapsed;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final tab in visibleTabs)
                  _SidebarItem(
                    icon: tab.icon,
                    label: tab.label,
                    isSelected: currentPath == tab.route,
                    isCollapsed: isCollapsed,
                    onTap: () => context.go(tab.route),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          _SidebarItem(
            icon: Icons.settings,
            label: 'Settings',
            isSelected: currentPath == '/settings',
            isCollapsed: isCollapsed,
            onTap: () => context.go('/settings'),
          ),
          _SidebarItem(
            icon: Icons.help_outline,
            label: 'Support',
            isSelected: currentPath == '/support',
            isCollapsed: isCollapsed,
            onTap: () => context.go('/support'),
          ),
          _SidebarItem(
            icon: Icons.logout,
            label: 'Logout',
            isSelected: false,
            isCollapsed: isCollapsed,
            onTap: () {
              ref.read(selectedRestaurantIdProvider.notifier).state = null;
              ref.read(selectedBranchProvider.notifier).state = null;
              ref.read(selectedTableProvider.notifier).state = null;
              ref.read(posCartProvider.notifier).clearCart();
              ref.invalidate(branchListProvider);
              ref.invalidate(restaurantListProvider);
              ref.invalidate(homeProvider);
              ref.invalidate(supportTicketsProvider);
              ref.read(authStateProvider.notifier).logout();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    Widget sidebarWithDragHandle = Row(
      children: [
        sidebarContent,
        if (isDesktop && !isCollapsed)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) {
              final newWidth = width + details.delta.dx;
              if (newWidth < 150) {
                ref.read(isSidebarCollapsedProvider.notifier).state = true;
                ref.read(sidebarWidthProvider.notifier).state = 260.0;
              } else if (newWidth >= 200 && newWidth <= 400) {
                ref.read(sidebarWidthProvider.notifier).state = newWidth;
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(
                width: 4,
                color: Colors.black12,
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop) sidebarWithDragHandle,
          Expanded(
            child: Column(
              children: [
                if (isDesktop) _DesktopAppBar(),
                Expanded(
                  child: Container(
                    color: AppTheme.background,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: isDesktop ? null : Drawer(child: sidebarContent),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppTheme.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IOR 360',
                    style: TextStyle(color: AppTheme.secondaryContainer, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    activeTenant.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'My Profile (Settings)',
                  icon: const CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primaryContainer,
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  onPressed: () => context.go('/settings?tab=profile'),
                ),
                const SizedBox(width: 8),
              ],
            ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.secondaryContainer : Colors.white70;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 24, vertical: 16),
        alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
        decoration: BoxDecoration(
          border: isSelected && !isCollapsed
              ? const Border(
                  left: BorderSide(color: AppTheme.secondaryContainer, width: 4),
                )
              : null,
          color: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: isCollapsed
            ? Tooltip(
                message: label,
                child: Icon(icon, color: color, size: 24),
              )
            : Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DesktopAppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final isSuperAdmin = authState.isSuperAdmin;
    final isAdmin = authState.isAdmin;
    final userBranchId = user?['branch_id'];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Super Admin Restaurant Selector
              if (isSuperAdmin) ...[
                Consumer(
                  builder: (context, ref, _) {
                    final restaurantsAsync = ref.watch(restaurantListProvider);
                    final selectedRestaurant = ref.watch(selectedRestaurantIdProvider);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryContainer.withValues(alpha: 0.3)),
                      ),
                      child: restaurantsAsync.when(
                        data: (rests) {
                          final safeSelectedRestaurant = (selectedRestaurant != null && rests.any((r) => r['restaurant_id'] == selectedRestaurant))
                              ? selectedRestaurant
                              : null;

                          if (selectedRestaurant != null && safeSelectedRestaurant == null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ref.read(selectedRestaurantIdProvider.notifier).state = null;
                            });
                          }

                          final currentName = safeSelectedRestaurant == null
                              ? 'All Tenants (Global)'
                              : rests.firstWhere((r) => r['restaurant_id'] == safeSelectedRestaurant,
                                  orElse: () => {'name': 'Restaurant #$safeSelectedRestaurant'})['name'];

                          return DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: safeSelectedRestaurant,
                              hint: Row(
                                children: [
                                  const Icon(Icons.business, size: 16, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Text(currentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              isDense: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Row(
                                    children: [
                                      Icon(Icons.public, size: 16, color: Colors.grey),
                                      SizedBox(width: 8),
                                      Text('All Tenants (Global)', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                ...rests.map((r) => DropdownMenuItem<int?>(
                                  value: r['restaurant_id'] as int?,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.storefront, size: 16, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Text('${r['name']} (${r['currency_symbol'] ?? '₹'})', style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                )).toList(),
                              ],
                              onChanged: (val) {
                                ref.read(selectedRestaurantIdProvider.notifier).state = val;
                                // Reset selected branch and table when switching restaurant
                                ref.read(selectedBranchProvider.notifier).state = null;
                                ref.read(selectedTableProvider.notifier).state = null;
                                ref.read(posCartProvider.notifier).clearCart();
                                ref.invalidate(branchListProvider);
                                ref.invalidate(branchManagementProvider);
                                ref.invalidate(restaurantManagementProvider);
                                ref.invalidate(currentRestaurantProvider);
                                ref.invalidate(homeProvider);
                                ref.invalidate(usersProvider);
                                ref.invalidate(posTablesProvider);
                                ref.invalidate(menuNotifierProvider);
                                ref.invalidate(menuProvider);
                                ref.invalidate(categoriesProvider);
                                ref.invalidate(inventoryStockProvider);
                                ref.invalidate(expensesProvider);
                                ref.invalidate(expenseCategoriesProvider);
                                ref.invalidate(groceriesProvider);
                                ref.invalidate(groceryCategoriesProvider);
                                ref.invalidate(groceryItemsProvider);
                                ref.invalidate(staffProvider);
                                ref.invalidate(salaryPaymentsProvider);
                                ref.invalidate(profitLossProvider);
                                ref.invalidate(reportsOverviewProvider);
                                ref.invalidate(salesTrendsProvider);
                                ref.invalidate(metricsSummaryProvider);
                                ref.invalidate(categoryRevenueProvider);
                                ref.invalidate(topItemsProvider);
                                ref.invalidate(expenseBreakdownProvider);
                                ref.invalidate(branchComparisonProvider);
                                ref.invalidate(executiveSummaryProvider);
                                ref.invalidate(salesEngineeringProvider);
                                ref.invalidate(inventorySupplyProvider);
                                ref.invalidate(expensesHrProvider);
                                ref.invalidate(operationsProvider);
                                ref.invalidate(supportTicketsProvider);

                                if (val != null) {
                                  final selectedRest = rests.firstWhere(
                                    (r) => r['restaurant_id'] == val,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (selectedRest.isNotEmpty && selectedRest['currency_symbol'] != null) {
                                    CurrencyFormatter.setCurrency(
                                      symbol: selectedRest['currency_symbol'] ?? '₹',
                                      code: selectedRest['currency_code'] ?? 'INR',
                                    );
                                  }
                                } else {
                                  CurrencyFormatter.setCurrency(
                                    symbol: authState.currencySymbol,
                                    code: authState.currencyCode,
                                  );
                                }
                              },
                            ),
                          );
                        },
                        loading: () => const SizedBox(width: 80, child: LinearProgressIndicator()),
                        error: (_, __) => const Text('Error loading tenants', style: TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
              ],

              // Branch Selector
              Consumer(
                builder: (context, ref, child) {
                  final branchesAsync = ref.watch(branchListProvider);
                  final selectedBranch = ref.watch(selectedBranchProvider);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDim.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: branchesAsync.when(
                      data: (branches) {
                        // Non-admin: Branch manager, cashier, staff are pinned to userBranchId
                        if (!isAdmin) {
                          final parsedUserBranch = userBranchId != null ? int.tryParse(userBranchId.toString()) : null;
                          if (selectedBranch != parsedUserBranch) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ref.read(selectedBranchProvider.notifier).state = parsedUserBranch;
                            });
                          }

                          final currentBranch = branches.firstWhere(
                            (b) => b['branch_id']?.toString() == userBranchId?.toString(),
                            orElse: () => <String, dynamic>{'name': userBranchId != null ? 'Branch #$userBranchId' : 'Assigned Branch'},
                          );

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                currentBranch['name'] ?? 'Branch #$userBranchId',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        }

                        // Admin: Allowed to select "All Branches" (null) or switch between branches
                        final safeSelectedBranch = (selectedBranch != null && branches.any((b) => b['branch_id']?.toString() == selectedBranch.toString()))
                            ? int.tryParse(selectedBranch.toString())
                            : null;

                        if (selectedBranch != null && safeSelectedBranch == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ref.read(selectedBranchProvider.notifier).state = null;
                          });
                        }

                        final displayBranchName = safeSelectedBranch == null 
                            ? 'All Branches'
                            : branches.firstWhere(
                                (b) => b['branch_id']?.toString() == safeSelectedBranch.toString(), 
                                orElse: () => {'name': 'Branch #$safeSelectedBranch'}
                              )['name'];

                        return DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: safeSelectedBranch,
                            hint: Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(displayBranchName, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                            icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade700),
                            isDense: true,
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade700),
                                    const SizedBox(width: 8),
                                    Text('All Branches', style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                              ...branches.map((b) => DropdownMenuItem<int?>(
                                value: int.tryParse(b['branch_id']?.toString() ?? ''),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade700),
                                    const SizedBox(width: 8),
                                    Text(b['name'], style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                              )),
                            ],
                            onChanged: (value) {
                              ref.read(selectedBranchProvider.notifier).state = value;
                            },
                          ),
                        );
                      },
                      loading: () => const SizedBox(width: 100, child: LinearProgressIndicator()),
                      error: (_, __) => const Text('Error loading branches'),
                    ),
                  );
                }
              ),
            ],
          ),

          // User & Tenant Badges
          Row(
            children: [
              // Currency Indicator Pill
              Consumer(
                builder: (context, ref, _) {
                  final activeTenant = ref.watch(activeTenantInfoProvider);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      '${activeTenant.currencySymbol} ${activeTenant.currencyCode}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),

              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  authState.role ?? 'USER',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 12),

              Tooltip(
                message: 'My Profile & Account (Settings)',
                child: InkWell(
                  onTap: () => context.go('/settings?tab=profile'),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: AppTheme.primaryContainer,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
