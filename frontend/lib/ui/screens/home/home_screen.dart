import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/home_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../core/currency_formatter.dart';
import '../../../core/responsive.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(homeProvider);
    final now = DateTime.now();
    final displayDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final isMobile = Responsive.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Owner Dashboard',
                        style: isMobile 
                            ? Theme.of(context).textTheme.headlineMedium 
                            : Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayDate,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: () {
                      ref.invalidate(homeProvider);
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      ref.invalidate(homeProvider);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            dashboardAsync.when(
              skipLoadingOnRefresh: false,
              data: (data) {
                final kpi1 = Column(
                  children: [
                    _KpiCard(
                      title: 'CASH INFLOW',
                      value: CurrencyFormatter.format(data['inflow'], decimalDigits: 0),
                      icon: Icons.arrow_upward,
                      color: AppTheme.primary,
                      percentage: '${data['inflow_pct'] >= 0 ? '+' : ''}${data['inflow_pct']}%',
                      percentageColor: data['inflow_pct'] >= 0 ? AppTheme.primaryContainer : AppTheme.error,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _PaymentSplitChip('Cash', data['cash_inflow'])),
                        const SizedBox(width: 8),
                        Expanded(child: _PaymentSplitChip('UPI', data['upi_inflow'])),
                        const SizedBox(width: 8),
                        Expanded(child: _PaymentSplitChip('Card', data['card_inflow'])),
                      ],
                    )
                  ],
                );
                final kpi2 = _KpiCard(
                  title: 'CASH OUTFLOW',
                  value: CurrencyFormatter.format(data['outflow'], decimalDigits: 0),
                  icon: Icons.arrow_downward,
                  color: AppTheme.error,
                  percentage: '${data['outflow_pct'] >= 0 ? '+' : ''}${data['outflow_pct']}%',
                  percentageColor: data['outflow_pct'] >= 0 ? AppTheme.error : AppTheme.primaryContainer,
                );
                final kpi3 = _KpiCard(
                  title: 'NET CASHFLOW',
                  value: CurrencyFormatter.format(data['net'], decimalDigits: 0),
                  icon: Icons.account_balance,
                  color: AppTheme.secondary,
                  percentage: '${data['net_pct'] >= 0 ? '+' : ''}${data['net_pct']}%',
                  percentageColor: data['net_pct'] >= 0 ? AppTheme.primary : AppTheme.error,
                );

                if (isMobile) {
                  return Column(
                    children: [
                      kpi1,
                      const SizedBox(height: 16),
                      kpi2,
                      const SizedBox(height: 16),
                      kpi3,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: kpi1),
                    const SizedBox(width: 24),
                    Expanded(child: kpi2),
                    const SizedBox(width: 24),
                    Expanded(child: kpi3),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
            const SizedBox(height: 32),
            dashboardAsync.when(
              skipLoadingOnRefresh: false,
              data: (data) {
                final recentBills = List<Map<String, dynamic>>.from(data['recent_bills']);
                final recentExpenses = List<Map<String, dynamic>>.from(data['recent_expenses']);
                final recentGroceries = List<Map<String, dynamic>>.from(data['recent_groceries']);

                final billsCard = SizedBox(
                  height: 400,
                  child: _BillsTableCard(bills: recentBills),
                );

                final otherCards = Column(
                  children: [
                    SizedBox(
                      height: 250,
                      child: _GenericTableCard(
                        title: 'Today\'s Expenses',
                        columns: const ['Date', 'Desc', 'Amount', 'Mode'],
                        rows: recentExpenses.map((e) => <String>[
                          e['date']?.toString() ?? '',
                          e['description']?.toString() ?? '',
                          CurrencyFormatter.format(e['amount'] ?? 0),
                          e['payment_mode']?.toString() ?? '',
                        ]).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 250,
                      child: _GenericTableCard(
                        title: 'Today\'s Groceries',
                        columns: const ['Date', 'Item Name', 'Qty', 'Amount'],
                        rows: recentGroceries.map((g) => <String>[
                          g['date']?.toString() ?? '',
                          g['item_name']?.toString() ?? '',
                          (g['quantity'] ?? 0).toString(),
                          CurrencyFormatter.format(g['amount'] ?? 0),
                        ]).toList(),
                      ),
                    ),
                  ],
                );

                if (isMobile) {
                  return Column(
                    children: [
                      billsCard,
                      const SizedBox(height: 24),
                      otherCards,
                    ],
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: billsCard,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: otherCards,
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillsTableCard extends StatelessWidget {
  final List<Map<String, dynamic>> bills;
  const _BillsTableCard({required this.bills});

  void _showFullScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Today\'s Bills', style: Theme.of(context).textTheme.headlineMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => _buildContent(constraints.maxWidth),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double maxWidth) {
    final double tableWidth = maxWidth < 800 ? 800 : maxWidth;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2)),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Table', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Bill No', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final b = bills[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  title: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text('${b['date']} ${b['time']}', style: const TextStyle(fontSize: 14))),
                          Expanded(flex: 1, child: Text('${b['table_id']}', style: const TextStyle(fontSize: 14))),
                          Expanded(flex: 2, child: Text('${b['bill_id']}', style: const TextStyle(fontSize: 14))),
                          Expanded(flex: 2, child: Text(CurrencyFormatter.format(b['amount'] ?? 0), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('${b['status']}', style: TextStyle(fontSize: 14, color: b['status'] == 'PAID' ? Colors.green : Colors.orange))),
                        ],
                      ),
                    ),
                  ),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border(top: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ordered Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 8),
                                ...((b['items'] as List?) ?? []).map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item['quantity']}x ${item['name']}'),
                                      Text(CurrencyFormatter.format(item['total'])),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 8),
                                Text('Mode: ${b['payment_mode'] ?? '-'}'),
                                if ((b['cash_amount'] ?? 0) > 0) Text('Cash: ${CurrencyFormatter.format(b['cash_amount'])}'),
                                if ((b['upi_amount'] ?? 0) > 0) Text('UPI: ${CurrencyFormatter.format(b['upi_amount'])}'),
                                if ((b['card_amount'] ?? 0) > 0) Text('Card: ${CurrencyFormatter.format(b['card_amount'])}'),
                                if ((b['tip_amount'] ?? 0) > 0) Text('Tip: ${CurrencyFormatter.format(b['tip_amount'])}'),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Today\'s Bills', style: Theme.of(context).textTheme.headlineMedium),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () => _showFullScreen(context),
                  tooltip: 'Full Screen',
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => _buildContent(constraints.maxWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenericTableCard extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  const _GenericTableCard({
    required this.title,
    required this.columns,
    required this.rows,
  });

  void _showFullScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => _buildContent(constraints.maxWidth),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double maxWidth) {
    final double tableWidth = maxWidth < 600 ? 600 : maxWidth;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2)),
              ),
              child: Row(
                children: columns.map((c) => Expanded(
                  child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: row.map((cell) => Expanded(
                        child: Text(cell, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () => _showFullScreen(context),
                  tooltip: 'Full Screen',
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => _buildContent(constraints.maxWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String percentage;
  final Color percentageColor;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.percentage,
    required this.percentageColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.trending_up, color: percentageColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  percentage,
                  style: TextStyle(color: percentageColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  'vs yesterday',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSplitChip extends StatelessWidget {
  final String label;
  final double amount;
  const _PaymentSplitChip(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(CurrencyFormatter.format(amount, decimalDigits: 0), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87)),
        ],
      ),
    );
  }
}

