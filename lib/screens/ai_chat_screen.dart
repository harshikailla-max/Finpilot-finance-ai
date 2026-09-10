import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/ai_provider.dart';
import '../utils/constants.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _suggestions = [
    'Where am I spending the most?',
    'How can I save more?',
    'Am I overspending?',
    'Create a budget for me',
    'Can I reach my savings goal?',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _messageController.clear();

    final aiProvider = context.read<AIProvider>();
    await aiProvider.sendMessage(text);

    // Scroll to bottom
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AIProvider>();
    final messages = aiProvider.chatMessages;
    final isTyping = aiProvider.isTyping;

    // Trigger auto-scroll on load
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FinPilot AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Icon(Icons.circle, size: 6, color: AppColors.successGreen),
                SizedBox(width: 4),
                Text(
                  'Online • Financial Intelligence',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.dangerRed),
            tooltip: 'Clear Chat',
            onPressed: () => aiProvider.clearChat(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Suggestion chips (only visible if messages are empty / only contains welcome message)
            if (messages.length <= 1)
              Container(
                height: 48,
                margin: const EdgeInsets.only(top: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final sug = _suggestions[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(sug),
                        backgroundColor: AppColors.cardBackground,
                       
                        side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onPressed: () => _sendMessage(sug),
                      ),
                    );
                  },
                ),
              ),

            // Messages thread
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isUser = msg.isUser;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.primaryPurple : AppColors.cardBackground,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
                          bottomRight: isUser ? Radius.zero : const Radius.circular(18),
                        ),
                        border: Border.all(
                          color: isUser
                              ? AppColors.primaryPurple
                              : Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Text(
                        msg.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0.0),
                  );
                },
              ),
            ),

            // Typing Indicator
            if (isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: AppColors.cyan, size: 14),
                          SizedBox(width: 8),
                          Text('FinPilot is thinking...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1000.ms),
                  ],
                ),
              ),

            // Text Input Box
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ask FinPilot anything...',
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
                          borderSide: const BorderSide(color: AppColors.cyan, width: 1.2),
                        ),
                      ),
                      onFieldSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Send button
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primaryPurple, AppColors.cyan],
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                      onPressed: () => _sendMessage(_messageController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
