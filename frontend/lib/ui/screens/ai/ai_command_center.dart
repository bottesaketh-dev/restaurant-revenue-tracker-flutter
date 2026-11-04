import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/chat_provider.dart';
import '../../../core/branch_provider.dart';
import '../../../core/app_notifier.dart';
import '../../../core/responsive.dart';
import '../../../theme/app_theme.dart';
import 'widgets/chat_inline_chart.dart';

class AiCommandCenterScreen extends ConsumerStatefulWidget {
  const AiCommandCenterScreen({super.key});

  @override
  ConsumerState<AiCommandCenterScreen> createState() => _AiCommandCenterScreenState();
}

class _AiCommandCenterScreenState extends ConsumerState<AiCommandCenterScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int? _lastBranchId;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _promptController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _checkBranchSwitch(int? currentBranchId, List<dynamic> branches) {
    if (_lastBranchId == null) {
      _lastBranchId = currentBranchId;
      return;
    }

    if (currentBranchId != null && currentBranchId != _lastBranchId) {
      _lastBranchId = currentBranchId;
      final matches = branches.where((b) => b['branch_id'] == currentBranchId);
      final branch = matches.isNotEmpty ? matches.first : null;
      final branchName = branch != null ? branch['name']?.toString() : 'Branch #$currentBranchId';
      if (branchName != null) {
        ref.read(chatProvider.notifier).recordBranchSwitch(currentBranchId, branchName);
        _scrollToBottom();
      }
    }
  }

  void _submitPrompt([String? text]) {
    final query = text ?? _promptController.text;
    if (query.trim().isEmpty) return;

    _promptController.clear();
    ref.read(chatProvider.notifier).sendMessage(query);
    _scrollToBottom();
  }

  void _showRenameDialog(BuildContext context, ChatConversationModel conv) {
    final renameController = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: renameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Conversation Title',
            hintText: 'e.g. Q3 Biryani Sales Audit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = renameController.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(chatProvider.notifier).renameConversation(conv.id, newTitle);
                Navigator.pop(dialogCtx);
                AppNotifier.showSuccess(context, 'Conversation renamed.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDialog(BuildContext context, ChatConversationModel conv) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Conversation?'),
        content: Text('Are you sure you want to delete "${conv.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(chatProvider.notifier).deleteConversation(conv.id);
              Navigator.pop(dialogCtx);
              AppNotifier.showSuccess(context, 'Conversation deleted.');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final branches = ref.watch(branchListProvider).value ?? [];
    final currentBranchId = ref.watch(selectedBranchProvider);
    final isMobile = Responsive.isMobile(context);

    // Watch for branch switches
    _checkBranchSwitch(currentBranchId, branches);

    // Resolve branch name for active indicator
    String activeBranchName = 'All Branches (Enterprise)';
    if (currentBranchId != null) {
      final matches = branches.where((b) => b['branch_id'] == currentBranchId);
      if (matches.isNotEmpty && matches.first['name'] != null) {
        activeBranchName = matches.first['name'].toString();
      } else {
        activeBranchName = 'Branch #$currentBranchId';
      }
    }

    // Auto-scroll when new messages arrive or when streaming
    if (chatState.isStreaming || chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    final sidebarContent = _buildSidebar(context, chatState, isMobile);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: isMobile ? Drawer(child: SafeArea(child: sidebarContent)) : null,
      body: Row(
        children: [
          // Desktop Conversation History Sidebar
          if (!isMobile)
            SizedBox(
              width: 300,
              child: sidebarContent,
            ),

          if (!isMobile)
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),

          // Main Chat Area
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                _buildHeader(context, isMobile, activeBranchName),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

                // Messages Timeline
                Expanded(
                  child: chatState.messages.isEmpty
                      ? _buildEmptyState(context, isMobile)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 32,
                            vertical: 24,
                          ),
                          itemCount: chatState.messages.length,
                          itemBuilder: (context, index) {
                            final msg = chatState.messages[index];
                            if (msg.role == 'user') {
                              return _buildUserMessage(context, msg, isMobile);
                            } else if (msg.role == 'system') {
                              return _buildSystemEventMessage(context, msg);
                            } else {
                              return _buildAssistantMessage(context, msg, isMobile);
                            }
                          },
                        ),
                ),

                // Fixed Bottom Composer
                _buildComposer(context, chatState, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Header Bar
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, bool isMobile, String activeBranchName) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 14,
      ),
      color: Colors.white,
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: AppTheme.onBackground),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Chat History',
            ),
          const Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 24),
          const SizedBox(width: 12),
          Text(
            'AI Command Center',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 20,
                ),
          ),
          const Spacer(),

          // Active Branch Focus Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? 120 : 220),
                  child: Text(
                    activeBranchName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Conversation History Sidebar
  // ---------------------------------------------------------------------------
  Widget _buildSidebar(BuildContext context, ChatState chatState, bool isMobile) {
    var convs = chatState.conversations;
    if (_searchFilter.trim().isNotEmpty) {
      convs = convs.where((c) => c.title.toLowerCase().contains(_searchFilter.toLowerCase())).toList();
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Sidebar Header & New Chat Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(chatProvider.notifier).startNewChat();
                      if (isMobile) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'New Chat',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Search Filter
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchFilter = val),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

          // Conversations List
          Expanded(
            child: chatState.isLoadingConversations
                ? const Center(child: CircularProgressIndicator())
                : convs.isEmpty
                    ? Center(
                        child: Text(
                          _searchFilter.isNotEmpty ? 'No matching chats' : 'No previous chats',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        itemCount: convs.length,
                        itemBuilder: (context, index) {
                          final conv = convs[index];
                          final isSelected = conv.id == chatState.activeConversationId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.transparent,
                              clipBehavior: Clip.antiAlias,
                              shape: isSelected
                                  ? RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                                    )
                                  : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              leading: Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                                color: isSelected ? AppTheme.primary : Colors.grey.shade600,
                              ),
                              title: Text(
                                conv.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? AppTheme.primary : const Color(0xFF1F2937),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatRelativeTime(conv.lastMessageAt ?? conv.createdAt),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                                tooltip: 'Conversation Actions',
                                onSelected: (val) {
                                  if (val == 'rename') {
                                    _showRenameDialog(context, conv);
                                  } else if (val == 'delete') {
                                    _confirmDeleteDialog(context, conv);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 16),
                                        SizedBox(width: 8),
                                        Text('Rename'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                ref.read(chatProvider.notifier).selectConversation(conv.id);
                                if (isMobile) Navigator.pop(context);
                              },
                            ),
                          ),
                        );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State with Intelligent Restaurant Suggestions
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(BuildContext context, bool isMobile) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              'IOR 360 Conversational Analyst',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 20 : 24,
                  ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(
                'Ask questions in natural language to analyze branch revenue, gross margins, payroll costs, and best-selling dishes with native charts.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildPromptChip('Show top 5 best-selling dishes'),
                _buildPromptChip('Plot sales vs expenses for last 30 days'),
                _buildPromptChip('What was today\'s total revenue?'),
                _buildPromptChip('Compare branch revenue and margins'),
                _buildPromptChip('Analyze grocery costs and wholesale suppliers'),
                _buildPromptChip('Show peak hourly ordering volumes'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String prompt) {
    return ActionChip(
      avatar: const Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.primary),
      label: Text(prompt, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      onPressed: () => _submitPrompt(prompt),
    );
  }

  // ---------------------------------------------------------------------------
  // Message Timeline Items
  // ---------------------------------------------------------------------------

  // 1. User Message
  Widget _buildUserMessage(BuildContext context, ChatMessageModel msg, bool isMobile) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: 20, left: isMobile ? 24 : 80),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(16).copyWith(topRight: Radius.zero),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          msg.content,
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  // 2. System Event (Branch Switch)
  Widget _buildSystemEventMessage(BuildContext context, ChatMessageModel msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7), // Warm amber tint
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.alt_route, size: 16, color: Color(0xFF92400E)),
              const SizedBox(width: 8),
              Text(
                msg.content,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Assistant Message with In-Timeline Thinking & Native Charts
  Widget _buildAssistantMessage(BuildContext context, ChatMessageModel msg, bool isMobile) {
    final isThinking = msg.status == 'thinking' || msg.status == 'pending';
    final hasFailed = msg.status == 'failed';
    final isCancelled = msg.status == 'cancelled';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 24, right: isMobile ? 16 : 64),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(topLeft: Radius.zero),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  'IOR 360 AI Analyst',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // In-Timeline Thinking & Execution Plan
            if (isThinking) ...[
              _buildThinkingBox(context, msg),
              const SizedBox(height: 14),
            ] else if (msg.steps.isNotEmpty) ...[
              // Collapsible Execution Summary
              _buildCollapsiblePlanSummary(context, msg),
              const SizedBox(height: 14),
            ],

            // Content Text (Markdown)
            if (msg.content.isNotEmpty)
              MarkdownBody(
                data: sanitizeSqlFromText(msg.content),
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF1F2937)),
                  h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  code: TextStyle(backgroundColor: Colors.grey.shade100, fontSize: 13),
                  tableHead: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tableBody: const TextStyle(fontSize: 13),
                ),
              ),

            // Native Inline Charts (Rendered directly in message timeline)
            if (msg.charts.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (var chart in msg.charts)
                ChatInlineChart(
                  chartSpec: chart,
                  rawData: msg.rawData,
                ),
            ],

            // Error Badge
            if (hasFailed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        msg.error ?? 'Query execution failed.',
                        style: const TextStyle(color: AppTheme.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Cancelled Badge
            if (isCancelled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.stop_circle_outlined, color: Colors.grey, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Generation stopped by user.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],

            // Assistant Actions Row (Copy, Retry)
            if (!isThinking) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 16, color: Colors.grey),
                    tooltip: 'Copy response to clipboard',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: msg.content));
                      AppNotifier.showSuccess(context, 'Response copied to clipboard.');
                    },
                  ),
                  if (hasFailed)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primary),
                      tooltip: 'Retry query',
                      onPressed: () {
                        // Find previous user message
                        final msgs = ref.read(chatProvider).messages;
                        final idx = msgs.indexOf(msg);
                        if (idx > 0 && msgs[idx - 1].role == 'user') {
                          _submitPrompt(msgs[idx - 1].content);
                        }
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Active Thinking Box
  Widget _buildThinkingBox(BuildContext context, ChatMessageModel msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
              SizedBox(width: 10),
              Text(
                'Thinking...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
            ],
          ),
          if (msg.steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var step in msg.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    _getStepIcon(step.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.text,
                        style: TextStyle(
                          fontSize: 12,
                          color: step.status == 'in_progress' ? AppTheme.primary : const Color(0xFF6B7280),
                          fontWeight: step.status == 'in_progress' ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // Collapsible Plan Summary for Completed Assistant Messages
  Widget _buildCollapsiblePlanSummary(BuildContext context, ChatMessageModel msg) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => ref.read(chatProvider.notifier).togglePlanExpanded(msg.id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Completed ${msg.steps.length} execution steps',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
                  ),
                  const Spacer(),
                  Icon(
                    msg.isPlanExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (msg.isPlanExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  const Divider(height: 12, color: Color(0xFFE5E7EB)),
                  for (var step in msg.steps)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Text(
                            step.text,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _getStepIcon(String status) {
    switch (status) {
      case 'in_progress':
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.secondary),
        );
      case 'completed':
        return const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981));
      case 'failed':
        return const Icon(Icons.cancel, size: 14, color: AppTheme.error);
      default:
        return const Icon(Icons.radio_button_unchecked, size: 14, color: Color(0xFF9CA3AF));
    }
  }

  // ---------------------------------------------------------------------------
  // Fixed Bottom Composer
  // ---------------------------------------------------------------------------
  Widget _buildComposer(BuildContext context, ChatState chatState, bool isMobile) {
    final canSend = _promptController.text.trim().isNotEmpty && !chatState.isStreaming;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promptController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitPrompt(),
                decoration: const InputDecoration(
                  hintText: 'Ask anything about restaurant revenue, food costs, dishes, staff...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppTheme.primary, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Color(0xFFF9FAFB),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Stop / Send Button
            if (chatState.isStreaming)
              IconButton.filled(
                icon: const Icon(Icons.stop, color: Colors.white, size: 20),
                tooltip: 'Stop generation',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: () {
                  ref.read(chatProvider.notifier).stopGeneration();
                },
              )
            else
              IconButton.filled(
                icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                tooltip: 'Send message',
                style: IconButton.styleFrom(
                  backgroundColor: canSend ? AppTheme.primary : Colors.grey.shade300,
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: canSend ? () => _submitPrompt() : null,
              ),
          ],
        ),
      ),
    );
  }

  static String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}
