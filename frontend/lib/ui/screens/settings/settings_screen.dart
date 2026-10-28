import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/settings_provider.dart';
import '../../../core/auth_provider.dart';
import '../../../core/restaurant_provider.dart';
import '../../../core/branch_provider.dart';
import '../../../core/app_notifier.dart';
import '../../../theme/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/support_provider.dart';

enum SettingsTab {
  printer,
  receipt,
  posRules,
  profile,
  diagnostics,
}

class SettingsScreen extends ConsumerStatefulWidget {
  final String? initialTabKey;
  const SettingsScreen({super.key, this.initialTabKey});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsTab _activeTab = SettingsTab.printer;

  void _applyInitialTab() {
    if (widget.initialTabKey == 'profile') {
      _activeTab = SettingsTab.profile;
    } else if (widget.initialTabKey == 'receipt') {
      _activeTab = SettingsTab.receipt;
    } else if (widget.initialTabKey == 'pos') {
      _activeTab = SettingsTab.posRules;
    } else if (widget.initialTabKey == 'diagnostics') {
      _activeTab = SettingsTab.diagnostics;
    } else if (widget.initialTabKey == 'printer') {
      _activeTab = SettingsTab.printer;
    }
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabKey != null) {
      setState(() {
        _applyInitialTab();
      });
    }
  }

  // Printer controllers
  late TextEditingController _printerNameController;
  String? _printerTestResult;
  bool _isTestingPrinter = false;

  // Receipt controllers
  late TextEditingController _receiptHeaderController;
  late TextEditingController _receiptFooterController;
  late TextEditingController _taxRateController;
  bool _isSavingReceipt = false;

  // Change password controllers
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _isChangingPassword = false;

  // Diagnostics state
  Map<String, dynamic>? _healthResult;
  bool _isPinging = false;

  @override
  void initState() {
    super.initState();
    _applyInitialTab();
    final settings = ref.read(settingsProvider);
    _printerNameController = TextEditingController(text: settings.printerName);

    final authState = ref.read(authStateProvider);
    _receiptHeaderController = TextEditingController();
    _receiptFooterController = TextEditingController();
    _taxRateController = TextEditingController(text: (authState.taxRate * 100).toStringAsFixed(2));

    _loadRestaurantDetails();
  }

  void _loadRestaurantDetails() {
    final currentRest = ref.read(currentRestaurantProvider).value;
    if (currentRest != null) {
      _receiptHeaderController.text = currentRest['receipt_header'] ?? '';
      _receiptFooterController.text = currentRest['receipt_footer'] ?? '';
      final rate = currentRest['tax_rate'];
      if (rate != null) {
        _taxRateController.text = (double.tryParse(rate.toString()) ?? 0.05 * 100).toStringAsFixed(2);
      }
    }
  }

  Future<void> _runInitialPing() async {
    setState(() => _isPinging = true);
    final res = await ref.read(settingsProvider.notifier).pingHealth();
    if (mounted) {
      setState(() {
        _healthResult = res;
        _isPinging = false;
      });
    }
  }

  @override
  void dispose() {
    _printerNameController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    _taxRateController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final authState = ref.watch(authStateProvider);
    final activeTenant = ref.watch(activeTenantInfoProvider);
    final isSuperAdmin = authState.isSuperAdmin;
    final isRestaurantAdmin = authState.isRestaurantAdmin;
    final canEditBranding = isSuperAdmin || isRestaurantAdmin;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings & Preferences',
                      style: isMobile
                          ? Theme.of(context).textTheme.headlineMedium
                          : Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Terminal hardware, thermal receipt configuration, POS rules, and account security',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        activeTenant.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tab Selector Navigation Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabButton('Printer & Hardware', Icons.print_outlined, SettingsTab.printer),
                    _buildTabButton('Receipt & Branding', Icons.receipt_long_outlined, SettingsTab.receipt),
                    _buildTabButton('POS Rules', Icons.point_of_sale_outlined, SettingsTab.posRules),
                    _buildTabButton('My Profile', Icons.person_outline, SettingsTab.profile),
                    _buildTabButton('System Diagnostics', Icons.monitor_heart_outlined, SettingsTab.diagnostics),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Active Tab Content View
            Expanded(
              child: SingleChildScrollView(
                child: () {
                  switch (_activeTab) {
                    case SettingsTab.printer:
                      return _buildPrinterSection(isMobile);
                    case SettingsTab.receipt:
                      return _buildReceiptSection(isMobile, canEditBranding, authState);
                    case SettingsTab.posRules:
                      return _buildPosRulesSection(isMobile, canEditBranding);
                    case SettingsTab.profile:
                      return _buildProfileSection(isMobile, authState);
                    case SettingsTab.diagnostics:
                      return _buildDiagnosticsSection(isMobile, authState, activeTenant);
                  }
                }(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, IconData icon, SettingsTab tab) {
    final isSelected = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SECTION 1: PRINTER & HARDWARE
  // --------------------------------------------------------------------------
  Widget _buildPrinterSection(bool isMobile) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.print, color: Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thermal POS Printer Bridge',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Configure ESC/POS thermal receipt printers connected via USB or Windows spooler',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Printer Name Input & Quick Selectors
                const Text(
                  'Printer Queue Name',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _printerNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Retsol_POS_80, EPSON_TM_T88V, or POS_Thermal_58',
                    prefixIcon: const Icon(Icons.devices, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => notifier.updatePrinterSettings(printerName: val.trim()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text('Quick Select:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    _buildPrinterChip('Retsol_POS_80'),
                    _buildPrinterChip('EPSON_TM_T88V'),
                    _buildPrinterChip('POS_Thermal_58'),
                    _buildPrinterChip('XP-80C'),
                  ],
                ),
                const SizedBox(height: 24),

                // Paper Width Selection
                const Text(
                  'Receipt Paper Width',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => notifier.updatePrinterSettings(paperWidth: '80mm'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: settings.paperWidth == '80mm'
                                ? AppTheme.primary.withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: settings.paperWidth == '80mm' ? AppTheme.primary : Colors.grey.shade300,
                              width: settings.paperWidth == '80mm' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    settings.paperWidth == '80mm' ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: settings.paperWidth == '80mm' ? AppTheme.primary : Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('80 mm (Standard)', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text('48 columns - Dining bill with full item breakdown', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => notifier.updatePrinterSettings(paperWidth: '58mm'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: settings.paperWidth == '58mm'
                                ? AppTheme.primary.withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: settings.paperWidth == '58mm' ? AppTheme.primary : Colors.grey.shade300,
                              width: settings.paperWidth == '58mm' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    settings.paperWidth == '58mm' ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: settings.paperWidth == '58mm' ? AppTheme.primary : Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('58 mm (Compact)', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text('32 columns - Small portable slips & takeaway tickets', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Cut & Copy Toggles
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Automatic Paper Cut'),
                  subtitle: const Text('Send ESC/POS full paper cut command after printing bill'),
                  value: settings.autoCut,
                  onChanged: (val) => notifier.updatePrinterSettings(autoCut: val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Print Customer Receipt Copy'),
                  subtitle: const Text('Standard receipt handed to the guest'),
                  value: settings.printCustomerCopy,
                  onChanged: (val) => notifier.updatePrinterSettings(printCustomerCopy: val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Print Merchant Kitchen Copy'),
                  subtitle: const Text('Secondary copy for accounting or order records'),
                  value: settings.printMerchantCopy,
                  onChanged: (val) => notifier.updatePrinterSettings(printMerchantCopy: val),
                ),
                const SizedBox(height: 24),

                // Interactive Diagnostic Button
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isTestingPrinter ? null : _handleTestPrinter,
                      icon: _isTestingPrinter
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.print),
                      label: Text(_isTestingPrinter ? 'Sending Slip...' : 'Print Test Slip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _printerTestResult = null;
                        });
                        AppNotifier.showSuccess(context, 'Printer settings applied locally.');
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save Local Preferences'),
                    ),
                  ],
                ),

                // Test Output Feedback Box
                if (_printerTestResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Printer Response / Diagnostic Log:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _printerTestResult!,
                          style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrinterChip(String name) {
    return ActionChip(
      label: Text(name, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        _printerNameController.text = name;
        ref.read(settingsProvider.notifier).updatePrinterSettings(printerName: name);
      },
    );
  }

  Future<void> _handleTestPrinter() async {
    setState(() {
      _isTestingPrinter = true;
      _printerTestResult = null;
    });

    final res = await ref.read(settingsProvider.notifier).testThermalPrinter(_printerNameController.text);
    if (!mounted) return;

    setState(() {
      _isTestingPrinter = false;
      _printerTestResult = '[${res['status']?.toString().toUpperCase()}] ${res['message']}';
    });

    if (res['status'] == 'success') {
      AppNotifier.showSuccess(context, 'Test slip queued to ${_printerNameController.text}');
    } else {
      AppNotifier.showWarning(context, res['message'] ?? 'Printer test completed with notice.');
    }
  }

  // --------------------------------------------------------------------------
  // SECTION 2: RECEIPT & BRANDING
  // --------------------------------------------------------------------------
  Widget _buildReceiptSection(bool isMobile, bool canEditBranding, AuthState authState) {
    final activeTenant = ref.watch(activeTenantInfoProvider);
    final currencySymbol = authState.currencySymbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!canEditBranding) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade900),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Receipt branding and tax rate can only be edited by Restaurant Administrators and Super Admins.',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Wrap(
          spacing: 24,
          runSpacing: 24,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            // Left Form
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 520),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.purple.shade50,
                            child: const Icon(Icons.receipt_long, color: Colors.purple),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Receipt Header & Footer Content',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Customize customer notes and tax settings printed on customer receipts',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      TextFormField(
                        controller: _receiptHeaderController,
                        enabled: canEditBranding,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Receipt Header Message / Tagline',
                          hintText: 'e.g. Authentic Telangana Cuisine\nPlot 42, Hitec City Main Rd\nGSTIN: 36ABCDE1234F1Z5',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _receiptFooterController,
                        enabled: canEditBranding,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Receipt Footer Message',
                          hintText: 'e.g. Thank you for dining with us!\nFollow us on Instagram @deccanspice\nFor feedback: contact@deccanspice.com',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _taxRateController,
                        enabled: canEditBranding,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Applicable GST / Tax Rate (%)',
                          hintText: 'e.g. 5.0 for 5% GST',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 24),

                      if (canEditBranding)
                        ElevatedButton.icon(
                          onPressed: _isSavingReceipt
                              ? null
                              : () => _handleSaveReceipt(activeTenant.restaurantId ?? authState.restaurantId ?? 1),
                          icon: _isSavingReceipt
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSavingReceipt ? 'Saving...' : 'Save Receipt Configuration'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Right: Live Thermal Receipt Preview Box
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Card(
                elevation: 0,
                color: Colors.amber.shade50.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility, size: 14, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'LIVE THERMAL RECEIPT PREVIEW',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Paper receipt mockup container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              activeTenant.name.toUpperCase(),
                              style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            if (_receiptHeaderController.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _receiptHeaderController.text.trim(),
                                style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier')),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Bill #1042', style: TextStyle(fontFamily: 'Courier', fontSize: 11)),
                                Text('Table #T-04', style: TextStyle(fontFamily: 'Courier', fontSize: 11)),
                              ],
                            ),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Cashier: Staff', style: TextStyle(fontFamily: 'Courier', fontSize: 11)),
                                Text('Dine-In', style: TextStyle(fontFamily: 'Courier', fontSize: 11)),
                              ],
                            ),
                            const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier')),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('ITEM', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 11)),
                                Text('QTY  TOTAL', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                            const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier')),
                            _buildPreviewRow('Hyderabadi Biryani', '2', '$currencySymbol 680.00'),
                            _buildPreviewRow('Paneer Butter Masala', '1', '$currencySymbol 240.00'),
                            _buildPreviewRow('Butter Naan', '4', '$currencySymbol 160.00'),
                            const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier')),
                            _buildPreviewRow('Subtotal:', '', '$currencySymbol 1,080.00'),
                            _buildPreviewRow('GST (${_taxRateController.text}%):', '', '$currencySymbol 54.00'),
                            const Text('================================', style: TextStyle(fontFamily: 'Courier')),
                            _buildPreviewRow('TOTAL AMOUNT:', '', '$currencySymbol 1,134.00', bold: true),
                            const Text('================================', style: TextStyle(fontFamily: 'Courier')),
                            const SizedBox(height: 6),
                            if (_receiptFooterController.text.trim().isNotEmpty) ...[
                              Text(
                                _receiptFooterController.text.trim(),
                                style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                            ],
                            const Text('*** PAID VIA UPI ***', style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('- - - - CUT HERE - - - -', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewRow(String left, String middle, String right, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (middle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                middle,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
              ),
            ),
          Text(
            right,
            style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveReceipt(int restaurantId) async {
    setState(() => _isSavingReceipt = true);
    try {
      final taxDouble = (double.tryParse(_taxRateController.text) ?? 5.0) / 100.0;
      await ref.read(settingsProvider.notifier).saveReceiptConfig(
            restaurantId: restaurantId,
            receiptHeader: _receiptHeaderController.text.trim(),
            receiptFooter: _receiptFooterController.text.trim(),
            taxRate: taxDouble,
          );
      if (mounted) {
        setState(() => _isSavingReceipt = false);
        AppNotifier.showSuccess(context, 'Receipt branding configuration saved successfully.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingReceipt = false);
        AppNotifier.showError(context, e.toString());
      }
    }
  }

  // --------------------------------------------------------------------------
  // SECTION 3: POS WORKFLOW RULES
  // --------------------------------------------------------------------------
  Widget _buildPosRulesSection(bool isMobile, bool canEditBranding) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: const Icon(Icons.point_of_sale, color: Colors.teal),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Point of Sale Workflow Rules',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Customize cashier settlement behavior, table turnover, and order routing',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-Print Receipt Upon Settlement'),
                  subtitle: const Text('Immediately trigger thermal receipt print after successful payment in POS'),
                  value: settings.autoPrintOnSettle,
                  onChanged: (val) => notifier.updatePosWorkflow(autoPrintOnSettle: val),
                ),
                const Divider(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-Release Table on Bill Settlement'),
                  subtitle: const Text('Instantly switch table status back to "Available" when bill payment is finalized'),
                  value: settings.autoReleaseTable,
                  onChanged: (val) => notifier.updatePosWorkflow(autoReleaseTable: val),
                ),
                const Divider(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require Customer Phone on Takeaway Orders'),
                  subtitle: const Text('Prevents billing takeaway orders without a customer contact number for notifications'),
                  value: settings.requirePhoneForTakeaway,
                  onChanged: (val) => notifier.updatePosWorkflow(requirePhoneForTakeaway: val),
                ),
                const Divider(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Generate Kitchen Order Tickets (KOT)'),
                  subtitle: const Text('Send new order dispatches to the kitchen display / thermal ticket printer'),
                  value: settings.enableKitchenTickets,
                  onChanged: (val) => notifier.updatePosWorkflow(enableKitchenTickets: val),
                ),
                const Divider(),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Default Payment Method'),
                  subtitle: const Text('Pre-selects preferred mode on POS checkout dialog'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: settings.defaultPaymentMethod,
                        items: const [
                          DropdownMenuItem(value: 'UPI', child: Text('UPI / QR Code')),
                          DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                          DropdownMenuItem(value: 'CARD', child: Text('Credit / Debit Card')),
                        ],
                        onChanged: (val) {
                          if (val != null) notifier.updatePosWorkflow(defaultPaymentMethod: val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // SECTION 4: MY PROFILE & SECURITY
  // --------------------------------------------------------------------------
  Widget _buildProfileSection(bool isMobile, AuthState authState) {
    final user = authState.user ?? {};
    final username = user['username'] ?? 'User';
    final email = user['email'] ?? 'No email';
    final role = authState.role ?? 'STAFF';
    final restName = authState.restaurantName;
    final branchId = authState.branchId;

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        // Operator Profile Details Card
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 480),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, size: 32, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: authState.isSuperAdmin
                                    ? Colors.amber.shade100
                                    : AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: authState.isSuperAdmin ? Colors.amber.shade900 : AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  _buildProfileRow('Organization Context', restName),
                  _buildProfileRow('Branch Assignment', branchId != null ? 'Branch #$branchId' : 'All Branches (Multi-Branch Scope)'),
                  _buildProfileRow('Access Tier', authState.accessLevel == 'FULL' ? 'Full Access' : 'Partial Permissions'),
                  _buildProfileRow('Session Status', 'Authenticated (JWT Active)'),
                  const SizedBox(height: 20),

                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(selectedRestaurantIdProvider.notifier).state = null;
                      ref.read(selectedBranchProvider.notifier).state = null;
                      ref.invalidate(supportTicketsProvider);
                      ref.read(authStateProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                    label: const Text('Sign Out of Terminal', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Change Password Card
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 480),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.shade50,
                          child: const Icon(Icons.lock_outline, color: Colors.orange),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Password',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Update your local account security password',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureCurrent ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'New password is required';
                        if (v.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureNew,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v != _newPasswordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _isChangingPassword ? null : _handleChangePassword,
                      icon: _isChangingPassword
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.key),
                      label: Text(_isChangingPassword ? 'Updating...' : 'Update Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
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

  Widget _buildProfileRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isChangingPassword = true);
    try {
      await ref.read(settingsProvider.notifier).changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
        AppNotifier.showSuccess(context, 'Password updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChangingPassword = false);
        AppNotifier.showError(context, e.toString());
      }
    }
  }

  // --------------------------------------------------------------------------
  // SECTION 5: SYSTEM DIAGNOSTICS & TENANT STATUS
  // --------------------------------------------------------------------------
  Widget _buildDiagnosticsSection(bool isMobile, AuthState authState, ActiveTenantInfo activeTenant) {
    final status = _healthResult?['status'] ?? 'pending';
    final latency = _healthResult?['latencyMs'] ?? 0;
    final isHealthy = status == 'healthy';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isHealthy ? Colors.green.shade50 : Colors.red.shade50,
                      child: Icon(
                        isHealthy ? Icons.check_circle : Icons.error_outline,
                        color: isHealthy ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'System Health & Connectivity Status',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Real-time connectivity diagnostics, latency telemetry, and database isolation checks',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),

                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildDiagnosticCard('API Backend', isHealthy ? 'Connected (Online)' : 'Offline / Error', Icons.cloud_done, isHealthy ? Colors.green : Colors.red),
                    _buildDiagnosticCard('Round-Trip Latency', '$latency ms', Icons.speed, Colors.blue),
                    _buildDiagnosticCard('Active Database', 'SQLite local.db', Icons.storage, Colors.indigo),
                    _buildDiagnosticCard('SaaS Multi-Tenant Mode', 'Active Isolation', Icons.shield, Colors.teal),
                    _buildDiagnosticCard('Active Tenant Context', '${activeTenant.name} (#${activeTenant.restaurantId ?? 'All'})', Icons.business, Colors.deepPurple),
                    _buildDiagnosticCard('Software Version', 'IOR 360 Enterprise v2.4', Icons.info_outline, Colors.grey.shade700),
                  ],
                ),
                const SizedBox(height: 24),

                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isPinging ? null : _runInitialPing,
                      icon: _isPinging
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh),
                      label: Text(_isPinging ? 'Pinging API...' : 'Ping Backend API'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(restaurantListProvider);
                        ref.invalidate(branchListProvider);
                        AppNotifier.showSuccess(context, 'Local cached lists refreshed.');
                      },
                      icon: const Icon(Icons.cleaning_services),
                      label: const Text('Flush Local Cache'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
