import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/reports_provider.dart';

class InventorySupplySection extends ConsumerWidget {
  const InventorySupplySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(inventorySupplyProvider).when(
          skipLoadingOnRefresh: false,
          data: (data) {
            final stock = List<Map<String, dynamic>>.from(data['stock']);
            final vendors = List<Map<String, dynamic>>.from(data['vendors']);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Inventory & Supply Chain',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
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
                              const Text('Stock vs Threshold',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              ...stock.map((item) {
                                final current =
                                    (item['current'] ?? 0).toDouble();
                                final threshold =
                                    (item['threshold'] ?? 10).toDouble();
                                final isLow = current <= threshold;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(item['item'],
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: isLow
                                                  ? Colors.red
                                                  : Colors.black87,
                                              fontWeight: isLow
                                                  ? FontWeight.bold
                                                  : FontWeight.normal)),
                                      Text(
                                          '${current.toStringAsFixed(1)} / ${threshold.toStringAsFixed(0)} ${item['unit']}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isLow
                                                  ? Colors.red
                                                  : Colors.black87)),
                                    ],
                                  ),
                                );
                              }),
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
                        shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Spend by Vendor',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
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
                                            if (value.toInt() >= 0 &&
                                                value.toInt() <
                                                    vendors.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: Text(
                                                    vendors[value.toInt()]
                                                        ['vendor'],
                                                    style: const TextStyle(
                                                        fontSize: 10),
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              );
                                            }
                                            return const SizedBox();
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: vendors.asMap().entries.map((e) {
                                      return BarChartGroupData(
                                        x: e.key,
                                        barRods: [
                                          BarChartRodData(
                                              toY: (e.value['spend'] ?? 0)
                                                  .toDouble(),
                                              color: Colors.blueAccent,
                                              width: 16,
                                              borderRadius:
                                                  BorderRadius.circular(4)),
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
