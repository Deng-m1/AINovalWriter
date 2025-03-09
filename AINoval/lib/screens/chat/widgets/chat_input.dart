import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isGenerating;
  final VoidCallback? onCancel;
  
  const ChatInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.isGenerating = false,
    this.onCancel,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '输入消息...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                enabled: !isGenerating,
              ),
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty && !isGenerating) {
                  onSend();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          if (isGenerating)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: '取消生成',
              onPressed: onCancel,
              color: Theme.of(context).colorScheme.error,
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              tooltip: '发送消息',
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  onSend();
                }
              },
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
} 