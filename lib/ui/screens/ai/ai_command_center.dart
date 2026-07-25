import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/chat_provider.dart';
import '../../../theme/app_theme.dart';
import 'dart:async';

class AiCommandCenterScreen extends ConsumerStatefulWidget {
  const AiCommandCenterScreen({super.key});

  @override
  ConsumerState<AiCommandCenterScreen> createState() => _AiCommandCenterScreenState();
}

class _AiCommandCenterScreenState extends ConsumerState<AiCommandCenterScreen> {
  final TextEditingController _promptController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isProcessing = false;

  void _submitQuery() async {
    if (_promptController.text.trim().isEmpty) return;
    
    final query = _promptController.text;
    _promptController.clear();
    
    setState(() {
      _messages.add({'type': 'user', 'content': query});
      _isProcessing = true;
    });

    // Stream real responses from backend
    final planId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final chatService = ref.read(chatStreamProvider);
    chatService.sendQuery(query).listen((data) {
      if (!mounted) return;
      
      setState(() {
        if (data['type'] == 'plan') {
          _messages.add({
            'type': 'plan',
            'id': planId,
            'steps': (data['steps'] as List).map((s) => {'text': s, 'status': 'pending'}).toList()
          });
        } else if (data['type'] == 'step_complete') {
          // Update one step to done
          final msgIndex = _messages.indexWhere((m) => m['type'] == 'plan' && m['id'] == planId);
          if (msgIndex >= 0) {
            final steps = _messages[msgIndex]['steps'] as List;
            for (var step in steps) {
              if (step['status'] == 'pending') {
                step['status'] = 'done';
                break;
              }
            }
          }
        } else if (data['type'] == 'final') {
          _messages.add({
            'type': 'ai',
            'content': data['text'] ?? 'No text response.',
            'hasChart': data['charts'] != null && (data['charts'] as List).isNotEmpty,
          });
          _isProcessing = false;
        } else if (data['type'] == 'error') {
          _messages.add({
            'type': 'ai',
            'content': 'Error: ${data['message']}',
            'hasChart': false,
          });
          _isProcessing = false;
        }
      });
    }, onError: (e) {
      setState(() {
        _isProcessing = false;
        _messages.add({
          'type': 'ai',
          'content': 'Error connecting to AI: $e',
          'hasChart': false,
        });
      });
    });
  }

  void _updatePlanStatus(String planId, int stepIndex, String status) {
    setState(() {
      final msg = _messages.firstWhere((m) => m['type'] == 'plan' && m['id'] == planId);
      msg['steps'][stepIndex]['status'] = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 32),
              const SizedBox(width: 16),
              Text('AI Command Center', style: Theme.of(context).textTheme.displayLarge),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        if (msg['type'] == 'user') {
                          return _buildUserMessage(context, msg['content']);
                        } else if (msg['type'] == 'plan') {
                          return _buildPlanMessage(context, msg['steps']);
                        } else {
                          return _buildAiMessage(context, msg['content'], msg['hasChart'] ?? false);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promptController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Plot sales vs expenses for the last 30 days',
                              filled: true,
                              fillColor: AppTheme.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _submitQuery(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isProcessing ? null : _submitQuery,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          child: _isProcessing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Send'),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context, String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, left: 64),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12).copyWith(topRight: Radius.zero),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  Widget _buildPlanMessage(BuildContext context, List<Map<String, dynamic>> steps) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, right: 64),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDim.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12).copyWith(topLeft: Radius.zero),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('AI Executing Plan...', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 12),
            ...steps.map((step) {
              final isDone = step['status'] == 'done';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, 
                         color: isDone ? Colors.green : Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(step['text'], style: TextStyle(
                      color: isDone ? AppTheme.onBackground : Colors.grey,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    )),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage(BuildContext context, String text, bool hasChart) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, right: 64),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12).copyWith(topLeft: Radius.zero),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 20),
                const SizedBox(width: 8),
                Text('AI Assistant', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(fontSize: 16)),
            if (hasChart) ...[
              const SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE9ECEF)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 48, color: AppTheme.primary.withOpacity(0.5)),
                      const SizedBox(height: 8),
                      const Text('[Vega-Lite Chart Rendered Here]', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
