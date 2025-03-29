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
    _handleTextChange();
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
    final colorScheme = Theme.of(context).colorScheme;
    final bool canSend = _isComposing && !widget.isGenerating;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ModelSelectorDropdown(
              onModelSelected: widget.onModelSelected ?? (_) {},
              selectedModel: widget.initialModel,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(
                    hintText: widget.isGenerating ? 'AI 正在回复...' : '输入消息...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: colorScheme.outline.withOpacity(0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: colorScheme.outline.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    isDense: true,
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  enabled: !widget.isGenerating,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                  onSubmitted: (_) {
                    if (canSend) {
                      widget.onSend();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                width: 44,
                child: widget.isGenerating
                    ? IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor:
                              colorScheme.errorContainer.withOpacity(0.8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                        ),
                        icon: Icon(Icons.stop_rounded,
                            size: 24, color: colorScheme.onErrorContainer),
                        tooltip: '停止生成',
                        onPressed: widget.onCancel,
                      )
                    : IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: canSend
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                        ),
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          size: 24,
                          color: canSend
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        tooltip: '发送消息',
                        onPressed: canSend ? widget.onSend : null,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
