import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/reports_provider.dart';
import '../../../../core/currency_formatter.dart';
import '../../../../theme/app_theme.dart';
import 'custom_donut_chart.dart';

class SalesEngineeringSection extends ConsumerWidget {
  const SalesEngineeringSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(salesEngineeringProvider).when(
      skipLoadingOnRefresh: false,
      data: (data) {
        final topItems = List<Map<String, dynamic>>.from(data['top_items']);
        final bottomItems = List<Map<String, dynamic>>.from(data['bottom_items']);
        final vegSplit = data['veg_split'];
        final heatmapData = List<Map<String, dynamic>>.from(data['heatmap']);
        final discounts = data['discounts'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales & Menu Engineering', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                          const Text('Veg vs Non-Veg Revenue', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: CustomDonutChart(
                              centerSpaceRadius: 40,
                              radius: 30,
                              touchedRadius: 40,
                              data: [
                                CustomDonutChartData(color: Colors.green, value: (vegSplit['veg'] ?? 0).toDouble(), label: 'Veg'),
                                CustomDonutChartData(color: Colors.red, value: (vegSplit['non_veg'] ?? 0).toDouble(), label: 'Non-Veg'),
                              ],
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
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Discount Impact', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Total Discounts'),
                            trailing: Text(CurrencyFormatter.format(discounts['discount_amount'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Total Subtotal'),
                            trailing: Text(CurrencyFormatter.format(discounts['subtotal'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Discount %'),
                            trailing: Text('%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Top 10 Items', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(height: 16),
                          ...topItems.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['name'], style: const TextStyle(fontSize: 14)),
                                    Text('', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bottom 10 Items', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          const SizedBox(height: 16),
                          ...bottomItems.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['name'], style: const TextStyle(fontSize: 14)),
                                    Text('', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
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
