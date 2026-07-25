import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/groceries_provider.dart';
import '../../../theme/app_theme.dart';

class GroceriesScreen extends ConsumerWidget {
  const GroceriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groceriesAsync = ref.watch(groceriesProvider);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Groceries Logs',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Log Purchase'),
              )
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Card(
              child: groceriesAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return const Center(child: Text("No groceries logged."));
                  }
                  return ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.kitchen, color: Colors.orange),
                        ),
                        title: Text('${log['product_name']} (${log['quantity']} ${log['unit']})', style: Theme.of(context).textTheme.headlineMedium),
                        subtitle: Text('${log['purchase_date']} • Vendor: ${log['vendor_name'] ?? 'N/A'}'),
                        trailing: Text('₹ ${log['total_price']}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.error,
                        )),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          )
        ],
      ),
    );
  }
}
