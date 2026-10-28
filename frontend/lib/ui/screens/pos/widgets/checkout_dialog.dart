import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/pos_provider.dart';
import '../../../../core/auth_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/currency_formatter.dart';
import '../../../../core/app_notifier.dart';

class CheckoutDialog extends ConsumerStatefulWidget {
  final String tableId;
  final List<CartItemModel> items;

  const CheckoutDialog({
    super.key,
    required this.tableId,
    required this.items,
  });

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _tipController = TextEditingController();
  final _cashController = TextEditingController();
  final _upiController = TextEditingController();
  final _cardController = TextEditingController();
  
  String _paymentMode = 'CASH';
  bool _isLoading = false;
  bool _autoPrint = true;

  @override
  void initState() {
    super.initState();
    _tipController.addListener(() => setState(() {}));
    _cashController.addListener(() => setState(() {}));
    _upiController.addListener(() => setState(() {}));
    _cardController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tipController.dispose();
    _cashController.dispose();
    _upiController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  double get subtotal => widget.items.fold(0, (sum, item) => sum + (double.tryParse(item.menuItem['price'].toString()) ?? 0.0) * item.quantity);
  double get taxRate => ref.watch(authStateProvider).taxRate;
  double get taxes => subtotal * taxRate;
  double get tipAmount => double.tryParse(_tipController.text) ?? 0.0;
  double get total => subtotal + taxes + tipAmount;

  double get cashAmount => double.tryParse(_cashController.text) ?? 0.0;
  double get upiAmount => double.tryParse(_upiController.text) ?? 0.0;
  double get cardAmount => double.tryParse(_cardController.text) ?? 0.0;
  double get mixedTotal => cashAmount + upiAmount + cardAmount;

  Future<void> _processCheckout() async {
    if (_paymentMode == 'MIXED') {
      if ((mixedTotal - total).abs() > 0.01) {
        AppNotifier.showError(context, 'Mixed payment amounts (${CurrencyFormatter.format(mixedTotal)}) must equal total (${CurrencyFormatter.format(total)})');
        return;
      }
    }

    setState(() => _isLoading = true);
    
    try {
      final res = await ref.read(posCartProvider.notifier).checkout(
        tableId: widget.tableId,
        paymentMode: _paymentMode,
        tipAmount: tipAmount,
        cashAmount: _paymentMode == 'MIXED' ? cashAmount : (_paymentMode == 'CASH' ? total : 0.0),
        upiAmount: _paymentMode == 'MIXED' ? upiAmount : (_paymentMode == 'UPI' ? total : 0.0),
        cardAmount: _paymentMode == 'MIXED' ? cardAmount : (_paymentMode == 'CARD' ? total : 0.0),
        autoPrint: _autoPrint,
      );
      
      if (mounted) {
        Navigator.pop(context, true);
        final printMsg = res['print_status'];
        if (_autoPrint && printMsg != null) {
          final str = printMsg.toString().toLowerCase();
          if (str.contains("fail") || str.contains("error") || str.contains("warning")) {
            AppNotifier.showWarning(context, 'Payment Successful! Printer note: $printMsg');
          } else {
            AppNotifier.showSuccess(context, 'Payment Successful! Receipt Printed on Retsol.');
          }
        } else {
          AppNotifier.showSuccess(context, 'Payment Successful! Bill Generated.');
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Checkout - ${widget.tableId}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 32),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...widget.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.quantity}x ${item.menuItem['name']}'),
                          Text(CurrencyFormatter.format(((double.tryParse(item.menuItem['price'].toString()) ?? 0.0) * item.quantity))),
                        ],
                      ),
                    )),
                    const Divider(height: 32),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text(CurrencyFormatter.format(subtotal)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Taxes (${(taxRate * 100).toStringAsFixed(1)}%)'),
                        Text(CurrencyFormatter.format(taxes)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Tip Amount: ${CurrencyFormatter.activeSymbol}'),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _tipController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              hintText: '0.00',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Grand Total', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Text(CurrencyFormatter.format(total), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Text('Payment Mode', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: ['CASH', 'UPI', 'CARD', 'MIXED'].map((mode) => ChoiceChip(
                        label: Text(mode),
                        selected: _paymentMode == mode,
                        onSelected: (selected) {
                          if (selected) setState(() => _paymentMode = mode);
                        },
                      )).toList(),
                    ),
                    
                    if (_paymentMode == 'MIXED') ...[
                      const SizedBox(height: 24),
                      Text('Split Amounts (Remaining: ${CurrencyFormatter.format(total - mixedTotal)})', 
                        style: TextStyle(color: (total - mixedTotal).abs() > 0.01 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cashController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Cash ${CurrencyFormatter.activeSymbol}', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _upiController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'UPI ${CurrencyFormatter.activeSymbol}', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _cardController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Card ${CurrencyFormatter.activeSymbol}', isDense: true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Print Bill on Retsol Thermal Printer',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Switch(
                    value: _autoPrint,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) => setState(() => _autoPrint = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processCheckout,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Confirm Payment', style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
