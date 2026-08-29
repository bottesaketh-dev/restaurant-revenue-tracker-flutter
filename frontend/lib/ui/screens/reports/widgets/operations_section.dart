import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/reports_provider.dart';
import '../../../../core/currency_formatter.dart';
import '../../../../theme/app_theme.dart';

class OperationsSection extends ConsumerWidget {
  const OperationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(operationsProvider).when(
      skipLoadingOnRefresh: false,
      data: (data) {
        final employeeRevenue = List<Map<String, dynamic>>.from(data['employee_revenue']);
        final totalTips = (data['total_tips'] ?? 0).toDouble();
        final tableUtil = List<Map<String, dynamic>>.from(data['table_utilization']);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Operations & Staff Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Revenue per Employee', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ...employeeRevenue.map((r) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.person),
                                title: Text(r['username']),
                                trailing: Text(CurrencyFormatter.format(r['revenue'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
                              )),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Total Tips Collected', style: TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Text(CurrencyFormatter.format(totalTips), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Table Utilization (Orders per Table)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 250,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() >= 0 && value.toInt() < tableUtil.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text('T${tableUtil[value.toInt()]['table']} (Cap:${tableUtil[value.toInt()]['capacity']})', style: const TextStyle(fontSize: 10)),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: tableUtil.asMap().entries.map((e) {
                                  return BarChartGroupData(
                                    x: e.key,
                                    barRods: [
                                      BarChartRodData(toY: (e.value['orders'] ?? 0).toDouble(), color: AppTheme.primary, width: 16, borderRadius: BorderRadius.circular(4)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
