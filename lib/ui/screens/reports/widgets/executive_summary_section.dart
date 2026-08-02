import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/reports_provider.dart';
import '../../../../core/currency_formatter.dart';
import '../../../../theme/app_theme.dart';
import 'custom_donut_chart.dart';

class ExecutiveSummarySection extends ConsumerStatefulWidget {
  const ExecutiveSummarySection({super.key});

  @override
  ConsumerState<ExecutiveSummarySection> createState() => _ExecutiveSummarySectionState();
}

class _ExecutiveSummarySectionState extends ConsumerState<ExecutiveSummarySection> {
  int touchedCategoryIndex = -1;

  Widget _buildGlassCard({required Widget child, double? height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ]
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(executiveSummaryProvider).when(
      skipLoadingOnRefresh: false,
      data: (data) {
        final kpis = data['kpis'];
        final paymentSplit = data['payment_split'];
        final branches = List<Map<String, dynamic>>.from(data['branches']);

        double maxBranchRevenue = 0;
        for (var b in branches) {
          final rev = (b['revenue'] ?? 0).toDouble();
          if (rev > maxBranchRevenue) maxBranchRevenue = rev;
        }
        if (maxBranchRevenue == 0) maxBranchRevenue = 10000;
        final maxY = maxBranchRevenue * 1.2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Executive Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _KpiCard(title: 'Revenue', value: CurrencyFormatter.format(kpis['revenue'] ?? 0), icon: Icons.monetization_on, color: AppTheme.primary)),
                Expanded(child: _KpiCard(title: 'Expenses', value: CurrencyFormatter.format(kpis['expenses'] ?? 0), icon: Icons.money_off, color: Colors.orange)),
                Expanded(child: _KpiCard(title: 'Net Profit', value: CurrencyFormatter.format(kpis['net_profit'] ?? 0), icon: Icons.account_balance_wallet, color: (kpis['net_profit'] ?? 0) >= 0 ? Colors.green : Colors.red)),
                Expanded(child: _KpiCard(title: 'Avg Ticket', value: CurrencyFormatter.format(kpis['avg_ticket'] ?? 0), icon: Icons.receipt, color: Colors.purple)),
              ],
            ),
            const SizedBox(height: 24),
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
                          const Text('Payment Mode Split', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: CustomDonutChart(
                              centerSpaceRadius: 40,
                              radius: 30,
                              touchedRadius: 40,
                              data: [
                                CustomDonutChartData(color: Colors.green, value: (paymentSplit['cash'] ?? 0).toDouble(), label: 'Cash'),
                                CustomDonutChartData(color: Colors.blue, value: (paymentSplit['upi'] ?? 0).toDouble(), label: 'UPI'),
                                CustomDonutChartData(color: Colors.orange, value: (paymentSplit['card'] ?? 0).toDouble(), label: 'Card'),
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
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Branch Revenue', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                                child: BarChart(
                                  BarChartData(
                                    maxY: maxY,
                                    alignment: BarChartAlignment.spaceAround,
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            if (value.toInt() >= 0 && value.toInt() < branches.length) {
                                              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(branches[value.toInt()]['name']));
                                            }
                                            return const SizedBox();
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: branches.asMap().entries.map((e) {
                                      return BarChartGroupData(
                                        x: e.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: (e.value['revenue'] ?? 0).toDouble(), 
                                            gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                            width: 28, 
                                            borderRadius: BorderRadius.circular(6),
                                            backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: Colors.grey.shade100),
                                          ),
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
            ),
            const SizedBox(height: 24),
            _buildSalesTrendChart(context),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

Widget _buildSalesTrendChart(BuildContext context) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Revenue Growth', style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2575FC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Live Data', style: TextStyle(color: Color(0xFF2575FC), fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text('Daily sales performance over the selected period.', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 32),
          SizedBox(
            height: 320,
            child: ref.watch(salesTrendsProvider).when(
              data: (data) {
                if (data.isEmpty) return const Center(child: Text('No data available', style: TextStyle(color: Colors.black87)));
                
                List<FlSpot> spots = [];
                double maxAmt = 0;
                for (int i = 0; i < data.length; i++) {
                  double amt = (data[i]['amount'] as num).toDouble();
                  if (amt > maxAmt) maxAmt = amt;
                  spots.add(FlSpot(i.toDouble(), amt));
                }

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true, 
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const Text('');
                            return Text(CurrencyFormatter.format(value, decimalDigits: 0), style: TextStyle(fontSize: 10, color: Colors.grey[600]));
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: (data.length / 6).ceilToDouble().clamp(1.0, double.infinity),
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < data.length) {
                              DateTime d = DateTime.parse(data[value.toInt()]['date']);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(DateFormat('MMM d').format(d), style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: data.isEmpty ? 1 : (data.length > 1 ? (data.length - 1).toDouble() : 1),
                    minY: 0,
                    maxY: maxAmt * 1.2,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            DateTime d = DateTime.parse(data[spot.x.toInt()]['date']);
                            final branchesMap = data[spot.x.toInt()]['branches'] as Map<String, dynamic>?;
                            
                            List<TextSpan> children = [
                              TextSpan(
                                text: '${CurrencyFormatter.format(spot.y)}\n',
                                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                              ),
                            ];
                            
                            if (branchesMap != null && branchesMap.isNotEmpty) {
                              branchesMap.forEach((branchName, amount) {
                                children.add(
                                  TextSpan(
                                    text: '$branchName: ${CurrencyFormatter.format(amount, decimalDigits: 0)}\n',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.normal),
                                  ),
                                );
                              });
                            }
                            
                            return LineTooltipItem(
                              '${DateFormat('MMM d, yyyy').format(d)}\n',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              children: children,
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        preventCurveOverShooting: true,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: const Color(0xFF2575FC),
                            );
                          },
                        ),
                        shadow: const Shadow(
                          color: Color(0x332575FC),
                          blurRadius: 15,
                          offset: Offset(0, 10),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF2575FC).withOpacity(0.15),
                              const Color(0xFF2575FC).withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
