import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/reports_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../core/currency_formatter.dart';

class OverviewView extends ConsumerWidget {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(reportsOverviewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dashboardAsync.when(skipLoadingOnRefresh: false, 
          data: (data) {
            final netVal = (data['net'] as num?)?.toDouble() ?? 0.0;
            final inflowVal = (data['inflow'] as num?)?.toDouble() ?? 0.0;
            final marginPct = inflowVal > 0 ? ((netVal / inflowVal) * 100).toStringAsFixed(1) : '0.0';
            final isPositive = netVal >= 0;

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
                ),
              ],
            );

            final kpi2 = Column(
              children: [
                _KpiCard(
                  title: 'CASH OUTFLOW',
                  value: CurrencyFormatter.format(data['outflow'], decimalDigits: 0),
                  icon: Icons.arrow_downward,
                  color: AppTheme.error,
                  percentage: '${data['outflow_pct'] >= 0 ? '+' : ''}${data['outflow_pct']}%',
                  percentageColor: data['outflow_pct'] >= 0 ? AppTheme.error : AppTheme.primaryContainer,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _PaymentSplitChip('Groceries', data['grocery_outflow'])),
                    const SizedBox(width: 8),
                    Expanded(child: _PaymentSplitChip('Expenses', data['expense_outflow'])),
                    const SizedBox(width: 8),
                    Expanded(child: _PaymentSplitChip('Salaries', data['salary_outflow'])),
                  ],
                ),
              ],
            );

            final kpi3 = Column(
              children: [
                _KpiCard(
                  title: 'NET CASHFLOW',
                  value: CurrencyFormatter.format(data['net'], decimalDigits: 0),
                  icon: Icons.account_balance,
                  color: AppTheme.secondary,
                  percentage: '${data['net_pct'] >= 0 ? '+' : ''}${data['net_pct']}%',
                  percentageColor: data['net_pct'] >= 0 ? AppTheme.primary : AppTheme.error,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TextSplitChip('Margin', '$marginPct%', isAccent: isPositive),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _TextSplitChip(
                        'Operating Status',
                        isPositive
                            ? 'Surplus'
                            : ((data['salary_outflow'] as num?)?.toDouble() ?? 0.0) > 0
                                ? 'Deficit (Payroll)'
                                : 'Deficit',
                        isAccent: isPositive,
                      ),
                    ),
                  ],
                ),
              ],
            );

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
        Expanded(
          child: dashboardAsync.when(skipLoadingOnRefresh: false, 
            data: (data) {
              final recentBills = List<Map<String, dynamic>>.from(data['recent_bills']);
              final recentExpenses = List<Map<String, dynamic>>.from(data['recent_expenses']);
              final recentGroceries = List<Map<String, dynamic>>.from(data['recent_groceries']);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _BillsTableCard(bills: recentBills),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Expanded(
                          child: _GenericTableCard(
                            title: 'Recent Expenses',
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
                        Expanded(
                          child: _GenericTableCard(
                            title: 'Recent Groceries',
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
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
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
                  Text('Recent Bills', style: Theme.of(context).textTheme.headlineMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Container(
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
                  title: Row(
                    children: [
                      Expanded(flex: 2, child: Text('${b['date']} ${b['time']}', style: const TextStyle(fontSize: 14))),
                      Expanded(flex: 1, child: Text('${b['table_id']}', style: const TextStyle(fontSize: 14))),
                      Expanded(flex: 2, child: Text('${b['bill_id']}', style: const TextStyle(fontSize: 14))),
                      Expanded(flex: 2, child: Text(CurrencyFormatter.format(b['amount'] ?? 0), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('${b['status']}', style: TextStyle(fontSize: 14, color: b['status'] == 'PAID' ? Colors.green : Colors.orange))),
                    ],
                  ),
                  children: [
                    Container(
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
                Text('Recent Bills', style: Theme.of(context).textTheme.headlineMedium),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () => _showFullScreen(context),
                  tooltip: 'Full Screen',
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
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
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Container(
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
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: row.map((cell) => Expanded(
                    child: Text(cell, style: const TextStyle(fontSize: 14)),
                  )).toList(),
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () => _showFullScreen(context),
                  tooltip: 'Full Screen',
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
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
  final dynamic amount;
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
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(CurrencyFormatter.format(amount ?? 0, decimalDigits: 0), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TextSplitChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isAccent;
  const _TextSplitChip(this.label, this.value, {this.isAccent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isAccent ? Colors.green.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAccent ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isAccent ? Colors.green.shade800 : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isAccent ? Colors.green.shade900 : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
