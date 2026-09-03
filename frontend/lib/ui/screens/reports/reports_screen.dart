import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/reports_provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/responsive.dart';
import 'overview_view.dart';
import 'widgets/executive_summary_section.dart';
import 'widgets/sales_engineering_section.dart';
import 'widgets/inventory_supply_section.dart';
import 'widgets/expenses_hr_section.dart';
import 'widgets/operations_section.dart';

import '../../../core/home_provider.dart';
import '../../../core/api_client.dart';

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
    final currentTab = ref.watch(reportsTabProvider);
    final isMobile = Responsive.isMobile(context);
    
    return Container(
      color: Colors.transparent, // Inherit light background
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, currentTab, isMobile),
          const SizedBox(height: 32),
          Expanded(
            child: _buildSelectedTabContent(currentTab),
          )
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent(ReportsTab tab) {
    switch (tab) {
      case ReportsTab.overview:
        return const OverviewView();
      case ReportsTab.executiveSummary:
        return const SingleChildScrollView(child: ExecutiveSummarySection());
      case ReportsTab.salesEngineering:
        return const SingleChildScrollView(child: SalesEngineeringSection());
      case ReportsTab.inventorySupply:
        return const SingleChildScrollView(child: InventorySupplySection());
      case ReportsTab.expensesHr:
        return const SingleChildScrollView(child: ExpensesHrSection());
      case ReportsTab.operations:
        return const SingleChildScrollView(child: OperationsSection());
    }
  }

  Widget _buildHeader(BuildContext context, ReportsTab currentTab, bool isMobile) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: isMobile ? double.infinity : null,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleBtn('Overview', ReportsTab.overview, currentTab),
                  _buildToggleBtn('Executive Summary', ReportsTab.executiveSummary, currentTab),
                  _buildToggleBtn('Sales & Menu', ReportsTab.salesEngineering, currentTab),
                  _buildToggleBtn('Inventory', ReportsTab.inventorySupply, currentTab),
                  _buildToggleBtn('Expenses & HR', ReportsTab.expensesHr, currentTab),
                  _buildToggleBtn('Operations', ReportsTab.operations, currentTab),
                ],
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: isMobile ? const Text('') : const Text('Refresh'),
              onPressed: () {
                ref.invalidate(homeProvider);
                ref.invalidate(executiveSummaryProvider);
                ref.invalidate(salesEngineeringProvider);
                ref.invalidate(inventorySupplyProvider);
                ref.invalidate(expensesHrProvider);
                ref.invalidate(operationsProvider);
                ref.invalidate(reportsOverviewProvider);
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey[300]!),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final currentRange = ref.read(dateRangeProvider);
                final newRange = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
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
                  final fmt = DateFormat('MMM d');
                  return Text('${fmt.format(range.start)} - ${fmt.format(range.end)}');
                },
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (format) async {
                final range = ref.read(dateRangeProvider);
                final storage = ref.read(secureStorageProvider);
                final token = await storage.read(key: 'jwt_token');

                String url = 'http://localhost:8000/api/v1/reports/export?format=$format';
                if (range != null) {
                  final start = DateFormat('yyyy-MM-dd').format(range.start);
                  final end = DateFormat('yyyy-MM-dd').format(range.end);
                  url += '&start_date=$start&end_date=$end';
                }
                if (token != null) {
                  url += '&token=$token';
                }
                launchUrl(Uri.parse(url));
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
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.download),
                  label: isMobile ? const Text('Export') : const Text('Export Report'),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildToggleBtn(String label, ReportsTab tab, ReportsTab currentTab) {
    final isSelected = tab == currentTab;
    return GestureDetector(
      onTap: () {
        ref.read(reportsTabProvider.notifier).state = tab;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  }
