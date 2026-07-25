import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AiChatBubble extends StatefulWidget {
  const AiChatBubble({super.key});

  @override
  State<AiChatBubble> createState() => _AiChatBubbleState();
}

class _AiChatBubbleState extends State<AiChatBubble> {
  bool _isOpen = false;
  final TextEditingController _controller = TextEditingController();

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 32,
      right: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isOpen)
            Container(
              width: 350,
              height: 500,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
                ],
                border: Border.all(color: const Color(0xFFE9ECEF)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppTheme.secondaryContainer, size: 20),
                            const SizedBox(width: 8),
                            Text('AI Assistant', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: _toggleChat,
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildAiMessage(context, 'Hello! I am your AI Assistant. How can I help you audit the restaurant today?'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: 'Ask anything...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: AppTheme.secondary),
                          onPressed: () {},
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          FloatingActionButton(
            backgroundColor: AppTheme.secondary,
            onPressed: _toggleChat,
            child: Icon(_isOpen ? Icons.close : Icons.auto_awesome, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAiMessage(BuildContext context, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12).copyWith(topLeft: Radius.zero),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
