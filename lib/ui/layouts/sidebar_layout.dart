import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/ai_chat_bubble.dart';
import '../../core/branch_provider.dart';

// Providers for Sidebar State
final isSidebarCollapsedProvider = StateProvider<bool>((ref) => false);
final sidebarWidthProvider = StateProvider<double>((ref) => 260.0);

class SidebarLayout extends ConsumerWidget {
  final Widget child;

  const SidebarLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.toString();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    
    final isCollapsed = ref.watch(isSidebarCollapsedProvider);
    final width = ref.watch(sidebarWidthProvider);
    
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
                    child: Text(
                      'Flavors Ledger',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.secondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
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
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Home',
                  isSelected: currentPath == '/home',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/home'),
                ),
                _SidebarItem(
                  icon: Icons.group_outlined,
                  label: 'Users',
                  isSelected: currentPath == '/users',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/users'),
                ),
                _SidebarItem(
                  icon: Icons.point_of_sale_outlined,
                  label: 'POS Billing',
                  isSelected: currentPath == '/pos',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/pos'),
                ),
                _SidebarItem(
                  icon: Icons.restaurant_menu,
                  label: 'Menu Catalog',
                  isSelected: currentPath == '/menu',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/menu'),
                ),
                _SidebarItem(
                  icon: Icons.people_outline,
                  label: 'Staff Directory',
                  isSelected: currentPath == '/staff',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/staff'),
                ),
                _SidebarItem(
                  icon: Icons.kitchen,
                  label: 'Groceries',
                  isSelected: currentPath == '/groceries',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/groceries'),
                ),
                _SidebarItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Kitchen & Recipes',
                  isSelected: currentPath == '/kitchen',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/kitchen'),
                ),
                _SidebarItem(
                  icon: Icons.payments,
                  label: 'General Expenses',
                  isSelected: currentPath == '/expenses',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/expenses'),
                ),
                _SidebarItem(
                  icon: Icons.analytics_outlined,
                  label: 'Reports',
                  isSelected: currentPath == '/reports',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/reports'),
                ),
                _SidebarItem(
                  icon: Icons.auto_awesome,
                  label: 'AI Command Center',
                  isSelected: currentPath == '/ai',
                  isCollapsed: isCollapsed,
                  onTap: () => context.go('/ai'),
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
            onTap: () {},
          ),
          _SidebarItem(
            icon: Icons.help_outline,
            label: 'Support',
            isSelected: currentPath == '/support',
            isCollapsed: isCollapsed,
            onTap: () {},
          ),
          _SidebarItem(
            icon: Icons.logout,
            label: 'Logout',
            isSelected: false,
            isCollapsed: isCollapsed,
            onTap: () {
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
      body: Stack(
        children: [
          Row(
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
          const AiChatBubble(),
        ],
      ),
      drawer: isDesktop ? null : Drawer(child: sidebarContent),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppTheme.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Flavors Ledger',
                style: TextStyle(color: AppTheme.secondaryContainer),
              ),
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
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Consumer(
            builder: (context, ref, child) {
              final branchesAsync = ref.watch(branchListProvider);
              final selectedBranch = ref.watch(selectedBranchProvider);
              final user = ref.watch(authStateProvider).user;
              final isAdmin = user?['role'] == 'ADMIN';
              final userBranchId = user?['branch_id'];
              
              final currentDisplayBranch = selectedBranch ?? (isAdmin ? null : userBranchId);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDim.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: branchesAsync.when(
                  data: (branches) {
                    final displayBranchName = currentDisplayBranch == null 
                        ? 'All Branches'
                        : branches.firstWhere((b) => b['branch_id']?.toString() == currentDisplayBranch.toString(), orElse: () => {'name': 'Unknown'})['name'];

                    return DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: currentDisplayBranch != null ? int.tryParse(currentDisplayBranch.toString()) : null,
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
                          if (isAdmin)
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
                          ...branches.where((b) => isAdmin || b['branch_id']?.toString() == userBranchId?.toString()).map((b) => DropdownMenuItem<int?>(
                            value: int.tryParse(b['branch_id']?.toString() ?? ''),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(b['name'], style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          )).toList(),
                        ],
                        onChanged: (value) {
                          if (value != null || isAdmin) {
                            ref.read(selectedBranchProvider.notifier).state = value;
                          }
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
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
                color: Colors.grey.shade700,
              ),
              IconButton(
                icon: const Icon(Icons.schedule),
                onPressed: () {},
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryContainer,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ],
          )
        ],
      ),
    );
  }
}
