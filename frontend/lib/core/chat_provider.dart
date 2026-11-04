import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'branch_provider.dart';
import 'restaurant_provider.dart';

// -----------------------------------------------------------------------------
// Security & Sanitization Helpers
// -----------------------------------------------------------------------------

/// Strips raw SQL queries, SQL code blocks, and internal tool invocations
/// to guarantee zero SQL leakage and ensure database security on the UI.
String sanitizeSqlFromText(String text) {
  if (text.isEmpty) return text;
  var cleaned = text;

  // 1. Strip ```sql ... ``` code blocks
  cleaned = cleaned.replaceAll(RegExp(r'```(?:sql|SQL)[\s\S]*?```'), '');

  // 2. Strip code blocks containing SQL SELECT / FROM
  cleaned = cleaned.replaceAll(
    RegExp(r'```[\s\S]*?\b(?:SELECT|select)\b[\s\S]*?\b(?:FROM|from)\b[\s\S]*?```'),
    '',
  );

  // 3. Strip standalone single or multi-line SQL statements starting with SELECT/WITH and having FROM
  cleaned = cleaned.replaceAll(
    RegExp(r'^\s*(?:SELECT|WITH)\b(?:(?!```)[\s\S])*?\bFROM\b(?:(?!```)[\s\S])*?(?:;|\n(?=\s*\n)|$)', caseSensitive: false, multiLine: true),
    '',
  );

  // 4. Strip LangChain / Agent CLI artifacts
  cleaned = cleaned.replaceAll(RegExp(r'>\s*Entering new.*', caseSensitive: false), '');
  cleaned = cleaned.replaceAll(RegExp(r'Invoking:\s*`?[a-zA-Z0-9_]+`?.*', caseSensitive: false), '');

  // 5. Clean up extra newlines
  cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return cleaned.trim();
}

// -----------------------------------------------------------------------------
// Models
// -----------------------------------------------------------------------------

class ChatConversationModel {
  final String id;
  final String title;
  final int? restaurantId;
  final int? branchId;
  final String? branchName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final int messageCount;

  ChatConversationModel({
    required this.id,
    required this.title,
    this.restaurantId,
    this.branchId,
    this.branchName,
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.messageCount = 0,
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) {
    return ChatConversationModel(
      id: json['conversation_id'] ?? '',
      title: json['title'] ?? 'New Chat',
      restaurantId: json['restaurant_id'],
      branchId: json['branch_id'],
      branchName: json['branch_name'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      lastMessageAt: json['last_message_at'] != null ? DateTime.tryParse(json['last_message_at']) : null,
      messageCount: json['message_count'] ?? 0,
    );
  }
}

class ChatPlanStep {
  final String id;
  final String text;
  String status; // 'pending', 'in_progress', 'completed', 'failed'

  ChatPlanStep({
    required this.id,
    required this.text,
    this.status = 'pending',
  });

  factory ChatPlanStep.fromJson(Map<String, dynamic> json) {
    return ChatPlanStep(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'status': status,
  };
}

class ChatInlineChartSpec {
  final String chartId;
  final String chartType; // 'bar', 'line', 'pie', 'donut', 'area'
  final String title;
  final String xField;
  final String yField;
  final String xLabel;
  final String yLabel;
  final List<dynamic> series;
  final List<dynamic> data;
  final String description;

  ChatInlineChartSpec({
    required this.chartId,
    required this.chartType,
    required this.title,
    required this.xField,
    required this.yField,
    required this.xLabel,
    required this.yLabel,
    required this.series,
    required this.data,
    required this.description,
  });

  factory ChatInlineChartSpec.fromJson(Map<String, dynamic> json) {
    return ChatInlineChartSpec(
      chartId: json['chart_id']?.toString() ?? '',
      chartType: json['chart_type']?.toString().toLowerCase() ?? 'bar',
      title: json['title']?.toString() ?? 'Operational Chart',
      xField: json['x_field']?.toString() ?? '',
      yField: json['y_field']?.toString() ?? '',
      xLabel: json['x_label']?.toString() ?? (json['x_field']?.toString() ?? ''),
      yLabel: json['y_label']?.toString() ?? (json['y_field']?.toString() ?? ''),
      series: (json['series'] as List<dynamic>?) ?? [],
      data: (json['data'] as List<dynamic>?) ?? [],
      description: json['description']?.toString() ?? '',
    );
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String role; // 'user', 'assistant', 'system'
  String content;
  final int? branchId;
  String status; // 'pending', 'thinking', 'completed', 'failed', 'cancelled'
  List<ChatPlanStep> steps;
  List<ChatInlineChartSpec> charts;
  List<dynamic> rawData;
  String? error;
  final DateTime? createdAt;
  bool isPlanExpanded;

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    this.content = '',
    this.branchId,
    this.status = 'completed',
    List<ChatPlanStep>? steps,
    List<ChatInlineChartSpec>? charts,
    List<dynamic>? rawData,
    this.error,
    this.createdAt,
    this.isPlanExpanded = false,
  })  : steps = steps ?? [],
        charts = charts ?? [],
        rawData = rawData ?? [];

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] as Map<String, dynamic>? ?? {};

    final stepsList = <ChatPlanStep>[];
    if (meta['plan'] is List) {
      for (var s in meta['plan']) {
        if (s is Map<String, dynamic>) {
          stepsList.add(ChatPlanStep.fromJson(s));
        } else if (s is String) {
          stepsList.add(ChatPlanStep(id: s, text: s, status: 'completed'));
        }
      }
    }

    final chartsList = <ChatInlineChartSpec>[];
    if (meta['charts'] is List) {
      for (var c in meta['charts']) {
        if (c is Map<String, dynamic>) {
          chartsList.add(ChatInlineChartSpec.fromJson(c));
        }
      }
    }

    return ChatMessageModel(
      id: json['message_id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      role: json['role'] ?? 'assistant',
      content: sanitizeSqlFromText(json['content'] ?? ''),
      branchId: json['branch_id'],
      status: json['status'] ?? 'completed',
      steps: stepsList,
      charts: chartsList,
      rawData: (meta['data'] as List<dynamic>?) ?? [],
      error: meta['error'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      isPlanExpanded: false,
    );
  }
}

// -----------------------------------------------------------------------------
// State
// -----------------------------------------------------------------------------

class ChatState {
  final List<ChatConversationModel> conversations;
  final String? activeConversationId;
  final List<ChatMessageModel> messages;
  final bool isLoadingConversations;
  final bool isLoadingMessages;
  final bool isStreaming;
  final String? error;

  ChatState({
    this.conversations = const [],
    this.activeConversationId,
    this.messages = const [],
    this.isLoadingConversations = false,
    this.isLoadingMessages = false,
    this.isStreaming = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatConversationModel>? conversations,
    String? activeConversationId,
    bool clearActiveConversation = false,
    List<ChatMessageModel>? messages,
    bool? isLoadingConversations,
    bool? isLoadingMessages,
    bool? isStreaming,
    String? error,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      activeConversationId: clearActiveConversation ? null : (activeConversationId ?? this.activeConversationId),
      messages: messages ?? this.messages,
      isLoadingConversations: isLoadingConversations ?? this.isLoadingConversations,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error,
    );
  }
}

// -----------------------------------------------------------------------------
// State Notifier
// -----------------------------------------------------------------------------

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

// Backward-compatible stream provider for existing references
final chatStreamProvider = Provider((ref) => ref.watch(chatProvider.notifier));

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  final _storage = const FlutterSecureStorage();
  http.Client? _activeClient;

  ChatNotifier(this._ref) : super(ChatState()) {
    loadConversations();
  }

  String get _baseUrl {
    final dio = _ref.read(dioProvider);
    return dio.options.baseUrl;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final restaurantId = _ref.read(selectedRestaurantIdProvider);
    if (restaurantId != null) {
      headers['X-Restaurant-ID'] = restaurantId.toString();
    }
    return headers;
  }

  // 1. Load All Conversations
  Future<void> loadConversations() async {
    state = state.copyWith(isLoadingConversations: true, error: null);
    try {
      final dio = _ref.read(dioProvider);
      final restaurantId = _ref.read(selectedRestaurantIdProvider);
      final res = await dio.get('/chat/conversations', queryParameters: {
        if (restaurantId != null) 'restaurant_id': restaurantId,
      });

      final list = (res.data as List).map((c) => ChatConversationModel.fromJson(c)).toList();
      state = state.copyWith(
        conversations: list,
        isLoadingConversations: false,
      );

      // If no conversation is active and conversations exist, select the first one
      if (state.activeConversationId == null && list.isNotEmpty) {
        selectConversation(list.first.id);
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      state = state.copyWith(isLoadingConversations: false, error: e.toString());
    }
  }

  // 2. Select an Existing Conversation
  Future<void> selectConversation(String conversationId) async {
    if (state.activeConversationId == conversationId && state.messages.isNotEmpty) {
      return;
    }

    state = state.copyWith(
      activeConversationId: conversationId,
      isLoadingMessages: true,
      error: null,
    );

    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get('/chat/conversations/$conversationId');
      final data = res.data as Map<String, dynamic>;
      final rawMsgs = (data['messages'] as List? ?? []);
      final messages = rawMsgs.map((m) => ChatMessageModel.fromJson(m)).toList();

      state = state.copyWith(
        activeConversationId: conversationId,
        messages: messages,
        isLoadingMessages: false,
      );
    } catch (e) {
      debugPrint('Error loading conversation history: $e');
      state = state.copyWith(isLoadingMessages: false, error: e.toString());
    }
  }

  // 3. Start a Fresh New Chat
  void startNewChat() {
    // If currently streaming, stop it
    stopGeneration();
    state = state.copyWith(
      clearActiveConversation: true,
      messages: [],
      error: null,
    );
  }

  // 4. Rename Conversation
  Future<void> renameConversation(String conversationId, String newTitle) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.patch('/chat/conversations/$conversationId', data: {'title': newTitle});
      await loadConversations();
    } catch (e) {
      debugPrint('Error renaming conversation: $e');
    }
  }

  // 5. Delete Conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete('/chat/conversations/$conversationId');

      if (state.activeConversationId == conversationId) {
        startNewChat();
      }
      await loadConversations();
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  // 6. Record Branch Switch System Event
  Future<void> recordBranchSwitch(int branchId, String branchName) async {
    final activeId = state.activeConversationId;
    // Only record if inside an active conversation that already has messages
    if (activeId == null || state.messages.isEmpty) return;

    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.post('/chat/conversations/$activeId/system-event', data: {
        'event_type': 'branch_switch',
        'branch_id': branchId,
        'branch_name': branchName,
      });

      final sysMsg = ChatMessageModel(
        id: res.data['message_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: activeId,
        role: 'system',
        content: res.data['content'] ?? 'Switched to branch: $branchName',
        branchId: branchId,
        status: 'completed',
        createdAt: DateTime.now(),
      );

      state = state.copyWith(messages: [...state.messages, sysMsg]);
    } catch (e) {
      debugPrint('Error recording branch switch: $e');
    }
  }

  // 7. Stop Generation
  Future<void> stopGeneration() async {
    if (!state.isStreaming) return;

    _activeClient?.close();
    _activeClient = null;

    final activeId = state.activeConversationId;
    if (activeId != null) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.post('/chat/conversations/$activeId/stop');
      } catch (_) {}
    }

    // Mark any trailing assistant thinking message as cancelled
    final updatedMessages = state.messages.map((m) {
      if (m.role == 'assistant' && (m.status == 'thinking' || m.status == 'pending')) {
        m.status = 'cancelled';
        if (m.content.isEmpty) {
          m.content = 'Generation was stopped.';
        }
      }
      return m;
    }).toList();

    state = state.copyWith(
      isStreaming: false,
      messages: updatedMessages,
    );
  }

  // 8. Toggle Plan Details Visibility
  void togglePlanExpanded(String messageId) {
    final updated = state.messages.map((m) {
      if (m.id == messageId) {
        m.isPlanExpanded = !m.isPlanExpanded;
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  // 9. Send User Message & Stream Responses
  Future<void> sendMessage(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || state.isStreaming) return;

    String? convId = state.activeConversationId;
    final restaurantId = _ref.read(selectedRestaurantIdProvider);
    final branchId = _ref.read(selectedBranchProvider);

    // If starting from clean state, create new conversation first
    if (convId == null) {
      try {
        final dio = _ref.read(dioProvider);
        final res = await dio.post('/chat/conversations', data: {
          'title': trimmed.length > 40 ? '${trimmed.substring(0, 37)}...' : trimmed,
          if (branchId != null) 'branch_id': branchId,
          if (restaurantId != null) 'restaurant_id': restaurantId,
        });
        convId = res.data['conversation_id'];
        state = state.copyWith(activeConversationId: convId);
      } catch (e) {
        debugPrint('Failed to auto-create conversation: $e');
      }
    }

    final targetConvId = convId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final userMsgId = 'u_${DateTime.now().millisecondsSinceEpoch}';
    final asstMsgId = 'a_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Immediately display User Message and Assistant Thinking placeholder in timeline
    final userMessage = ChatMessageModel(
      id: userMsgId,
      conversationId: targetConvId,
      role: 'user',
      content: trimmed,
      branchId: branchId,
      status: 'completed',
      createdAt: DateTime.now(),
    );

    final asstPlaceholder = ChatMessageModel(
      id: asstMsgId,
      conversationId: targetConvId,
      role: 'assistant',
      content: '',
      branchId: branchId,
      status: 'thinking',
      steps: [
        ChatPlanStep(id: 'step_understand', text: 'Understanding inquiry & scope', status: 'in_progress'),
        ChatPlanStep(id: 'step_query', text: 'Retrieving business data', status: 'pending'),
        ChatPlanStep(id: 'step_analyze', text: 'Synthesizing response & insights', status: 'pending'),
      ],
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      activeConversationId: targetConvId,
      messages: [...state.messages, userMessage, asstPlaceholder],
      isStreaming: true,
      error: null,
    );

    // 2. Start HTTP Streaming Request
    _activeClient = http.Client();
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/chat/conversations/$targetConvId/messages');
      final request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = jsonEncode({
          'message': trimmed,
          if (restaurantId != null) 'restaurant_id': restaurantId,
          if (branchId != null) 'branch_id': branchId,
        });

      final response = await _activeClient!.send(request);

      if (response.statusCode != 200) {
        _handleError(asstMsgId, 'Server error (HTTP ${response.statusCode})');
        return;
      }

      // 3. Process NDJSON Chunks with Split Buffer
      String lineBuffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (!state.isStreaming) break;

        lineBuffer += chunk;
        while (lineBuffer.contains('\n')) {
          final newlineIdx = lineBuffer.indexOf('\n');
          final rawLine = lineBuffer.substring(0, newlineIdx).trim();
          lineBuffer = lineBuffer.substring(newlineIdx + 1);

          if (rawLine.isNotEmpty) {
            try {
              final event = jsonDecode(rawLine);
              _handleStreamEvent(asstMsgId, event);
            } catch (e) {
              debugPrint('NDJSON parse error on line: $e');
            }
          }
        }
      }

      // Flush remaining line buffer if any
      if (lineBuffer.trim().isNotEmpty) {
        try {
          final event = jsonDecode(lineBuffer.trim());
          _handleStreamEvent(asstMsgId, event);
        } catch (_) {}
      }
    } catch (e) {
      if (state.isStreaming) {
        _handleError(asstMsgId, 'Network error: $e');
      }
    } finally {
      _activeClient?.close();
      _activeClient = null;
      if (mounted) {
        state = state.copyWith(isStreaming: false);
      }
      // Reload conversation list to refresh titles and timestamps
      loadConversations();
    }
  }

  void _handleStreamEvent(String asstMsgId, Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final currentMsgs = [...state.messages];
    final asstIdx = currentMsgs.indexWhere((m) => m.id == asstMsgId);
    if (asstIdx == -1) return;

    final asst = currentMsgs[asstIdx];

    if (type == 'plan') {
      final rawSteps = event['steps'] as List<dynamic>? ?? [];
      final parsedSteps = <ChatPlanStep>[];
      for (var s in rawSteps) {
        if (s is Map<String, dynamic>) {
          parsedSteps.add(ChatPlanStep.fromJson(s));
        } else if (s is String) {
          parsedSteps.add(ChatPlanStep(id: s, text: s, status: 'pending'));
        }
      }
      if (parsedSteps.isNotEmpty) {
        asst.steps = parsedSteps;
      }
    } else if (type == 'step_started') {
      final stepId = event['id']?.toString();
      for (var s in asst.steps) {
        if (s.id == stepId) {
          s.status = 'in_progress';
          break;
        }
      }
    } else if (type == 'step_completed') {
      final stepId = event['id']?.toString();
      for (var s in asst.steps) {
        if (s.id == stepId) {
          s.status = 'completed';
          break;
        }
      }
    } else if (type == 'message_chunk') {
      final delta = event['delta']?.toString() ?? '';
      asst.content += delta;
      asst.status = 'thinking'; // Keep streaming thinking state
    } else if (type == 'final') {
      final finalContent = event['content']?.toString();
      if (finalContent != null && finalContent.isNotEmpty) {
        asst.content = sanitizeSqlFromText(finalContent);
      }
      asst.status = 'completed';

      // Mark all plan steps as completed on final response
      for (var s in asst.steps) {
        s.status = 'completed';
      }

      // Attach declarative charts
      final rawCharts = event['charts'] as List<dynamic>? ?? [];
      final parsedCharts = <ChatInlineChartSpec>[];
      for (var c in rawCharts) {
        if (c is Map<String, dynamic>) {
          parsedCharts.add(ChatInlineChartSpec.fromJson(c));
        }
      }
      asst.charts = parsedCharts;

      // Attach raw tabular data
      if (event['data'] is List) {
        asst.rawData = event['data'] as List<dynamic>;
      }
    } else if (type == 'cancelled') {
      asst.status = 'cancelled';
      if (asst.content.isEmpty) {
        asst.content = 'Generation was stopped.';
      }
    } else if (type == 'error') {
      asst.status = 'failed';
      asst.error = event['message']?.toString() ?? 'An unknown error occurred.';
      if (asst.content.isEmpty) {
        asst.content = 'Error: ${asst.error}';
      }
    }

    state = state.copyWith(messages: currentMsgs);
  }

  void _handleError(String asstMsgId, String errorMessage) {
    final currentMsgs = [...state.messages];
    final asstIdx = currentMsgs.indexWhere((m) => m.id == asstMsgId);
    if (asstIdx != -1) {
      currentMsgs[asstIdx].status = 'failed';
      currentMsgs[asstIdx].error = errorMessage;
      if (currentMsgs[asstIdx].content.isEmpty) {
        currentMsgs[asstIdx].content = errorMessage;
      }
      state = state.copyWith(messages: currentMsgs, isStreaming: false);
    }
  }

  @override
  void dispose() {
    _activeClient?.close();
    super.dispose();
  }
}
