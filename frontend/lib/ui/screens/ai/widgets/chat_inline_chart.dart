import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/chat_provider.dart';
import '../../../../core/currency_formatter.dart';
import '../../../../theme/app_theme.dart';

class ChatInlineChart extends StatefulWidget {
  final ChatInlineChartSpec chartSpec;
  final List<dynamic> rawData;

  const ChatInlineChart({
    super.key,
    required this.chartSpec,
    this.rawData = const [],
  });

  @override
  State<ChatInlineChart> createState() => _ChatInlineChartState();
}

class _ChatInlineChartState extends State<ChatInlineChart> {
  bool _showTable = false;

  // Chart Color Palette
  static const List<Color> _palette = [
    Color(0xFF012D1D), // Royal India Green
    Color(0xFF8E4E14), // Saffron Gold
    Color(0xFF1B4332), // Emerald Forest
    Color(0xFF2D6A4F), // Jade
    Color(0xFFD4A373), // Warm Sand
    Color(0xFF52796F), // Muted Sage
    Color(0xFFB08968), // Bronze
    Color(0xFF40916C), // Mint Green
  ];

  @override
  Widget build(BuildContext context) {
    final spec = widget.chartSpec;
    final data = spec.data;

    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text('No numerical data points available for chart: ${spec.title}'),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title and Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getChartIcon(spec.chartType),
                            size: 18,
                            color: AppTheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              spec.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (spec.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          spec.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showTable = !_showTable;
                    });
                  },
                  icon: Icon(
                    _showTable ? Icons.bar_chart : Icons.table_chart_outlined,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  label: Text(
                    _showTable ? 'Show Chart' : 'View Data (${data.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content: Chart or Tabular Data
          Padding(
            padding: const EdgeInsets.all(20),
            child: _showTable ? _buildDataTable(data) : _buildChart(spec, data),
          ),
        ],
      ),
    );
  }

  IconData _getChartIcon(String type) {
    switch (type.toLowerCase()) {
      case 'line':
      case 'area':
        return Icons.show_chart;
      case 'pie':
      case 'donut':
        return Icons.pie_chart;
      default:
        return Icons.bar_chart;
    }
  }

  Widget _buildChart(ChatInlineChartSpec spec, List<dynamic> data) {
    switch (spec.chartType.toLowerCase()) {
      case 'line':
      case 'area':
        return _buildLineChart(spec, data);
      case 'pie':
      case 'donut':
        return _buildPieChart(spec, data);
      default:
        return _buildBarChart(spec, data);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers: Color Parsing & Series Legend
  // ---------------------------------------------------------------------------
  static Color _parseColor(dynamic hex, Color fallback) {
    if (hex == null || hex is! String) return fallback;
    var str = hex.replaceAll('#', '').trim();
    if (str.length == 6) {
      str = 'FF$str';
    }
    final val = int.tryParse(str, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  Widget _buildLegend(List<Map<String, dynamic>> seriesList) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: List.generate(seriesList.length, (sIdx) {
          final s = seriesList[sIdx];
          final color = _parseColor(s['color'], _palette[sIdx % _palette.length]);
          final name = s['name']?.toString() ?? s['field']?.toString() ?? '';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Native Bar Chart
  // ---------------------------------------------------------------------------
  Widget _buildBarChart(ChatInlineChartSpec spec, List<dynamic> data) {
    final xField = spec.xField;
    final seriesMaps = <Map<String, dynamic>>[];
    for (var s in spec.series) {
      if (s is Map<String, dynamic>) {
        seriesMaps.add(s);
      }
    }
    if (seriesMaps.isEmpty) {
      seriesMaps.add({
        'name': spec.yLabel.isNotEmpty ? spec.yLabel : spec.yField,
        'field': spec.yField,
        'color': '#012D1D',
      });
    }

    final isMultiSeries = seriesMaps.length > 1;
    final barGroups = <BarChartGroupData>[];
    double maxY = 0.0;
    final labels = <String>[];

    final rodWidth = isMultiSeries
        ? min(14.0, max(6.0, 180 / ((data.length + 1) * seriesMaps.length)))
        : min(28.0, max(12.0, 300 / (data.length + 1)));

    for (int i = 0; i < data.length; i++) {
      final row = data[i] as Map<String, dynamic>;
      final label = row[xField]?.toString() ?? 'Item $i';
      labels.add(label);

      final rods = <BarChartRodData>[];
      for (int sIdx = 0; sIdx < seriesMaps.length; sIdx++) {
        final s = seriesMaps[sIdx];
        final field = s['field']?.toString() ?? spec.yField;
        final color = _parseColor(s['color'], _palette[sIdx % _palette.length]);

        final rawVal = row[field];
        final val = (rawVal is num)
            ? rawVal.toDouble()
            : (double.tryParse(rawVal?.toString() ?? '0') ?? 0.0);

        if (val > maxY) maxY = val;

        rods.add(
          BarChartRodData(
            toY: val,
            color: color,
            width: rodWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        );
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: rods,
        ),
      );
    }

    if (maxY == 0) maxY = 100;
    final topY = maxY * 1.18;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMultiSeries) _buildLegend(seriesMaps),
        SizedBox(
          height: 280,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: topY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = labels[group.x.toInt()];
                    final sName = rodIndex < seriesMaps.length
                        ? (seriesMaps[rodIndex]['name']?.toString() ?? '')
                        : '';
                    return BarTooltipItem(
                      '$label\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      children: [
                        if (sName.isNotEmpty)
                          TextSpan(
                            text: '$sName: ',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        TextSpan(
                          text: CurrencyFormatter.format(rod.toY),
                          style: const TextStyle(
                            color: AppTheme.secondaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (val, meta) {
                      if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          _formatCompactNumber(val),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx >= 0 && idx < labels.length) {
                        final str = labels[idx];
                        final truncated = str.length > 10 ? '${str.substring(0, 8)}..' : str;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            truncated,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: topY / 4,
                getDrawingHorizontalLine: (val) => const FlLine(
                  color: Color(0xFFF3F4F6),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Native Line Chart (Supports Multi-Series Double Curves)
  // ---------------------------------------------------------------------------
  Widget _buildLineChart(ChatInlineChartSpec spec, List<dynamic> data) {
    final xField = spec.xField;
    final seriesMaps = <Map<String, dynamic>>[];
    for (var s in spec.series) {
      if (s is Map<String, dynamic>) {
        seriesMaps.add(s);
      }
    }
    if (seriesMaps.isEmpty) {
      seriesMaps.add({
        'name': spec.yLabel.isNotEmpty ? spec.yLabel : spec.yField,
        'field': spec.yField,
        'color': '#012D1D',
      });
    }

    final isMultiSeries = seriesMaps.length > 1;
    final labels = <String>[];
    for (int i = 0; i < data.length; i++) {
      final row = data[i] as Map<String, dynamic>;
      labels.add(row[xField]?.toString() ?? '$i');
    }

    double maxY = -double.infinity;
    double minY = double.infinity;

    final lineBarsData = <LineChartBarData>[];

    for (int sIdx = 0; sIdx < seriesMaps.length; sIdx++) {
      final s = seriesMaps[sIdx];
      final field = s['field']?.toString() ?? spec.yField;
      final color = _parseColor(s['color'], _palette[sIdx % _palette.length]);

      final spots = <FlSpot>[];
      for (int i = 0; i < data.length; i++) {
        final row = data[i] as Map<String, dynamic>;
        final rawVal = row[field];
        final val = (rawVal is num)
            ? rawVal.toDouble()
            : (double.tryParse(rawVal?.toString() ?? '0') ?? 0.0);

        if (val > maxY) maxY = val;
        if (val < minY) minY = val;

        spots.add(FlSpot(i.toDouble(), val));
      }

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: data.length <= 15,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: color,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: !isMultiSeries,
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      );
    }

    if (maxY == -double.infinity || maxY == 0) maxY = 100;
    if (minY == double.infinity) minY = 0;

    final double effectiveMinY = minY < 0 ? (minY * 1.15).floorToDouble() : 0.0;
    final double effectiveMaxY = (maxY * 1.2).ceilToDouble();
    final double yRange = effectiveMaxY - effectiveMinY;
    final double interval = yRange > 0 ? (yRange / 4) : 25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMultiSeries) _buildLegend(seriesMaps),
        SizedBox(
          height: 280,
          child: LineChart(
            LineChartData(
              maxY: effectiveMaxY,
              minY: effectiveMinY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final sIdx = spot.barIndex;
                      final sName = sIdx < seriesMaps.length
                          ? (seriesMaps[sIdx]['name']?.toString() ?? '')
                          : '';
                      final sColor = sIdx < seriesMaps.length
                          ? _parseColor(seriesMaps[sIdx]['color'], AppTheme.secondaryContainer)
                          : AppTheme.secondaryContainer;
                      final idx = spot.x.toInt();
                      final label = (idx >= 0 && idx < labels.length) ? labels[idx] : '';
                      final isFirst = spot == touchedSpots.first;

                      return LineTooltipItem(
                        isFirst ? '$label\n' : '',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        children: [
                          TextSpan(
                            text: '${sName.isNotEmpty ? "$sName: " : ""}${CurrencyFormatter.format(spot.y)}',
                            style: TextStyle(color: sColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    interval: interval > 0 ? interval : null,
                    getTitlesWidget: (val, meta) {
                      if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          _formatCompactNumber(val),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: max(1.0, (data.length / 6).floorToDouble()),
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx >= 0 && idx < labels.length) {
                        final str = labels[idx];
                        final truncated = str.length > 10 ? '${str.substring(0, 8)}..' : str;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            truncated,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval > 0 ? interval : null,
                getDrawingHorizontalLine: (val) => const FlLine(
                  color: Color(0xFFF3F4F6),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: lineBarsData,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Native Pie Chart
  // ---------------------------------------------------------------------------
  Widget _buildPieChart(ChatInlineChartSpec spec, List<dynamic> data) {
    final xField = spec.xField;
    final yField = spec.yField;

    double totalVal = 0.0;
    final rows = <Map<String, dynamic>>[];

    for (var item in data) {
      final row = item as Map<String, dynamic>;
      final raw = row[yField];
      final val = (raw is num) ? raw.toDouble() : (double.tryParse(raw?.toString() ?? '0') ?? 0.0);
      if (val > 0) {
        totalVal += val;
        rows.add({'label': row[xField]?.toString() ?? 'Other', 'val': val});
      }
    }

    if (totalVal == 0) totalVal = 1;

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < min(rows.length, 8); i++) {
      final r = rows[i];
      final val = r['val'] as double;
      final pct = (val / totalVal) * 100;
      final color = _palette[i % _palette.length];

      sections.add(
        PieChartSectionData(
          color: color,
          value: val,
          title: pct >= 5 ? '${pct.toStringAsFixed(1)}%' : '',
          radius: 65,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(min(rows.length, 8), (i) {
            final r = rows[i];
            final color = _palette[i % _palette.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '${r['label']}: ${CurrencyFormatter.format(r['val'])}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Tabular Data Viewer
  // ---------------------------------------------------------------------------
  Widget _buildDataTable(List<dynamic> data) {
    if (data.isEmpty) return const Text('No records');

    final firstRow = data.first as Map<String, dynamic>;
    final columns = firstRow.keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
        columnSpacing: 24,
        columns: columns.map((col) {
          final cleanCol = col.replaceAll('_', ' ').toUpperCase();
          return DataColumn(
            label: Text(
              cleanCol,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4B5563)),
            ),
          );
        }).toList(),
        rows: data.map((rowMap) {
          final m = rowMap as Map<String, dynamic>;
          return DataRow(
            cells: columns.map((col) {
              final val = m[col];
              String displayVal = val?.toString() ?? '-';
              if (val is num && ["amount", "revenue", "price", "sale", "cost", "salary", "expense", "margin"].any((k) => col.toLowerCase().contains(k))) {
                displayVal = CurrencyFormatter.format(val.toDouble());
              }
              return DataCell(
                Text(
                  displayVal,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  static String _formatCompactNumber(double val) {
    final isNeg = val < 0;
    final absVal = val.abs();
    String formatted;
    if (absVal >= 10000000) {
      formatted = '${(absVal / 10000000).toStringAsFixed(1)}Cr';
    } else if (absVal >= 100000) {
      formatted = '${(absVal / 100000).toStringAsFixed(1)}L';
    } else if (absVal >= 1000) {
      formatted = '${(absVal / 1000).toStringAsFixed(0)}k';
    } else {
      formatted = absVal.toStringAsFixed(0);
    }
    return isNeg ? '-$formatted' : formatted;
  }
}
