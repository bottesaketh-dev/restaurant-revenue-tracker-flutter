import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/pos_provider.dart';
import '../../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../../../../core/currency_formatter.dart';

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
  double get taxes => subtotal * 0.05;
  double get tipAmount => double.tryParse(_tipController.text) ?? 0.0;
  double get total => subtotal + taxes + tipAmount;

  double get cashAmount => double.tryParse(_cashController.text) ?? 0.0;
  double get upiAmount => double.tryParse(_upiController.text) ?? 0.0;
  double get cardAmount => double.tryParse(_cardController.text) ?? 0.0;
  double get mixedTotal => cashAmount + upiAmount + cardAmount;

  Future<void> _processCheckout() async {
    if (_paymentMode == 'MIXED') {
      if ((mixedTotal - total).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mixed payment amounts (${CurrencyFormatter.format(mixedTotal)}) must equal total (${CurrencyFormatter.format(total)})'))
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    
    try {
      await ref.read(posCartProvider.notifier).checkout(
        tableId: widget.tableId,
        paymentMode: _paymentMode,
        tipAmount: tipAmount,
        cashAmount: _paymentMode == 'MIXED' ? cashAmount : (_paymentMode == 'CASH' ? total : 0.0),
        upiAmount: _paymentMode == 'MIXED' ? upiAmount : (_paymentMode == 'UPI' ? total : 0.0),
        cardAmount: _paymentMode == 'MIXED' ? cardAmount : (_paymentMode == 'CARD' ? total : 0.0),
      );
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful! Bill Generated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                        const Text('Taxes (5%)'),
                        Text(CurrencyFormatter.format(taxes)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Tip Amount: ₹'),
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
                              decoration: const InputDecoration(labelText: 'Cash ₹', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _upiController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'UPI ₹', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _cardController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Card ₹', isDense: true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
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
