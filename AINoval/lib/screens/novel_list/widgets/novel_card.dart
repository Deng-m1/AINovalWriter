import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/utils/date_formatter.dart';
import 'package:flutter/material.dart';

class NovelCard extends StatefulWidget {
  const NovelCard({
    super.key,
    required this.novel,
    required this.onTap,
    required this.isGridView,
  });
  final NovelSummary novel;
  final VoidCallback onTap;
  final bool isGridView;

  @override
  State<NovelCard> createState() => _NovelCardState();
}

class _NovelCardState extends State<NovelCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child:
          widget.isGridView ? _buildGridCard(context) : _buildListCard(context),
    );
  }

  // 构建网格视图中的卡片 - 优化设计
  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = NovelCardDesignUtils.getRandomPastelColor(widget.novel.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: _isHovering
          ? (Matrix4.identity()..translate(0, -4))
          : Matrix4.identity(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: _isHovering ? 6.0 : 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _isHovering
              ? BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.5), width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.black.withOpacity(0.02),
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面区域
              Expanded(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: NovelCoverWidget(
                    novel: widget.novel,
                    bgColor: bgColor,
                  ),
                ),
              ),

              // 信息区域
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: _isHovering
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, -2))
                        ]
                      : null,
                ),
                child: NovelInfoWidget(
                  novel: widget.novel,
                  theme: theme,
                  isCompact: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建列表视图中的卡片 - 优化设计
  Widget _buildListCard(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = NovelCardDesignUtils.getRandomPastelColor(widget.novel.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: _isHovering ? 3.0 : 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: _isHovering
            ? BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.5), width: 1)
            : BorderSide(color: Colors.grey.shade200, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.black.withOpacity(0.03),
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 封面图
              Container(
                width: 40,
                height: 56,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox.expand(
                        child: NovelCoverDesign(
                            bgColor: bgColor, id: widget.novel.id),
                      ),
                    ),
                    // 完成度进度条
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        child: LinearProgressIndicator(
                          value: widget.novel.completionPercentage,
                          backgroundColor: Colors.black12,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                          minHeight: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // 信息区域
              Expanded(
                child: NovelInfoWidget(
                  novel: widget.novel,
                  theme: theme,
                  isCompact: false,
                ),
              ),

              // 操作按钮
              NovelActionsMenu(novel: widget.novel),
            ],
          ),
        ),
      ),
    );
  }
}

/// 小说封面组件
class NovelCoverWidget extends StatelessWidget {
  const NovelCoverWidget({
    super.key,
    required this.novel,
    required this.bgColor,
  });

  final NovelSummary novel;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        gradient: LinearGradient(
          colors: [
            bgColor.withOpacity(0.9),
            bgColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 根据小说ID选择不同的封面设计
          NovelCoverDesign(bgColor: bgColor, id: novel.id),

          // 显示完成进度条
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: novel.completionPercentage,
              backgroundColor: Colors.black12,
              color: theme.colorScheme.primary.withOpacity(0.7),
              minHeight: 3,
            ),
          ),

          // 右上角显示字数指示
          if (novel.wordCount > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${novel.wordCount}字',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 小说信息组件
class NovelInfoWidget extends StatelessWidget {
  const NovelInfoWidget({
    super.key,
    required this.novel,
    required this.theme,
    this.isCompact = false,
  });

  final NovelSummary novel;
  final ThemeData theme;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            novel.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 12,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  DateFormatter.formatRelative(novel.lastEditTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          if (novel.seriesName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 12,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    novel.seriesName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            novel.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (novel.seriesName.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              novel.seriesName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                '上次编辑: ${DateFormatter.formatRelative(novel.lastEditTime)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.text_fields,
                size: 14,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                '${novel.wordCount}字',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      );
    }
  }
}

/// 小说操作菜单
class NovelActionsMenu extends StatelessWidget {
  const NovelActionsMenu({
    super.key,
    required this.novel,
  });

  final NovelSummary novel;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Colors.grey.shade500,
        size: 20,
      ),
      tooltip: '更多操作',
      onSelected: (String result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('列表项操作 "$result" 待实现')),
        );
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit, size: 18),
            title: Text('重命名', style: TextStyle(fontSize: 14)),
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'move',
          child: ListTile(
            leading: Icon(Icons.drive_file_move_outline, size: 18),
            title: Text('移动到系列', style: TextStyle(fontSize: 14)),
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(
              Icons.delete_outline,
              size: 18,
              color: Colors.red.shade700,
            ),
            title: Text(
              '删除',
              style: TextStyle(fontSize: 14, color: Colors.red.shade700),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            dense: true,
          ),
        ),
      ],
      splashRadius: 18,
    );
  }
}

/// 小说封面设计组件
class NovelCoverDesign extends StatelessWidget {
  const NovelCoverDesign({
    super.key,
    required this.bgColor,
    required this.id,
    this.index,
  });

  final Color bgColor;
  final String id;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final designType = index != null ? index! % 5 : id.hashCode % 5;

    switch (designType) {
      case 0:
        return CirclesDesign(baseColor: bgColor);
      case 1:
        return StripeDesign(baseColor: bgColor);
      case 2:
        return WaveDesign(baseColor: bgColor);
      case 3:
        return GridDesign(baseColor: bgColor);
      default:
        return GeometricDesign(baseColor: bgColor);
    }
  }
}

/// 圆形设计
class CirclesDesign extends StatelessWidget {
  const CirclesDesign({
    super.key,
    required this.baseColor,
  });

  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: CirclePainter(
            baseColor: baseColor,
            color: baseColor.withOpacity(0.5),
          ),
          size: const Size.square(200), // 给CustomPaint一个确定的大小
        ),
        Center(
          child: Icon(
            Icons.auto_stories,
            size: 28,
            color: Colors.black.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}

/// 条纹设计
class StripeDesign extends StatelessWidget {
  const StripeDesign({
    super.key,
    required this.baseColor,
  });

  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.7,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 15,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    color: baseColor.withGreen(180).withOpacity(0.8),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 35,
                  bottom: 20,
                  child: Container(
                    width: 6,
                    color: baseColor.withBlue(180).withOpacity(0.7),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 10,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor.withRed(200),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 15,
                  left: 50,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor.withGreen(200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.menu_book,
            size: 28,
            color: Colors.black.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}

/// 波浪设计
class WaveDesign extends StatelessWidget {
  const WaveDesign({
    super.key,
    required this.baseColor,
  });

  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.5,
          child: ClipPath(
            clipper: WaveClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [baseColor.withRed(200), baseColor.withBlue(200)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.book_outlined,
            size: 28,
            color: Colors.black.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}

/// 网格设计
class GridDesign extends StatelessWidget {
  const GridDesign({
    super.key,
    required this.baseColor,
  });

  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: GridPainter(
            color: baseColor.withOpacity(0.5),
            lineWidth: 1.0,
            spacing: 10.0,
          ),
          size: const Size.square(200), // 给CustomPaint一个确定的大小
        ),
        Center(
          child: Icon(
            Icons.chrome_reader_mode,
            size: 28,
            color: Colors.black.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}

/// 几何设计
class GeometricDesign extends StatelessWidget {
  const GeometricDesign({
    super.key,
    required this.baseColor,
  });

  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              child: Transform.rotate(
                angle: -0.5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        width: 50,
                        height: 50,
                        color: baseColor.withBlue(200).withGreen(150),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      right: 15,
                      child: Container(
                        width: 80,
                        height: 30,
                        color: baseColor.withRed(220).withGreen(180),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 40,
                      child: Container(
                        width: 20,
                        height: 70,
                        color: baseColor.withGreen(200).withRed(150),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.edit_document,
              size: 28,
              color: Colors.black.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}

/// 工具类 - 设计辅助
class NovelCardDesignUtils {
  // 获取随机柔和颜色
  static Color getRandomPastelColor(String id, [int? index]) {
    final List<Color> colors = [
      const Color(0xFFBBDEFB), // Light Blue
      const Color(0xFFC8E6C9), // Light Green
      const Color(0xFFFFE0B2), // Light Orange
      const Color(0xFFF8BBD0), // Light Pink
      const Color(0xFFE1BEE7), // Light Purple
      const Color(0xFFB2DFDB), // Light Teal
      const Color(0xFFFFF9C4), // Light Yellow
      const Color(0xFFB3E5FC), // Light Cyan
      const Color(0xFFFFCCBC), // Light Deep Orange
      const Color(0xFFC5CAE9), // Light Indigo
    ];

    // 如果提供了索引，使用索引选择颜色，否则使用ID的哈希码
    if (index != null) {
      return colors[index % colors.length];
    }

    return colors[id.hashCode.abs() % colors.length];
  }
}

/// 波浪裁剪器
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height * 0.8);

    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2.2, size.height * 0.85);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint =
        Offset(size.width - (size.width / 3.5), size.height * 0.65);
    var secondEndPoint = Offset(size.width, size.height * 0.7);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// 网格绘制器
class GridPainter extends CustomPainter {
  GridPainter({
    required this.color,
    required this.lineWidth,
    required this.spacing,
  });
  final Color color;
  final double lineWidth;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // 水平线
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // 垂直线
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldPainter) => false;
}

/// 圆形绘制器
class CirclePainter extends CustomPainter {
  CirclePainter({
    required this.color,
    required this.baseColor,
  });
  final Color color;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 绘制多个同心圆
    for (int i = 5; i > 0; i--) {
      final radius = (size.width / 2) * (i / 5);
      final paint = Paint()
        ..color = i % 2 == 0 ? color : baseColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldPainter) => false;
}
