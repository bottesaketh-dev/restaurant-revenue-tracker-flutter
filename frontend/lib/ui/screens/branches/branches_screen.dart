import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/branch_provider.dart';
import '../../../core/restaurant_provider.dart';
import '../../../core/auth_provider.dart';
import '../../../core/app_notifier.dart';
import '../../../theme/app_theme.dart';
import '../../../core/responsive.dart';

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  String _searchQuery = '';
  int? _selectedRestaurantFilter;
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchManagementProvider);
    final restaurantsAsync = ref.watch(restaurantListProvider);
    final authState = ref.watch(authStateProvider);
    final isMobile = Responsive.isMobile(context);
    final isSuperAdmin = authState.isSuperAdmin;
    final canManage = authState.canManageBranches;

    final restaurants = restaurantsAsync.value ?? [];
    final restaurantMap = {
      for (final r in restaurants) r['restaurant_id'] as int?: r['name']?.toString() ?? 'Restaurant #${r['restaurant_id']}'
    };

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
                      'Branch Outlets',
                      style: isMobile
                          ? Theme.of(context).textTheme.headlineMedium
                          : Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage branch locations, dining operational scopes, and local configurations',
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
                        ref.read(branchManagementProvider.notifier).fetchBranches();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: isMobile ? const SizedBox.shrink() : const Text('Refresh'),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showBranchDialog(context, null, restaurants),
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Add Branch'),
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
              child: _buildDirectoryView(branchesAsync, restaurantMap, restaurants, canManage, isSuperAdmin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryView(
    AsyncValue<List<Map<String, dynamic>>> branchesAsync,
    Map<int?, String> restaurantMap,
    List<Map<String, dynamic>> restaurants,
    bool canManage,
    bool isSuperAdmin,
  ) {
    return Column(
      children: [
        // Search & Filters Row
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search branch by name or address...',
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
            if (isSuperAdmin) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedRestaurantFilter,
                    hint: const Text('All Parent Restaurants'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Parent Restaurants')),
                      ...restaurants.map((r) => DropdownMenuItem<int?>(
                            value: r['restaurant_id'] as int?,
                            child: Text(r['name'] ?? ''),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedRestaurantFilter = val);
                      ref.read(branchManagementProvider.notifier).fetchBranches(overrideRestaurantId: val);
                    },
                  ),
                ),
              ),
            ],
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
            child: branchesAsync.when(
              data: (branches) {
                var filtered = branches.where((b) {
                  final name = (b['name'] ?? '').toString().toLowerCase();
                  final address = (b['address'] ?? '').toString().toLowerCase();
                  final matchesSearch = name.contains(_searchQuery) || address.contains(_searchQuery);

                  final restId = b['restaurant_id'];
                  final matchesRestaurant = _selectedRestaurantFilter == null || restId == _selectedRestaurantFilter;

                  final isActive = b['is_active'] == true;
                  final matchesStatus = _statusFilter == 'ALL' ||
                      (_statusFilter == 'ACTIVE' && isActive) ||
                      (_statusFilter == 'INACTIVE' && !isActive);

                  return matchesSearch && matchesRestaurant && matchesStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_location_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No branches found',
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
                    final branch = filtered[index];
                    final restName = restaurantMap[branch['restaurant_id']] ?? 'Restaurant #${branch['restaurant_id']}';

                    return _BranchTile(
                      branch: branch,
                      restaurantName: restName,
                      canManage: canManage,
                      onEdit: () => _showBranchDialog(context, branch, restaurants),
                      onDelete: () => _confirmDeleteBranch(branch),
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
                    Text('Failed to load branches: $err', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.read(branchManagementProvider.notifier).fetchBranches(),
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

  void _showBranchDialog(
    BuildContext context,
    Map<String, dynamic>? branch,
    List<Map<String, dynamic>> restaurants,
  ) {
    showDialog(
      context: context,
      builder: (context) => _BranchDialog(branch: branch, restaurants: restaurants),
    );
  }

  void _confirmDeleteBranch(Map<String, dynamic> branch) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Deactivate Branch Outlet'),
        content: Text(
          'Are you sure you want to deactivate or remove "${branch['name']}"?\n\n'
          'To protect operational records (orders, bills, employees, inventory), branches with active data will be soft-deactivated.',
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
                    .read(branchManagementProvider.notifier)
                    .deleteBranch(branch['branch_id']);
                if (mounted) {
                  AppNotifier.showSuccess(context, result['message'] ?? 'Branch updated successfully.');
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

class _BranchTile extends StatelessWidget {
  final Map<String, dynamic> branch;
  final String restaurantName;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BranchTile({
    required this.branch,
    required this.restaurantName,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = branch['is_active'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
            child: const Icon(Icons.storefront, color: AppTheme.secondary, size: 26),
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
                        branch['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business, size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            restaurantName,
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                          ),
                        ],
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
                    if (branch['address'] != null && branch['address'].toString().isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(branch['address'].toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        ],
                      ),
                    if (branch['phone'] != null && branch['phone'].toString().isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(branch['phone'].toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
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
              tooltip: 'Edit Branch',
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

class _BranchDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? branch;
  final List<Map<String, dynamic>> restaurants;

  const _BranchDialog({this.branch, required this.restaurants});

  @override
  ConsumerState<_BranchDialog> createState() => _BranchDialogState();
}

class _BranchDialogState extends ConsumerState<_BranchDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  int? _selectedRestaurantId;
  late bool _isActive;
  bool _isLoading = false;

  bool get isEditing => widget.branch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    final authState = ref.read(authStateProvider);

    _nameController = TextEditingController(text: b?['name'] ?? '');
    _addressController = TextEditingController(text: b?['address'] ?? '');
    _phoneController = TextEditingController(text: b?['phone'] ?? '');
    _isActive = b?['is_active'] ?? true;

    if (isEditing) {
      _selectedRestaurantId = b?['restaurant_id'];
    } else {
      _selectedRestaurantId = authState.isSuperAdmin ? null : authState.restaurantId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final authState = ref.read(authStateProvider);

    final targetRestaurant = _selectedRestaurantId ?? authState.restaurantId;
    if (targetRestaurant == null) {
      AppNotifier.showError(context, 'Please select a parent restaurant organization.');
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'restaurant_id': targetRestaurant,
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'is_active': _isActive,
    };

    try {
      if (isEditing) {
        await ref
            .read(branchManagementProvider.notifier)
            .updateBranch(widget.branch!['branch_id'], data);
        if (mounted) {
          Navigator.pop(context);
          AppNotifier.showSuccess(context, 'Branch outlet updated successfully.');
        }
      } else {
        await ref.read(branchManagementProvider.notifier).createBranch(data);
        if (mounted) {
          Navigator.pop(context);
          AppNotifier.showSuccess(context, 'Branch outlet created successfully.');
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
    final authState = ref.watch(authStateProvider);
    final isSuperAdmin = authState.isSuperAdmin;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
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
                      isEditing ? 'Edit Branch Outlet' : 'Add New Branch',
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

                // Parent Restaurant Selector (Super Admins only or read-only indicator)
                if (isSuperAdmin) ...[
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedRestaurantId,
                    decoration: const InputDecoration(labelText: 'Parent Restaurant Organization *'),
                    items: widget.restaurants.map((r) {
                      return DropdownMenuItem<int?>(
                        value: r['restaurant_id'] as int?,
                        child: Text('${r['name']} (${r['currency_symbol'] ?? '₹'})'),
                      );
                    }).toList(),
                    validator: (v) => v == null ? 'Please select a parent restaurant' : null,
                    onChanged: (val) => setState(() => _selectedRestaurantId = val),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.business, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Parent Organization: ${authState.restaurantName}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Branch Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Branch Name * (e.g. Madhapur Flagship)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Branch name is required' : null,
                ),
                const SizedBox(height: 16),

                // Address
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Branch Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Contact Phone
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Contact Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Active Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Branch Outlet'),
                  subtitle: const Text('Inactive branches cannot process POS billing or accept dine-in tables'),
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
                          : Text(isEditing ? 'Save Changes' : 'Create Branch'),
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
