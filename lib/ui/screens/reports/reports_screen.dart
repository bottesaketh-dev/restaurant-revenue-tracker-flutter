import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/reports_provider.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Financial Reports',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text('Export PDF'),
              )
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: ref.watch(profitLossProvider).when(
                          data: (data) {
                            final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
                            return [
                              Text('Profit & Loss Statement (${DateFormat('MMMM yyyy').format(DateTime.now())})', style: Theme.of(context).textTheme.headlineMedium),
                              const Divider(height: 48),
                              _buildReportRow(context, 'Gross Sales (A)', currencyFormatter.format(data['revenue']), isHeader: true),
                              const SizedBox(height: 24),
                              _buildReportRow(context, 'Cost of Goods Sold (B)', currencyFormatter.format(-data['cogs']), isDeduction: true),
                              const Divider(height: 32),
                              _buildReportRow(context, 'Gross Operating Profit (C = A - B)', currencyFormatter.format(data['gross_profit']), isHeader: true),
                              const SizedBox(height: 24),
                              _buildReportRow(context, 'Operating Expenses (D)', currencyFormatter.format(-data['opex_total']), isDeduction: true),
                              const Divider(height: 32),
                              _buildReportRow(context, 'Net Profit (E = C - D)', currencyFormatter.format(data['net_profit']), isHeader: true, color: AppTheme.secondary),
                            ];
                          },
                          loading: () => [const Center(child: CircularProgressIndicator())],
                          error: (e, st) => [Center(child: Text('Error: $e'))],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildMetricCard(context, 'Total Bills Generated', '142', Icons.receipt),
                      const SizedBox(height: 24),
                      _buildMetricCard(context, 'Average Order Value', '₹ 876', Icons.analytics),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildReportRow(BuildContext context, String label, String value, {bool isHeader = false, bool isDeduction = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            color: isDeduction ? AppTheme.error : null,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            color: color ?? (isDeduction ? AppTheme.error : AppTheme.onBackground),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelSmall),
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
