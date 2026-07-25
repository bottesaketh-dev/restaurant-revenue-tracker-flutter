import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dashboard_provider.dart';
import '../../../theme/app_theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Owner Dashboard',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Today\'s Financial Overview',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          dashboardAsync.when(
            data: (data) => Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'CASH INFLOW',
                    value: '₹${data['inflow'].toStringAsFixed(0)}',
                    icon: Icons.arrow_upward,
                    color: AppTheme.primary,
                    percentage: '${data['inflow_pct'] >= 0 ? '+' : ''}${data['inflow_pct']}%',
                    percentageColor: data['inflow_pct'] >= 0 ? AppTheme.primaryContainer : AppTheme.error,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _KpiCard(
                    title: 'CASH OUTFLOW',
                    value: '₹${data['outflow'].toStringAsFixed(0)}',
                    icon: Icons.arrow_downward,
                    color: AppTheme.error,
                    percentage: '${data['outflow_pct'] >= 0 ? '+' : ''}${data['outflow_pct']}%',
                    percentageColor: data['outflow_pct'] >= 0 ? AppTheme.error : AppTheme.primaryContainer,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _KpiCard(
                    title: 'NET CASHFLOW',
                    value: '₹${data['net'].toStringAsFixed(0)}',
                    icon: Icons.account_balance,
                    color: AppTheme.secondary,
                    percentage: '${data['net_pct'] >= 0 ? '+' : ''}${data['net_pct']}%',
                    percentageColor: data['net_pct'] >= 0 ? AppTheme.primary : AppTheme.error,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: dashboardAsync.when(
              data: (data) {
                final recentBills = List<Map<String, dynamic>>.from(data['recent_bills']);
                final recentExpenses = List<Map<String, dynamic>>.from(data['recent_expenses']);
                final recentGroceries = List<Map<String, dynamic>>.from(data['recent_groceries']);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTableCard(
                        context,
                        'Recent Bills',
                        ['Date', 'Time', 'Table', 'Bill No', 'Amount', 'Status'],
                        recentBills.map((b) => <String>[
                          b['date']?.toString() ?? '',
                          b['time']?.toString() ?? '',
                          b['table_id']?.toString() ?? '',
                          b['bill_id']?.toString() ?? '',
                          '₹${(b['amount'] ?? 0).toStringAsFixed(2)}',
                          b['status']?.toString() ?? '',
                        ]).toList(),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildTableCard(
                              context,
                              'Recent Expenses',
                              ['Date', 'Desc', 'Amount', 'Mode'],
                              recentExpenses.map((e) => <String>[
                                e['date']?.toString() ?? '',
                                e['description']?.toString() ?? '',
                                '₹${(e['amount'] ?? 0).toStringAsFixed(2)}',
                                e['payment_mode']?.toString() ?? '',
                              ]).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: _buildTableCard(
                              context,
                              'Recent Groceries',
                              ['Date', 'Item ID', 'Qty', 'Amount'],
                              recentGroceries.map((g) => <String>[
                                g['date']?.toString() ?? '',
                                g['item_id']?.toString() ?? '',
                                (g['quantity'] ?? 0).toString(),
                                '₹${(g['amount'] ?? 0).toStringAsFixed(2)}',
                              ]).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(BuildContext context, String title, List<String> columns, List<List<String>> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2)),
              ),
              child: Row(
                children: columns.map((c) => Expanded(
                  child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: row.map((cell) => Expanded(
                        child: Text(cell, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String percentage;
  final Color percentageColor;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.percentage,
    required this.percentageColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.trending_up, color: percentageColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  percentage,
                  style: TextStyle(color: percentageColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  'vs yesterday',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
