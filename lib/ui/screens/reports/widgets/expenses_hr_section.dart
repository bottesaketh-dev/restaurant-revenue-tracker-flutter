import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/reports_provider.dart';
import '../../../../core/currency_formatter.dart';
import 'custom_donut_chart.dart';

class ExpensesHrSection extends ConsumerWidget {
  const ExpensesHrSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(expensesHrProvider).when(
          skipLoadingOnRefresh: false,
          data: (data) {
            final expenses = List<Map<String, dynamic>>.from(data['expenses']);
            final payroll = List<Map<String, dynamic>>.from(data['payroll']);
            final employees =
                List<Map<String, dynamic>>.from(data['employees']);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Expenses & HR',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Expenses Breakdown',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: CustomDonutChart(
                                  centerSpaceRadius: 40,
                                  radius: 30,
                                  touchedRadius: 40,
                                  data: expenses.asMap().entries.map((e) {
                                    return CustomDonutChartData(
                                      color: Colors.primaries[e.key % Colors.primaries.length],
                                      value: (e.value['amount'] ?? 0).toDouble(),
                                      label: e.value['category'],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payroll by Position',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              ...payroll.map((p) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(p['position']),
                                    trailing: Text(
                                        CurrencyFormatter.format(
                                            p['amount'] ?? 0),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Employee Status',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              ...employees.map((e) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(e['name'],
                                        style: const TextStyle(fontSize: 14)),
                                    subtitle: Text(e['position'],
                                        style: const TextStyle(fontSize: 12)),
                                    trailing: Icon(Icons.circle,
                                        size: 12,
                                        color: e['active']
                                            ? Colors.green
                                            : Colors.red),
                                  )),
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
