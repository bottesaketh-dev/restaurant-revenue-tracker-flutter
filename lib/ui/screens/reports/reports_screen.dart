import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/reports_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:html' as html;

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int? touchedCategoryIndex;
  int? touchedExpenseIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, // Inherit light background
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildKpiRow(context),
                  const SizedBox(height: 24),
                  _buildSalesTrendChart(context),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildCategoryRevenueDonutChart(context),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildTopItemsList(context),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildExpenseBreakdownDonutChart(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Command Center',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Global Multi-Branch Intelligence Dashboard',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey[300]!),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final currentRange = ref.read(dateRangeProvider);
                final newRange = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialEntryMode: DatePickerEntryMode.input,
                  initialDateRange: currentRange ?? DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 30)),
                    end: DateTime.now(),
                  ),
                );
                if (newRange != null) {
                  ref.read(dateRangeProvider.notifier).state = newRange;
                }
              },
              icon: const Icon(Icons.calendar_month, color: Color(0xFF2575FC)),
              label: Consumer(
                builder: (context, ref, child) {
                  final range = ref.watch(dateRangeProvider);
                  if (range == null) return const Text('Last 30 Days');
                  final fmt = DateFormat('MMM d, yyyy');
                  return Text('${fmt.format(range.start)} - ${fmt.format(range.end)}');
                },
              ),
            ),
            const SizedBox(width: 16),
            PopupMenuButton<String>(
              onSelected: (format) {
                final range = ref.read(dateRangeProvider);
                String url = 'http://localhost:8000/api/v1/reports/export?format=$format';
                if (range != null) {
                  final start = DateFormat('yyyy-MM-dd').format(range.start);
                  final end = DateFormat('yyyy-MM-dd').format(range.end);
                  url += '&start_date=$start&end_date=$end';
                }
                html.window.open(url, '_blank');
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
                const PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
              ],
              child: IgnorePointer(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.download),
                  label: const Text('Export Report'),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, double? height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: child,
      ),
    );
  }

  Widget _buildKpiRow(BuildContext context) {
    return ref.watch(metricsSummaryProvider).when(
      data: (data) {
        final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
        return Row(
          children: [
            Expanded(child: _buildGlassMetricCard('Total Revenue', currencyFormatter.format(data['revenue']), Icons.auto_graph, const [Color(0xFF00C9FF), Color(0xFF92FE9D)])),
            const SizedBox(width: 16),
            Expanded(child: _buildGlassMetricCard('Net Profit', currencyFormatter.format(data['net_profit']), Icons.account_balance_wallet, const [Color(0xFFF54EA2), Color(0xFFFF7676)])),
            const SizedBox(width: 16),
            Expanded(child: _buildGlassMetricCard('Total Expenses', currencyFormatter.format(data['expenses']), Icons.money_off, const [Color(0xFFFF9A44), Color(0xFFFC6076)])),
            const SizedBox(width: 16),
            Expanded(child: _buildGlassMetricCard('Avg Order Value', currencyFormatter.format(data['avg_order_value']), Icons.analytics, const [Color(0xFF6A11CB), Color(0xFF2575FC)])),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildGlassMetricCard(String title, String value, IconData icon, List<Color> gradientColors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: gradientColors.map((c) => c.withOpacity(0.15)).toList()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors.last.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4)
                          )
                        ]
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const Text('');
                            return Text('${(value / 1000).toStringAsFixed(0)}k', style: TextStyle(fontSize: 10, color: Colors.grey[600]));
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
                    maxX: (data.length - 1).toDouble(),
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
                                text: '₹${spot.y.toStringAsFixed(2)}\n',
                                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                              ),
                            ];
                            
                            if (branchesMap != null && branchesMap.isNotEmpty) {
                              branchesMap.forEach((branchName, amount) {
                                children.add(
                                  TextSpan(
                                    text: '$branchName: ₹${(amount as num).toStringAsFixed(0)}\n',
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



  Widget _buildCategoryRevenueDonutChart(BuildContext context) {
    return _buildGlassCard(
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category Revenue', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ref.watch(categoryRevenueProvider).when(
              data: (data) {
                if (data.isEmpty) return const Center(child: Text('No data available', style: TextStyle(color: Colors.black87)));
                
                final colors = [
                  const Color(0xFF00C9FF), const Color(0xFF92FE9D), const Color(0xFFF54EA2), const Color(0xFFFF7676), const Color(0xFF6A11CB), const Color(0xFF2575FC)
                ];
                
                double total = 0;
                for (var d in data) total += (d['revenue'] as num).toDouble();
                final fmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius: 70,
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      touchedCategoryIndex = -1;
                                      return;
                                    }
                                    touchedCategoryIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              sections: data.asMap().entries.map((e) {
                                final isTouched = e.key == touchedCategoryIndex;
                                final val = (e.value['revenue'] as num).toDouble();
                                final color = colors[e.key % colors.length];
                                
                                String title;
                                if (isTouched) {
                                  title = '${e.value['category']}\n${fmt.format(val)}';
                                } else {
                                  title = '${((val/total)*100).toStringAsFixed(0)}%';
                                }
                                
                                return PieChartSectionData(
                                  color: color,
                                  value: val,
                                  title: title,
                                  radius: isTouched ? 50 : 40,
                                  titleStyle: TextStyle(
                                    fontSize: isTouched ? 11 : 10, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.white,
                                    shadows: const [Shadow(color: Colors.black26, blurRadius: 4)]
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Total', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              Text(fmt.format(total), style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: data.asMap().entries.map((e) {
                        final color = colors[e.key % colors.length];
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(e.value['category'], style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ],
                        );
                      }).toList(),
                    )
                  ],
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

  Widget _buildTopItemsList(BuildContext context) {
    return _buildGlassCard(
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Performing Items', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ref.watch(topItemsProvider).when(
              data: (data) {
                if (data.isEmpty) return const Center(child: Text('No data available', style: TextStyle(color: Colors.black87)));
                
                double maxQty = 0;
                for (var d in data) {
                  double qty = (d['quantity'] as num).toDouble();
                  if (qty > maxQty) maxQty = qty;
                }
                if (maxQty == 0) maxQty = 1;

                return ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final qty = (item['quantity'] as num).toDouble();
                    final percent = qty / maxQty;
                    
                    return Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('${index + 1}', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item['name'], style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('${qty.toInt()} sold', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                children: [
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: percent,
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFFF54EA2), Color(0xFFFF7676)]),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
          )
        ],
      )
    );
  }

  Widget _buildExpenseBreakdownDonutChart(BuildContext context) {
    return _buildGlassCard(
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expense Breakdown', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ref.watch(expenseBreakdownProvider).when(
              data: (data) {
                if (data.isEmpty) return const Center(child: Text('No data available', style: TextStyle(color: Colors.black87)));
                
                final colors = [
                  const Color(0xFFFF9A44), const Color(0xFFFC6076), const Color(0xFFF54EA2), const Color(0xFF6A11CB), const Color(0xFF2575FC)
                ];
                
                double total = 0;
                for (var d in data) total += (d['amount'] as num).toDouble();
                final fmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius: 70,
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      touchedExpenseIndex = -1;
                                      return;
                                    }
                                    touchedExpenseIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              sections: data.asMap().entries.map((e) {
                                final isTouched = e.key == touchedExpenseIndex;
                                final val = (e.value['amount'] as num).toDouble();
                                final color = colors[e.key % colors.length];
                                
                                String title;
                                if (isTouched) {
                                  title = '${e.value['category']}\n${fmt.format(val)}';
                                } else {
                                  title = '${((val/total)*100).toStringAsFixed(0)}%';
                                }
                                
                                return PieChartSectionData(
                                  color: color,
                                  value: val,
                                  title: title,
                                  radius: isTouched ? 50 : 40,
                                  titleStyle: TextStyle(
                                    fontSize: isTouched ? 11 : 10, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.white,
                                    shadows: const [Shadow(color: Colors.black26, blurRadius: 4)]
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Outflow', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              Text(fmt.format(total), style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: data.asMap().entries.map((e) {
                        final color = colors[e.key % colors.length];
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(e.value['category'], style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ],
                        );
                      }).toList(),
                    )
                  ],
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
