import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/chat_models.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    Key? key,
    required this.message,
    required this.onActionSelected,
  }) : super(key: key);
  final ChatMessage message;
  final Function(MessageAction) onActionSelected;

  @override
  Widget build(BuildContext context) {
    // 假设 message.role 可以区分用户和 AI (如果用 sender，则替换为 message.sender)
    final bool isUserMessage = message.role ==
        MessageRole.user; // 或者 message.sender == MessageSender.user

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // 稍微减少垂直间距
      child: Row(
        mainAxisAlignment:
            isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start, // 保持顶部对齐
        children: [
          // AI 头像占位符 (如果需要显示)
          if (!isUserMessage) _buildAvatar(context, false),
          if (!isUserMessage) const SizedBox(width: 8),

          // 消息气泡容器 - 使用LayoutBuilder
          Flexible(
            child: LayoutBuilder(builder: (context, constraints) {
              // 基于LayoutBuilder中的约束计算最大宽度，保证气泡不会太宽
              final maxWidth = constraints.maxWidth * 0.95;

              return Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  // 用户消息时间戳靠右，AI 消息时间戳靠左
                  crossAxisAlignment: isUserMessage
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // 气泡主体
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 14.0), // 调整内边距
                      decoration: BoxDecoration(
                        color: isUserMessage
                            ? Theme.of(context).colorScheme.primary // 用户消息用主色
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainer, // AI消息用 surfaceContainer
                        // 实现"尾巴"效果的圆角
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16.0),
                          topRight: const Radius.circular(16.0),
                          bottomLeft: Radius.circular(
                              isUserMessage ? 16.0 : 4.0), // 用户左下圆角，AI左下小圆角/直角
                          bottomRight: Radius.circular(
                              isUserMessage ? 4.0 : 16.0), // 用户右下小圆角/直角，AI右下圆角
                        ),
                        // 可以为 AI 消息添加细微边框
                        border: !isUserMessage
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withOpacity(0.3),
                                width: 0.5,
                              )
                            : null,
                      ),
                      child: isUserMessage
                          ? _buildUserMessageContent(context)
                          : _buildAIMessageContent(context),
                    ),
                    // 时间戳
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 4.0, left: 6.0, right: 6.0), // 调整时间戳边距
                      child: Text(
                        message.formattedTime, // 使用已有的格式化时间
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withOpacity(0.7), // 调整时间戳颜色
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          // 用户头像占位符 (如果需要显示)
          if (isUserMessage) const SizedBox(width: 8),
          if (isUserMessage) _buildAvatar(context, true),
        ],
      ),
    );
  }

  // 头像构建方法 (可选)
  Widget _buildAvatar(BuildContext context, bool isUser) {
    // 现在使用 Icon 代替 CircleAvatar
    return Icon(
      isUser ? Icons.person_outline : Icons.smart_toy_outlined,
      color: isUser
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary,
      size: 28, // 调整大小
    );
    /* return CircleAvatar(
       radius: 16, // 调整大小
       backgroundColor: isUser
           ? Theme.of(context).colorScheme.primaryContainer
           : Theme.of(context).colorScheme.secondaryContainer,
       child: Icon(
         isUser ? Icons.person_outline : Icons.smart_toy_outlined, // 使用 outline 图标
         size: 18, // 图标大小
         color: isUser
             ? Theme.of(context).colorScheme.onPrimaryContainer
             : Theme.of(context).colorScheme.onSecondaryContainer,
       ),
     ); */
  }

  // 构建用户消息内容
  Widget _buildUserMessageContent(BuildContext context) {
    return Text(
      message.content,
      softWrap: true, // Ensure text wraps
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimary, // 用户消息文本颜色
        fontSize: 14, // 调整字体大小
        height: 1.4, // 调整行高
      ),
    );
  }

  // 构建AI消息内容 (Markdown)
  Widget _buildAIMessageContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.status == MessageStatus.error)
          _buildErrorMessage(context)
        else
          MarkdownBody(
            data: message.content.isEmpty &&
                    message.status == MessageStatus.pending
                ? '思考中...'
                : message.content,
            styleSheet: MarkdownStyleSheet(
              p: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant, // AI 消息主要文本颜色
                fontSize: 14, // 字体大小
                height: 1.4, // 行高
              ),
              h1: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface, fontWeight: FontWeight.w600),
              h2: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface, fontWeight: FontWeight.w600),
              h3: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface, fontWeight: FontWeight.w600),
              code: textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: colorScheme.surfaceContainerHighest
                    .withOpacity(0.5), // 代码背景色
                color: colorScheme.onSurfaceVariant, // 代码文字颜色
                fontSize: 13,
              ),
              codeblockDecoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest
                    .withOpacity(0.5), // 代码块背景色
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color:
                        colorScheme.outlineVariant.withOpacity(0.3)), // 代码块边框
              ),
              blockquoteDecoration: BoxDecoration(
                // 引用块样式
                border: Border(
                    left: BorderSide(color: colorScheme.primary, width: 4)),
                color: colorScheme.primaryContainer.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4)),
              ),
              blockquotePadding: const EdgeInsets.all(12), // 引用块内边距
              listBulletPadding: const EdgeInsets.only(right: 4), // 列表标记边距
              listIndent: 16, // 列表缩进
            ),
          ),

        // ActionChip 样式调整
        if (message.actions != null && message.actions!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10.0), // Chip 与上方内容的间距
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: message.actions!.map((action) {
                return ActionChip(
                  label: Text(action.label),
                  onPressed: () => onActionSelected(action),
                  backgroundColor: colorScheme.secondaryContainer
                      .withOpacity(0.5), // Chip 背景色
                  labelStyle: textTheme.bodySmall?.copyWith(
                    // Chip 文字样式
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2), // Chip 内边距
                  side: BorderSide.none, // 移除边框
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)), // 圆角
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // 构建错误消息 (样式微调)
  Widget _buildErrorMessage(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 18, // 调整图标大小
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.content.isEmpty ? '发生错误' : message.content, // 默认错误消息
            softWrap: true, // Ensure error text wraps
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w500, // 加粗错误文本
                ),
          ),
        ),
      ],
    );
  }
}
