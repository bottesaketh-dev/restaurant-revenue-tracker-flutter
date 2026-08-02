import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/currency_formatter.dart';

class CustomDonutChartData {
  final String label;
  final double value;
  final Color color;

  CustomDonutChartData({required this.label, required this.value, required this.color});
}

class CustomDonutChart extends StatefulWidget {
  final List<CustomDonutChartData> data;
  final String centerLabel;
  final bool formatAsCurrency;
  final double radius;
  final double touchedRadius;
  final double centerSpaceRadius;

  const CustomDonutChart({
    super.key,
    required this.data,
    this.centerLabel = 'Total',
    this.formatAsCurrency = true,
    this.radius = 40,
    this.touchedRadius = 50,
    this.centerSpaceRadius = 70,
  });

  @override
  State<CustomDonutChart> createState() => _CustomDonutChartState();
}

class _CustomDonutChartState extends State<CustomDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(child: Text('No data available', style: TextStyle(color: Colors.black87)));
    }

    double total = widget.data.fold(0, (sum, item) => sum + item.value);

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: widget.centerSpaceRadius,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: widget.data.asMap().entries.map((e) {
                    final isTouched = e.key == touchedIndex;
                    final val = e.value.value;
                    final color = e.value.color;
                    
                    String title;
                    if (isTouched) {
                      String formattedVal = widget.formatAsCurrency 
                          ? CurrencyFormatter.format(val, decimalDigits: 0) 
                          : val.toStringAsFixed(0);
                      title = '${e.value.label}\n$formattedVal';
                    } else {
                      title = total == 0 ? '0%' : '${((val / total) * 100).toStringAsFixed(0)}%';
                    }
                    
                    return PieChartSectionData(
                      color: color,
                      value: val,
                      title: title,
                      radius: isTouched ? widget.touchedRadius : widget.radius,
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
                  Text(widget.centerLabel, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  Text(
                    widget.formatAsCurrency 
                        ? CurrencyFormatter.format(total, decimalDigits: 0) 
                        : total.toStringAsFixed(0), 
                    style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: widget.data.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(e.label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            );
          }).toList(),
        )
      ],
    );
  }
}
