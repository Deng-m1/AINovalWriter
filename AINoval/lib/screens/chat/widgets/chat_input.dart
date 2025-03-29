import 'package:flutter/material.dart';
import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/screens/chat/widgets/model_selector_dropdown.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.isGenerating = false,
    this.onCancel,
    this.onModelSelected,
    this.initialModel,
  }) : super(key: key);
  
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isGenerating;
  final VoidCallback? onCancel;
  final Function(UserAIModelConfigModel?)? onModelSelected;
  final UserAIModelConfigModel? initialModel;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isComposing = false;
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }
  
  void _handleTextChange() {
    setState(() {
      _isComposing = widget.controller.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 模型选择器 - 放在最上方左侧
          ModelSelectorDropdown(
            onModelSelected: widget.onModelSelected ?? (_) {},
            selectedModel: widget.initialModel,
          ),
          
          const SizedBox(height: 6.0),
          
          // 输入框和按钮区域
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 输入框
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabled: !widget.isGenerating,
                    ),
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                
                // 附件按钮
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: IconButton(
                    icon: const Icon(Icons.attach_file, size: 20),
                    tooltip: '附加文件',
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey.shade600,
                  ),
                ),
                
                // 图片按钮
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: IconButton(
                    icon: const Icon(Icons.image_outlined, size: 20),
                    tooltip: '插入图片',
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey.shade600,
                  ),
                ),
                
                // 发送/取消按钮
                Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 8.0, left: 6.0),
                  child: widget.isGenerating
                    ? IconButton(
                        icon: const Icon(Icons.stop_circle_outlined, size: 28),
                        tooltip: '取消生成',
                        onPressed: widget.onCancel,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Theme.of(context).colorScheme.error,
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward, size: 20),
                        tooltip: '发送消息',
                        onPressed: _isComposing && !widget.isGenerating ? widget.onSend : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: _isComposing
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade400,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 