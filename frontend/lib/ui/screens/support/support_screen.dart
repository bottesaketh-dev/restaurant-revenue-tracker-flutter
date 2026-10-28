import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/support_provider.dart';
import '../../../core/settings_provider.dart';
import '../../../core/auth_provider.dart';
import '../../../core/restaurant_provider.dart';
import '../../../core/branch_provider.dart';
import '../../../core/app_notifier.dart';
import '../../../theme/app_theme.dart';
import '../../../core/responsive.dart';

enum SupportSubTab {
  tickets,
  diagnostics,
  faqs,
  shortcuts,
}

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  SupportSubTab _activeTab = SupportSubTab.tickets;

  // Ticket Form Controllers
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = 'POS & Billing';
  String _selectedPriority = 'MEDIUM';
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _remoteDeskController = TextEditingController();
  bool _isSubmittingTicket = false;
  bool _includeDiagnostics = true;

  // FAQ Search
  final _faqSearchController = TextEditingController();
  String _faqSearchQuery = '';

  // Diagnostics Live State
  Map<String, dynamic>? _pingResult;
  bool _isPinging = false;

  final List<String> _categories = [
    'POS & Billing',
    'Thermal Printer & Spooler',
    'Kitchen & KOT',
    'User Roles & Permissions',
    'Financial Reports & EOD',
    'System & Hardware',
    'Other / Feature Request',
  ];

  final List<Map<String, String>> _staticFaqs = [
    {
      'category': 'Thermal Printer & Spooler',
      'question': 'Printer shows "Device Not Found" or fails to print receipts.',
      'answer': '1. Check Settings > Printer and verify the printer name matches Windows Control Panel exactly (e.g., "Retsol_POS_80" or "POS-80").\n2. Open Windows Services (services.msc) and restart the "Print Spooler" service.\n3. Verify USB / LAN cable and ensure the thermal paper roll is loaded thermal-side facing the print head.\n4. Click "Test Print" in Settings > Printer to send an ESC/POS diagnostic ticket.'
    },
    {
      'category': 'Thermal Printer & Spooler',
      'question': 'How to switch paper roll width between 80mm and 58mm?',
      'answer': 'Navigate to Settings > Printer & Hardware. Select 58mm (approx 32 chars/line) or 80mm (approx 48 chars/line). The preview and printing commands format automatically.'
    },
    {
      'category': 'Thermal Printer & Spooler',
      'question': 'How to customize receipt header and footer messages?',
      'answer': 'Open Settings > Receipt & Branding. Enter your restaurant\'s GSTIN, FSSAI license, branch address in the Header, and custom greeting or return policy in the Footer.'
    },
    {
      'category': 'POS Billing & Cash Desk',
      'question': 'How do I split payment between Cash and UPI?',
      'answer': 'On the POS Billing screen checkout modal, choose "Split Payment". Enter the Cash portion and UPI portion. Once the sum matches the order total, click "Complete Payment".'
    },
    {
      'category': 'POS Billing & Cash Desk',
      'question': 'How to cancel or clear an active order?',
      'answer': 'Before billing, press the "Clear Cart" button or press "Esc" to clear the order items. For settled bills, an authorized Manager can void the transaction from Reports > Bills.'
    },
    {
      'category': 'Kitchen & KOT Workflow',
      'question': 'How do kitchen staff receive and track orders?',
      'answer': 'When an order is submitted at the counter or tables, it instantly streams to the Kitchen tab. Chefs can advance ticket status from "Pending" to "Cooking" and "Ready".'
    },
    {
      'category': 'Kitchen & KOT Workflow',
      'question': 'Why is an ingredient not auto-deducting from inventory?',
      'answer': 'Make sure the recipe has ingredients linked in Kitchen > Recipe Ingredients. If ingredients are not linked or units are missing, inventory will not decrement upon order settlement.'
    },
    {
      'category': 'User Access & Multi-Tenant',
      'question': 'How to grant or restrict tab access for cashier and staff?',
      'answer': 'Super Admins or Restaurant Admins can open the Users tab, select the staff account, and check or uncheck individual tab permissions (POS, Kitchen, Reports, Groceries).'
    },
    {
      'category': 'User Access & Multi-Tenant',
      'question': 'How do I change my account password?',
      'answer': 'Click your Profile symbol at the top right of any page to open Settings > My Profile. Fill in your current password, new password, and click "Update Password".'
    },
  ];

  final List<Map<String, String>> _shortcuts = [
    {'key': 'F1', 'action': 'Focus Menu Item Search', 'scope': 'POS Billing'},
    {'key': 'F2', 'action': 'Toggle Dine-In / Takeaway', 'scope': 'POS Billing'},
    {'key': 'F4', 'action': 'Quick Cash Settlement', 'scope': 'Checkout'},
    {'key': 'F8', 'action': 'Quick UPI / QR Settlement', 'scope': 'Checkout'},
    {'key': 'Ctrl + P', 'action': 'Reprint Last Customer Bill', 'scope': 'POS Billing'},
    {'key': 'Ctrl + Enter', 'action': 'Submit Order & Print KOT', 'scope': 'Order Cart'},
    {'key': 'Esc', 'action': 'Clear Search / Close Active Dialog', 'scope': 'Global'},
    {'key': 'Alt + N', 'action': 'Start New Order (Clear Current)', 'scope': 'POS Billing'},
    {'key': 'Alt + T', 'action': 'Quick Table Selection Dialog', 'scope': 'Dine-In'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(supportTicketsProvider.notifier).fetchTickets();
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _remoteDeskController.dispose();
    _faqSearchController.dispose();
    super.dispose();
  }

  Future<void> _runPing() async {
    setState(() => _isPinging = true);
    final res = await ref.read(settingsProvider.notifier).pingHealth();
    if (mounted) {
      setState(() {
        _pingResult = res;
        _isPinging = false;
      });
    }
  }

  Future<void> _launchHelpline(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) AppNotifier.showSuccess(context, 'Helpline number $phone copied to clipboard');
    }
  }

  Future<void> _launchWhatsApp(String phone, String restName) async {
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    final msg = Uri.encodeComponent('Hello IOR 360 Support Desk,\nI need urgent assistance for my restaurant "$restName".');
    final uri = Uri.parse('https://wa.me/$clean?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) AppNotifier.showSuccess(context, 'WhatsApp number $phone copied to clipboard');
    }
  }

  String _generateDiagnosticsPayload() {
    final auth = ref.read(authStateProvider);
    final tenant = ref.read(activeTenantInfoProvider);
    final branch = ref.read(selectedBranchProvider);
    final settings = ref.read(settingsProvider);

    return '''
========================================
IOR 360 DIAGNOSTICS DUMP
Generated: ${DateTime.now().toIso8601String()}
========================================
[ORGANIZATION & TENANCY]
Restaurant Name: ${tenant.name}
Restaurant ID: ${tenant.restaurantId ?? 'Global (All)'}
Currency: ${tenant.currencySymbol} (${tenant.currencyCode})
Selected Branch ID: ${branch ?? 'All Branches'}

[USER CONTEXT]
Logged In User: ${auth.user?['username'] ?? 'Unknown'}
Email: ${auth.user?['email'] ?? 'Unknown'}
Role: ${auth.role ?? 'USER'}
Access Level: ${auth.accessLevel}

[HARDWARE & POS RULES]
Configured Printer: ${settings.printerName}
Paper Width: ${settings.paperWidth}
Auto Cut: ${settings.autoCut}
Auto Print on Settle: ${settings.autoPrintOnSettle}
Default Payment: ${settings.defaultPaymentMethod}

[BACKEND & CONNECTIVITY]
Ping Status: ${_pingResult?['status'] ?? 'Unknown'}
Backend Message: ${_pingResult?['message'] ?? 'Pending ping'}
App Version: IOR 360 v2.4.0 (Build 2026.10)
========================================
''';
  }

  Future<void> _copyDiagnostics() async {
    final dump = _generateDiagnosticsPayload();
    await Clipboard.setData(ClipboardData(text: dump));
    if (mounted) {
      AppNotifier.showSuccess(context, 'Full System Diagnostics copied to clipboard! Paste in chat or ticket.');
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmittingTicket = true);

    try {
      final diag = _includeDiagnostics ? _generateDiagnosticsPayload() : null;
      final created = await ref.read(supportTicketsProvider.notifier).createTicket(
            category: _selectedCategory,
            priority: _selectedPriority,
            subject: _subjectController.text.trim(),
            description: _descriptionController.text.trim(),
            contactPhone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
            metadataJson: diag,
          );

      if (mounted) {
        _subjectController.clear();
        _descriptionController.clear();
        AppNotifier.showSuccess(
          context,
          'Ticket ${created?.ticketNumber ?? ''} created successfully! Our operations desk is reviewing.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'Failed to create ticket: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmittingTicket = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final supportInfoAsync = ref.watch(supportInfoProvider);
    final tenant = ref.watch(activeTenantInfoProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Bar
            _buildHeader(context, supportInfoAsync, tenant.name),
            const SizedBox(height: 20),

            // Emergency Action Cards
            _buildEmergencyCards(context, supportInfoAsync, tenant.name),
            const SizedBox(height: 24),

            // Navigation Tabs
            _buildSubTabs(),
            const SizedBox(height: 20),

            // Active Tab View Content
            _buildActiveTabContent(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<SupportDeskInfo> infoAsync, String restName) {
    final info = infoAsync.value ?? const SupportDeskInfo();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primary.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent, color: AppTheme.secondaryContainer, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    const Text(
                      'IOR 360 Support & Emergency Desk',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                          const SizedBox(width: 6),
                          Text(
                            info.serviceStatus.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Priority assistance for active billing, thermal printer hardware, kitchen KOT, and cashier operations for $restName.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCards(BuildContext context, AsyncValue<SupportDeskInfo> infoAsync, String restName) {
    final info = infoAsync.value ?? const SupportDeskInfo();
    final isDesktop = Responsive.isDesktop(context);

    final cards = [
      // 1. Phone Helpline
      _buildActionCard(
        icon: Icons.phone_in_talk,
        iconBg: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
        title: 'Emergency Operations Hotline',
        subtitle: info.helpline,
        badge: 'Priority Rush Hours',
        badgeColor: Colors.blue.shade100,
        badgeTextColor: Colors.blue.shade800,
        buttonText: 'Call Helpline',
        buttonColor: Colors.blue.shade700,
        onTap: () => _launchHelpline(info.helpline),
      ),
      // 2. WhatsApp Dispatch
      _buildActionCard(
        icon: Icons.chat_bubble,
        iconBg: Colors.green.shade50,
        iconColor: Colors.green.shade700,
        title: 'WhatsApp Tech Dispatch',
        subtitle: info.whatsapp,
        badge: 'Avg Reply < 2m',
        badgeColor: Colors.green.shade100,
        badgeTextColor: Colors.green.shade800,
        buttonText: 'Chat on WhatsApp',
        buttonColor: Colors.green.shade700,
        onTap: () => _launchWhatsApp(info.whatsapp, restName),
      ),
      // 3. Remote Technician Session
      _buildRemoteDeskCard(context),
    ];

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6.0), child: c))).toList(),
      );
    } else {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12.0), child: c)).toList(),
      );
    }
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  badge,
                  style: TextStyle(color: badgeTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.touch_app, size: 16),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRemoteDeskCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.screen_share, color: Colors.purple.shade700, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'AnyDesk / Remote',
                  style: TextStyle(color: Colors.purple.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Remote Desk Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text('Technician live screen share', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _remoteDeskController,
                  decoration: InputDecoration(
                    hintText: 'Enter 9-digit code',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () {
                  final code = _remoteDeskController.text.trim();
                  if (code.isEmpty) {
                    AppNotifier.showWarning(context, 'Please enter your remote desktop ID');
                    return;
                  }
                  AppNotifier.showSuccess(context, 'Connect request sent for session #$code. Technician connecting.');
                  _remoteDeskController.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Connect', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildTabPill('Raise & Track Tickets', Icons.confirmation_number_outlined, SupportSubTab.tickets),
          _buildTabPill('System Diagnostics', Icons.fact_check_outlined, SupportSubTab.diagnostics),
          _buildTabPill('Operations FAQs', Icons.menu_book_outlined, SupportSubTab.faqs),
          _buildTabPill('POS Shortcuts', Icons.keyboard_outlined, SupportSubTab.shortcuts),
        ],
      ),
    );
  }

  Widget _buildTabPill(String title, IconData icon, SupportSubTab tab) {
    final isSelected = _activeTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppTheme.primary,
        ),
        label: Text(title),
        selected: isSelected,
        onSelected: (_) => setState(() => _activeTab = tab),
        selectedColor: AppTheme.primary,
        backgroundColor: Colors.transparent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(bool isDesktop) {
    switch (_activeTab) {
      case SupportSubTab.tickets:
        return _buildTicketsTab(isDesktop);
      case SupportSubTab.diagnostics:
        return _buildDiagnosticsTab();
      case SupportSubTab.faqs:
        return _buildFaqsTab();
      case SupportSubTab.shortcuts:
        return _buildShortcutsTab();
    }
  }

  // --- TAB 1: TICKETS ---
  Widget _buildTicketsTab(bool isDesktop) {
    final ticketsAsync = ref.watch(supportTicketsProvider);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: New Ticket Form
          Expanded(
            flex: 5,
            child: _buildNewTicketForm(),
          ),
          const SizedBox(width: 24),
          // Right: Tickets List
          Expanded(
            flex: 6,
            child: _buildTicketsList(ticketsAsync),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildNewTicketForm(),
          const SizedBox(height: 24),
          _buildTicketsList(ticketsAsync),
        ],
      );
    }
  }

  Widget _buildNewTicketForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Submit Support Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Detail your issue below. Our restaurant support engineers will review and initiate callbacks for critical tickets.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const Divider(height: 24),

            // Category Dropdown
            const Text('Issue Category *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),

            // Priority Chips
            const Text('Priority Level *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map((p) {
                final isSelected = _selectedPriority == p;
                Color chipColor = Colors.grey.shade200;
                Color selectedColor = Colors.blue.shade700;
                if (p == 'CRITICAL') selectedColor = Colors.red.shade700;
                if (p == 'HIGH') selectedColor = Colors.orange.shade800;
                if (p == 'LOW') selectedColor = Colors.green.shade700;

                return ChoiceChip(
                  label: Text(p, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: selectedColor,
                  backgroundColor: chipColor,
                  onSelected: (_) => setState(() => _selectedPriority = p),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Subject
            const Text('Ticket Subject *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                hintText: 'e.g., Thermal printer not cutting receipt after billing',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a subject' : null,
            ),
            const SizedBox(height: 16),

            // Description
            const Text('Detailed Description *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe what happened, error messages, table/bill number, or steps to reproduce...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide details' : null,
            ),
            const SizedBox(height: 16),

            // Callback Phone
            const Text('Callback Phone (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '+91 98765 43210',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),

            // Attach Diagnostics Checkbox
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _includeDiagnostics,
                onChanged: (v) => setState(() => _includeDiagnostics = v ?? true),
                title: const Text('Attach system & printer diagnostics snapshot', style: TextStyle(fontSize: 12)),
                subtitle: const Text('Includes restaurant ID, active branch, and printer name for fast resolution', style: TextStyle(fontSize: 11)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingTicket ? null : _submitTicket,
                icon: _isSubmittingTicket
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_isSubmittingTicket ? 'Submitting...' : 'Submit Support Ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsList(AsyncValue<List<SupportTicketItem>> ticketsAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('My Operations Tickets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Tickets',
                onPressed: () => ref.read(supportTicketsProvider.notifier).fetchTickets(),
              ),
            ],
          ),
          const Divider(height: 20),
          ticketsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 36),
                  const SizedBox(height: 8),
                  Text('Unable to fetch tickets: $err', style: const TextStyle(fontSize: 12, color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.read(supportTicketsProvider.notifier).fetchTickets(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (tickets) {
              if (tickets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No support tickets currently open.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Fill out the form on the left if you need assistance.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tickets.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final t = tickets[index];
                  Color statusColor = Colors.amber.shade800;
                  if (t.status == 'RESOLVED') statusColor = Colors.green.shade700;
                  if (t.status == 'IN_PROGRESS') statusColor = Colors.blue.shade700;

                  Color priorityColor = Colors.grey.shade700;
                  if (t.priority == 'CRITICAL') priorityColor = Colors.red.shade700;
                  if (t.priority == 'HIGH') priorityColor = Colors.orange.shade800;

                  return Material(
                    color: Colors.transparent,
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.confirmation_number, color: priorityColor, size: 20),
                      ),
                      title: Row(
                        children: [
                          Text(
                            t.ticketNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              t.status,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${t.category} • ${t.subject}',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Description:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
                              const SizedBox(height: 4),
                              Text(t.description, style: const TextStyle(fontSize: 12)),
                              if (t.contactPhone != null) ...[
                                const SizedBox(height: 8),
                                Text('Callback: ${t.contactPhone}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                              ],
                              if (t.resolutionNotes != null && t.resolutionNotes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Resolution Notes: ${t.resolutionNotes}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --- TAB 2: SYSTEM DIAGNOSTICS SNAPSHOT ---
  Widget _buildDiagnosticsTab() {
    final auth = ref.watch(authStateProvider);
    final tenant = ref.watch(activeTenantInfoProvider);
    final branch = ref.watch(selectedBranchProvider);
    final settings = ref.watch(settingsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monitor_heart, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Real-Time Operations Diagnostics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _copyDiagnostics,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Diagnostics for Support'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Use this snapshot when speaking with technical support engineers to identify configuration and network issues.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const Divider(height: 24),

          // Cards Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildDiagMetric('Organization', tenant.name, 'ID: #${tenant.restaurantId ?? "Global"}', Icons.storefront),
              _buildDiagMetric('Selected Branch', branch != null ? 'Branch #$branch' : 'All Branches View', 'Branch ID: #${branch ?? "All"}', Icons.location_on_outlined),
              _buildDiagMetric('Logged-In User', auth.user?['username'] ?? 'User', 'Role: ${auth.role ?? "STAFF"}', Icons.account_circle_outlined),
              _buildDiagMetric('Thermal Printer', settings.printerName, 'Width: ${settings.paperWidth} • Cut: ${settings.autoCut ? "Yes" : "No"}', Icons.print_outlined),
              _buildDiagMetric(
                'Backend API Connectivity',
                _pingResult != null ? '${_pingResult!['latency_ms'] ?? 0} ms • ${_pingResult!['status']}' : 'Not tested yet',
                _isPinging ? 'Pinging backend...' : 'Click to run ping test',
                Icons.wifi_tethering,
                action: TextButton(
                  onPressed: _isPinging ? null : _runPing,
                  child: const Text('Ping Now'),
                ),
              ),
              _buildDiagMetric('Software Version', 'IOR 360 v2.4.0', 'Release Build (FastAPI + SQLite/Supabase)', Icons.verified_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagMetric(String label, String value, String detail, IconData icon, {Widget? action}) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                if (action != null) ...[
                  const SizedBox(height: 4),
                  action,
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- TAB 3: FAQS ---
  Widget _buildFaqsTab() {
    final filteredFaqs = _staticFaqs.where((f) {
      if (_faqSearchQuery.isEmpty) return true;
      final q = _faqSearchQuery.toLowerCase();
      return f['question']!.toLowerCase().contains(q) ||
          f['answer']!.toLowerCase().contains(q) ||
          f['category']!.toLowerCase().contains(q);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.quiz_outlined, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Restaurant Operations Knowledge Base', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Step-by-step guides for common cashier, printer, and kitchen operational scenarios.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _faqSearchController,
            decoration: InputDecoration(
              hintText: 'Search FAQ (e.g., printer, split payment, KOT, password)...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _faqSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _faqSearchController.clear();
                          _faqSearchQuery = '';
                        });
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() => _faqSearchQuery = val),
          ),
          const Divider(height: 24),

          if (filteredFaqs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No articles match your search. Contact helpline above for support.'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredFaqs.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final faq = filteredFaqs[index];
                return Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help_outline, color: AppTheme.primary, size: 20),
                    title: Text(
                      faq['question']!,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(faq['category']!, style: const TextStyle(fontSize: 11, color: AppTheme.secondary)),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          faq['answer']!,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- TAB 4: KEYBOARD SHORTCUTS ---
  Widget _buildShortcutsTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.keyboard, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('POS Cashier Keyboard Shortcuts Cheat Sheet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep these high-speed keyboard shortcuts handy at your counter desk during dinner rush hours.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const Divider(height: 24),

          Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1, borderRadius: BorderRadius.circular(8)),
            columnWidths: const {
              0: FixedColumnWidth(160),
              1: FlexColumnWidth(),
              2: FixedColumnWidth(140),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Shortcut Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Action / Workflow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Active Screen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              ..._shortcuts.map(
                (s) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          s['key']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(s['action']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(s['scope']!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
