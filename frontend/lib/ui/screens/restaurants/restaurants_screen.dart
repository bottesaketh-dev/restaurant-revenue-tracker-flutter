import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/restaurant_provider.dart';
import '../../../core/auth_provider.dart';
import '../../../core/app_notifier.dart';
import '../../../theme/app_theme.dart';
import '../../../core/responsive.dart';

class RestaurantsScreen extends ConsumerStatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  ConsumerState<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends ConsumerState<RestaurantsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = ref.watch(restaurantManagementProvider);
    final authState = ref.watch(authStateProvider);
    final isMobile = Responsive.isMobile(context);
    final canManage = authState.canManageRestaurants;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restaurant Organizations',
                      style: isMobile
                          ? Theme.of(context).textTheme.headlineMedium
                          : Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage multi-tenant restaurant profiles, branding, and currency configurations',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(restaurantManagementProvider.notifier).fetchRestaurants();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: isMobile ? const SizedBox.shrink() : const Text('Refresh'),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showRestaurantDialog(context, null),
                        icon: const Icon(Icons.add_business),
                        label: const Text('Add Restaurant'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content Area - Clean Directory View
            Expanded(
              child: _buildDirectoryView(restaurantsAsync, canManage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryView(
    AsyncValue<List<Map<String, dynamic>>> restaurantsAsync,
    bool canManage,
  ) {
    return Column(
      children: [
        // Search & Filters Row
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by restaurant name, slug, or email...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _statusFilter = val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // List Area
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: restaurantsAsync.when(
              data: (restaurants) {
                var filtered = restaurants.where((r) {
                  final name = (r['name'] ?? '').toString().toLowerCase();
                  final slug = (r['slug'] ?? '').toString().toLowerCase();
                  final email = (r['contact_email'] ?? '').toString().toLowerCase();
                  final matchesSearch = name.contains(_searchQuery) ||
                      slug.contains(_searchQuery) ||
                      email.contains(_searchQuery);

                  final isActive = r['is_active'] == true;
                  final matchesStatus = _statusFilter == 'ALL' ||
                      (_statusFilter == 'ACTIVE' && isActive) ||
                      (_statusFilter == 'INACTIVE' && !isActive);

                  return matchesSearch && matchesStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No restaurants found',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final rest = filtered[index];
                    return _RestaurantTile(
                      restaurant: rest,
                      canManage: canManage,
                      onEdit: () => _showRestaurantDialog(context, rest),
                      onDelete: () => _confirmDeleteRestaurant(rest),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load restaurants: $err', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.read(restaurantManagementProvider.notifier).fetchRestaurants(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRestaurantDialog(BuildContext context, Map<String, dynamic>? restaurant) {
    showDialog(
      context: context,
      builder: (context) => _RestaurantDialog(restaurant: restaurant),
    );
  }

  void _confirmDeleteRestaurant(Map<String, dynamic> restaurant) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Deactivate Restaurant Organization'),
        content: Text(
          'Are you sure you want to deactivate or remove "${restaurant['name']}"?\n\n'
          'To protect operational and financial integrity, restaurants with branches or past transactions will be soft-deactivated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final result = await ref
                    .read(restaurantManagementProvider.notifier)
                    .deleteRestaurant(restaurant['restaurant_id']);
                if (mounted) {
                  AppNotifier.showSuccess(context, result['message'] ?? 'Restaurant updated successfully.');
                }
              } catch (e) {
                if (mounted) {
                  AppNotifier.showError(context, e.toString());
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RestaurantTile({
    required this.restaurant,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = restaurant['is_active'] == true;
    final currencySymbol = restaurant['currency_symbol'] ?? '₹';
    final currencyCode = restaurant['currency_code'] ?? 'INR';
    final taxRate = (restaurant['tax_rate'] != null)
        ? (double.tryParse(restaurant['tax_rate'].toString()) ?? 0.05) * 100
        : 5.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.storefront, color: AppTheme.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        restaurant['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        restaurant['slug'] ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(restaurant['contact_email'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      ],
                    ),
                    if (restaurant['contact_phone'] != null && restaurant['contact_phone'].toString().isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(restaurant['contact_phone'].toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_exchange, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('$currencySymbol ($currencyCode) • Tax: ${taxRate.toStringAsFixed(1)}%',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
              tooltip: 'Edit Restaurant',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: 'Deactivate / Remove',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class _RestaurantDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? restaurant;

  const _RestaurantDialog({this.restaurant});

  @override
  ConsumerState<_RestaurantDialog> createState() => _RestaurantDialogState();
}

class _RestaurantDialogState extends ConsumerState<_RestaurantDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _slugController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _currencyCodeController;
  late TextEditingController _currencySymbolController;
  late TextEditingController _taxRateController;
  late TextEditingController _receiptHeaderController;
  late TextEditingController _receiptFooterController;
  late bool _isActive;
  bool _isLoading = false;

  bool get isEditing => widget.restaurant != null;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    _nameController = TextEditingController(text: r?['name'] ?? '');
    _slugController = TextEditingController(text: r?['slug'] ?? '');
    _emailController = TextEditingController(text: r?['contact_email'] ?? '');
    _phoneController = TextEditingController(text: r?['contact_phone'] ?? '');
    _currencyCodeController = TextEditingController(text: r?['currency_code'] ?? 'INR');
    _currencySymbolController = TextEditingController(text: r?['currency_symbol'] ?? '₹');
    _taxRateController = TextEditingController(
      text: r?['tax_rate'] != null ? r!['tax_rate'].toString() : '0.05',
    );
    _receiptHeaderController = TextEditingController(text: r?['receipt_header'] ?? '');
    _receiptFooterController = TextEditingController(text: r?['receipt_footer'] ?? '');
    _isActive = r?['is_active'] ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currencyCodeController.dispose();
    _currencySymbolController.dispose();
    _taxRateController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final tax = double.tryParse(_taxRateController.text.trim()) ?? 0.05;

    final data = {
      'name': _nameController.text.trim(),
      'slug': _slugController.text.trim().toLowerCase(),
      'contact_email': _emailController.text.trim(),
      'contact_phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'currency_code': _currencyCodeController.text.trim().toUpperCase(),
      'currency_symbol': _currencySymbolController.text.trim(),
      'tax_rate': tax,
      'receipt_header': _receiptHeaderController.text.trim().isEmpty ? null : _receiptHeaderController.text.trim(),
      'receipt_footer': _receiptFooterController.text.trim().isEmpty ? null : _receiptFooterController.text.trim(),
      'is_active': _isActive,
    };

    try {
      if (isEditing) {
        await ref
            .read(restaurantManagementProvider.notifier)
            .updateRestaurant(widget.restaurant!['restaurant_id'], data);
        if (mounted) {
          Navigator.pop(context);
          AppNotifier.showSuccess(context, 'Restaurant organization updated.');
        }
      } else {
        await ref.read(restaurantManagementProvider.notifier).createRestaurant(data);
        if (mounted) {
          Navigator.pop(context);
          AppNotifier.showSuccess(context, 'Restaurant organization created.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppNotifier.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Restaurant Organization' : 'Add New Restaurant',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),

                // Name & Slug
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Restaurant Name *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        onChanged: (val) {
                          if (!isEditing && _slugController.text.isEmpty) {
                            _slugController.text = val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _slugController,
                        decoration: const InputDecoration(labelText: 'URL Slug *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Slug is required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Contact Email & Phone
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Contact Email *'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Contact Phone'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Currency Code, Symbol, Tax Rate
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _currencyCodeController,
                        decoration: const InputDecoration(labelText: 'Currency Code'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _currencySymbolController,
                        decoration: const InputDecoration(labelText: 'Currency Symbol'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _taxRateController,
                        decoration: const InputDecoration(labelText: 'Tax Rate (e.g. 0.05)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Receipt Header & Footer
                TextFormField(
                  controller: _receiptHeaderController,
                  decoration: const InputDecoration(labelText: 'Receipt Header Note'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _receiptFooterController,
                  decoration: const InputDecoration(labelText: 'Receipt Footer Note'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Active Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Organization'),
                  subtitle: const Text('Inactive restaurants cannot process orders or authenticate staff'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEditing ? 'Save Changes' : 'Create Organization'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
