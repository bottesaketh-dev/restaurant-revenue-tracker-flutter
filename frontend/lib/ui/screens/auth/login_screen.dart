import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth_provider.dart';
import '../../../core/restaurant_provider.dart';
import '../../../core/branch_provider.dart';
import '../../../core/pos_provider.dart';
import '../../../core/home_provider.dart';
import '../../../core/menu_provider.dart';
import '../../../core/groceries_provider.dart';
import '../../../core/expenses_provider.dart';
import '../../../core/staff_provider.dart';
import '../../../core/kitchen_provider.dart';
import '../../../core/users_provider.dart';
import '../../../core/reports_provider.dart';
import '../../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both username and password.')),
      );
      return;
    }

    await ref.read(authStateProvider.notifier).login(username, password);
    
    if (!mounted) return;
    
    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated) {
      // Synchronize multi-tenant and branch state to the authenticated session
      ref.read(selectedRestaurantIdProvider.notifier).state = authState.restaurantId;
      ref.read(selectedBranchProvider.notifier).state = authState.isAdmin ? null : authState.branchId;
      ref.read(selectedTableProvider.notifier).state = null;
      ref.read(posCartProvider.notifier).clearCart();

      // Invalidate providers to clear out any stale cache from previous sessions
      ref.invalidate(branchListProvider);
      ref.invalidate(restaurantListProvider);
      ref.invalidate(currentRestaurantProvider);
      ref.invalidate(homeProvider);
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
      ref.invalidate(usersProvider);
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

      context.go(authState.landingRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'IOR 360',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppTheme.primary,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enterprise Restaurant Management Platform',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (authState.error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          authState.error!,
                          style: const TextStyle(color: AppTheme.error),
                        ),
                      ),
                    TextField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _login,
                        child: authState.isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
