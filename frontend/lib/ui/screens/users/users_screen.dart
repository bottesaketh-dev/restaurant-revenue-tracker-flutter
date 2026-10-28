import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/users_provider.dart';
import '../../../core/branch_provider.dart';
import '../../../core/auth_provider.dart';
import '../../../core/restaurant_provider.dart';
import '../../../core/nav_tabs.dart';
import '../../../core/app_notifier.dart';
import '../../../theme/app_theme.dart';
import '../../../core/responsive.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final branchesAsync = ref.watch(branchListProvider);
    final isMobile = Responsive.isMobile(context);
    final authState = ref.watch(authStateProvider);
    final isAdmin = authState.isAdmin;
    final selectedBranch = ref.watch(selectedBranchProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      'User Management',
                      style: isMobile 
                          ? Theme.of(context).textTheme.headlineMedium 
                          : Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 4),
                    Consumer(
                      builder: (context, ref, _) {
                        final activeTenant = ref.watch(activeTenantInfoProvider);
                        return Text(
                          'Manage application access and roles for ${activeTenant.name}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showUserDialog(context, ref, null),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: usersAsync.when(
                  data: (users) {
                    if (selectedBranch != null) {
                      users = users.where((u) => u['branch_id'] == selectedBranch).toList();
                    }
                    if (users.isEmpty) {
                      return const Center(child: Text('No users found in the selected branch.'));
                    }
                    final branches = branchesAsync.value ?? [];
                    final branchNameById = {
                      for (final b in branches) b['branch_id']: b['name'],
                    };
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final branchId = user['branch_id'];
                        final branchName = branchId == null
                            ? 'All Branches'
                            : (branchNameById[branchId] ?? 'Branch #$branchId');
                        
                        return _UserRow(
                          user: user,
                          branchName: branchName,
                          isAdmin: isAdmin,
                          onEdit: () => _showUserDialog(context, ref, user),
                          onDelete: () => _deleteUser(context, ref, user),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? user) {
    showDialog(
      context: context,
      builder: (context) => _UserDialog(user: user),
    );
  }

  void _deleteUser(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['username']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(usersProvider.notifier).deleteUser(user['user_id']);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final String branchName;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserRow({
    required this.user,
    required this.branchName,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends ConsumerState<_UserRow> {
  late String _accessLevel;
  late Set<String> _selectedTabs;

  @override
  void initState() {
    super.initState();
    _resetFromUser();
  }

  @override
  void didUpdateWidget(covariant _UserRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user['user_id'] != widget.user['user_id']) {
      _resetFromUser();
    }
  }

  void _resetFromUser() {
    _accessLevel = (widget.user['access_level'] as String?) ?? 'FULL';
    final tabs = widget.user['allowed_tabs'];
    _selectedTabs = tabs is List ? tabs.map((e) => e.toString()).toSet() : <String>{};
  }

  bool get _isDirty {
    final targetRole = (widget.user['role'] as String?)?.toUpperCase() ?? '';
    if (targetRole == 'SUPER_ADMIN') return false;
    final originalLevel = (widget.user['access_level'] as String?) ?? 'FULL';
    final originalTabs = widget.user['allowed_tabs'];
    final originalSet = originalTabs is List ? originalTabs.map((e) => e.toString()).toSet() : <String>{};
    if (_accessLevel != originalLevel) return true;
    if (_accessLevel == 'PARTIAL' && !setEquals(_selectedTabs, originalSet)) return true;
    return false;
  }

  Future<void> _saveAccess() async {
    try {
      await ref.read(usersProvider.notifier).updateAccess(
            widget.user['user_id'],
            _accessLevel,
            _accessLevel == 'PARTIAL' ? _selectedTabs.toList() : null,
          );
      if (!mounted) return;
      AppNotifier.showSuccess(context, 'Access updated for ${widget.user['username']}');
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isActive = user['is_active'] ?? true;
    final targetRole = (user['role'] as String?)?.toUpperCase() ?? '';
    final isTargetSuperAdmin = targetRole == 'SUPER_ADMIN';
    final currentAuth = ref.watch(authStateProvider);
    final isCallerSuperAdmin = currentAuth.isSuperAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isTargetSuperAdmin ? Colors.amber.shade100 : AppTheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  isTargetSuperAdmin ? Icons.security : Icons.person,
                  color: isTargetSuperAdmin ? Colors.amber.shade900 : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['username'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('${user['email']} • Role: ${user['role']} • Branch: ${widget.branchName}'),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: widget.onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          if (widget.isAdmin) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: isTargetSuperAdmin
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield, color: Colors.amber.shade900, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Super Admin • Unrestricted Full Platform Access',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Text('Tab Access:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _accessLevel,
                                  items: const [
                                    DropdownMenuItem(value: 'FULL', child: Text('Full Access (All Standard Tabs)')),
                                    DropdownMenuItem(value: 'PARTIAL', child: Text('Partial Access (Custom Tabs)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _accessLevel = val;
                                        if (val == 'PARTIAL' && _selectedTabs.isEmpty) {
                                          _selectedTabs = kNavTabs
                                              .where((t) => t.key != 'restaurants' && t.key != 'branches')
                                              .map((t) => t.key)
                                              .toSet();
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isDirty ? _saveAccess : null,
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text('Save Access'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                            if (_isDirty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Text(
                                  'Unsaved changes',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_accessLevel == 'PARTIAL') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                'Select Accessible Tabs for this user:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setState(() {
                                    final standardKeys = kNavTabs
                                        .where((t) => t.key != 'restaurants' && t.key != 'branches')
                                        .map((t) => t.key);
                                    _selectedTabs.addAll(standardKeys);
                                  });
                                },
                                child: const Text('Select All Standard', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setState(() {
                                    // If caller is not Super Admin, preserve restaurants if it was granted
                                    final keepRestaurants = !isCallerSuperAdmin && _selectedTabs.contains('restaurants');
                                    _selectedTabs.clear();
                                    if (keepRestaurants) {
                                      _selectedTabs.add('restaurants');
                                    }
                                  });
                                },
                                child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.red)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tab in kNavTabs) () {
                                final isRestaurantsTab = tab.key == 'restaurants';
                                final isLocked = isRestaurantsTab && !isCallerSuperAdmin;
                                final isSelected = _selectedTabs.contains(tab.key);

                                Widget chip = FilterChip(
                                  avatar: Icon(
                                    tab.icon,
                                    size: 15,
                                    color: isSelected
                                        ? Colors.white
                                        : (isLocked ? Colors.grey : AppTheme.primary),
                                  ),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(tab.label),
                                      if (isRestaurantsTab) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          isCallerSuperAdmin ? Icons.shield_outlined : Icons.lock,
                                          size: 13,
                                          color: isSelected
                                              ? Colors.white70
                                              : (isCallerSuperAdmin ? Colors.amber.shade800 : Colors.grey),
                                        ),
                                      ],
                                    ],
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppTheme.primary,
                                  checkmarkColor: Colors.white,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isLocked ? Colors.grey.shade600 : Colors.black87),
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  onSelected: isLocked
                                      ? null
                                      : (selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedTabs.add(tab.key);
                                            } else {
                                              _selectedTabs.remove(tab.key);
                                            }
                                          });
                                        },
                                );

                                if (isLocked) {
                                  return Tooltip(
                                    message: 'Only Super Admins can grant or revoke Restaurants tab access.',
                                    child: chip,
                                  );
                                }
                                return chip;
                              }(),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? user;
  const _UserDialog({this.user});

  @override
  ConsumerState<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends ConsumerState<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _username;
  late String _email;
  late String _role;
  int? _branchId;
  String _password = '';
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _username = widget.user?['username'] ?? '';
    _email = widget.user?['email'] ?? '';
    _role = widget.user?['role'] ?? 'staff';
    _branchId = widget.user?['branch_id'] ?? ref.read(selectedBranchProvider);
    _isActive = widget.user?['is_active'] ?? true;
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final activeRestaurantId = ref.read(selectedRestaurantIdProvider);
      final data = {
        'username': _username,
        'email': _email,
        'role': _role,
        'branch_id': _branchId,
        'is_active': _isActive,
        if (activeRestaurantId != null) 'restaurant_id': activeRestaurantId,
      };

      if (_password.isNotEmpty) {
        data['password'] = _password;
      }

      try {
        if (widget.user == null) {
          if (_password.isEmpty) {
            AppNotifier.showError(context, 'Password is required for new users');
            return;
          }
          await ref.read(usersProvider.notifier).addUser(data);
        } else {
          await ref.read(usersProvider.notifier).updateUser(widget.user!['user_id'], data);
        }
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        AppNotifier.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersList = ref.watch(usersProvider).value ?? [];
    final authState = ref.watch(authStateProvider);
    final Set<String> rolesSet = {
      'restaurant_admin',
      'branch_manager',
      'cashier',
      'staff',
    };
    if (authState.isSuperAdmin) {
      rolesSet.add('super_admin');
    }
    for (final u in usersList) {
      if (u['role'] != null && u['role'].toString().isNotEmpty) {
        rolesSet.add(u['role'].toString().toLowerCase());
      }
    }
    
    // Ensure current role is always an option
    if (_role.isNotEmpty) {
      rolesSet.add(_role.toLowerCase());
    }

    String formatRole(String r) {
      return r
          .split('_')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
          .join(' ');
    }

    return AlertDialog(
      title: Text(widget.user == null ? 'Add User' : 'Edit User'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _username,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
                onSaved: (val) => _username = val!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
                onSaved: (val) => _email = val!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: widget.user == null ? 'Password' : 'New Password (leave blank to keep)'),
                obscureText: true,
                onSaved: (val) => _password = val ?? '',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role.toLowerCase(),
                decoration: const InputDecoration(labelText: 'Role'),
                items: rolesSet.map((r) {
                  return DropdownMenuItem(
                    value: r,
                    child: Text(formatRole(r)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _role = val);
                },
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final branchesAsync = ref.watch(branchListProvider);
                  final branches = branchesAsync.value ?? [];
                  return DropdownButtonFormField<int?>(
                    initialValue: (_branchId != null && branches.any((b) => b['branch_id'] == _branchId)) ? _branchId : null,
                    decoration: const InputDecoration(labelText: 'Branch'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Branches'),
                      ),
                      ...branches.map((b) {
                        return DropdownMenuItem<int?>(
                          value: b['branch_id'] as int?,
                          child: Text(b['name'] ?? 'Branch #${b['branch_id']}'),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _branchId = val),
                  );
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
