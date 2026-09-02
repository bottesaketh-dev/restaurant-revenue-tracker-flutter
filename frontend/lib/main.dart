import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'ui/layouts/sidebar_layout.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/pos/pos_billing_screen.dart';
import 'ui/screens/menu/menu_screen.dart';
import 'ui/screens/staff/staff_screen.dart';
import 'ui/screens/groceries/groceries_screen.dart';
import 'ui/screens/expenses/expenses_screen.dart';
import 'ui/screens/reports/reports_screen.dart';
import 'ui/screens/ai/ai_command_center.dart';
import 'ui/screens/kitchen/kitchen_screen.dart';
import 'ui/screens/users/users_screen.dart';
import 'core/auth_provider.dart';
import 'core/nav_tabs.dart';

void main() {
  runApp(const ProviderScope(child: FlavorsLedgerApp()));
}

class FlavorsLedgerApp extends ConsumerWidget {
  const FlavorsLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    final router = GoRouter(
      initialLocation: authState.isAuthenticated ? authState.landingRoute : '/login',
      redirect: (context, state) {
        final isLoggedIn = authState.isAuthenticated;
        final path = state.uri.toString();
        final isGoingToLogin = path == '/login';

        if (!isLoggedIn && !isGoingToLogin) return '/login';
        if (isLoggedIn && isGoingToLogin) return authState.landingRoute;

        if (isLoggedIn && !isGoingToLogin) {
          final tab = kNavTabs.where((t) => t.route == path).cast<NavTab?>().firstWhere((t) => t != null, orElse: () => null);
          if (tab != null && !authState.canAccessTab(tab.key)) {
            return authState.landingRoute;
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return SidebarLayout(child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/users',
              builder: (context, state) => const UsersScreen(),
            ),
            GoRoute(
              path: '/pos',
              builder: (context, state) => const PosBillingScreen(),
            ),
            GoRoute(
              path: '/menu',
              builder: (context, state) => const MenuScreen(),
            ),
            GoRoute(
              path: '/staff',
              builder: (context, state) => const StaffScreen(),
            ),
            GoRoute(
              path: '/groceries',
              builder: (context, state) => const GroceriesScreen(),
            ),
            GoRoute(
              path: '/expenses',
              builder: (context, state) => const ExpensesScreen(),
            ),
            GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsScreen(),
            ),
            GoRoute(
              path: '/ai',
              builder: (context, state) => const AiCommandCenterScreen(),
            ),
            GoRoute(
              path: '/kitchen',
              builder: (context, state) => const KitchenScreen(),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Flavors Ledger',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

