import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/screens/editor/editor_screen.dart';
import 'package:ainoval/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 继续写作区域组件
class ContinueWritingSection extends StatelessWidget {
  const ContinueWritingSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 如果屏幕非常窄，则直接隐藏此区域
    if (screenWidth < 350) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<NovelListBloc, NovelListState>(
      builder: (context, state) {
        if (state is NovelListLoaded && state.novels.isNotEmpty) {
          final recentNovels = List<NovelSummary>.from(state.novels)
            ..sort((a, b) => b.lastEditTime.compareTo(a.lastEditTime));

          if (recentNovels.length > 3) {
            recentNovels.removeRange(3, recentNovels.length);
          }

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  icon: Icons.edit_note,
                  title: '继续写作',
                ),
                const SizedBox(height: 12),
                // 使用LayoutBuilder获取可用空间
                LayoutBuilder(builder: (context, constraints) {
                  // 根据可用宽度动态计算卡片高度和数量
                  double cardHeight;
                  int visibleCards;

                  if (constraints.maxWidth < 450) {
                    cardHeight = 90.0; // 非常窄的屏幕更小的高度
                    visibleCards = 1; // 只显示一张卡片
                  } else if (constraints.maxWidth < 600) {
                    cardHeight = 110.0; // 窄屏幕稍小的高度
                    visibleCards = 2; // 显示两张卡片
                  } else {
                    cardHeight = 130.0; // 宽屏幕标准高度
                    visibleCards = 3; // 显示所有卡片
                  }

                  // 限制显示的卡片数量
                  final displayNovels =
                      recentNovels.take(visibleCards).toList();

                  return SizedBox(
                    height: cardHeight,
                    child: ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: displayNovels.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final novel = displayNovels[index];

                        // 计算卡片宽度: 窄屏幕下宽度更窄，确保卡片不会过大
                        double cardWidth;
                        if (constraints.maxWidth < 450) {
                          cardWidth =
                              constraints.maxWidth * 0.85; // 非常窄的屏幕使用85%宽度
                        } else if (constraints.maxWidth < 600) {
                          cardWidth = constraints.maxWidth * 0.6; // 窄屏幕使用60%宽度
                        } else {
                          cardWidth = 280.0; // 宽屏幕使用固定宽度
                        }

                        return RecentNovelCard(
                          novel: novel,
                          index: index,
                          cardWidth: cardWidth,
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// 最近编辑过的小说卡片
class RecentNovelCard extends StatelessWidget {
  const RecentNovelCard({
    super.key,
    required this.novel,
    required this.index,
    this.cardWidth = 280.0,
  });

  final NovelSummary novel;
  final int index;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = _getRandomPastelColor(novel.id, index);
    final bool isNarrow = cardWidth < 250;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(left: 4, right: 12),
      child: Card(
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _navigateToEditor(context),
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: Row(
            children: [
              // 封面区域 - 宽度等比例缩放
              SizedBox(
                width: isNarrow
                    ? cardWidth * 0.28
                    : cardWidth * 0.33, // 很窄的卡片封面占比更小
                child: RecentNovelCover(
                    novel: novel, bgColor: bgColor, index: index),
              ),

              // 信息区域
              Expanded(
                child: RecentNovelInfo(
                  novel: novel,
                  isCompact: isNarrow, // 窄卡片使用紧凑布局
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 导航到编辑器
  void _navigateToEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(novel: novel),
      ),
    );
  }

  // 获取动态的柔和颜色
  Color _getRandomPastelColor(String id, int index) {
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

    return colors[index % colors.length];
  }
}

/// 区域标题头组件
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrow = screenWidth < 450;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isNarrow ? 6 : 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: isNarrow ? 16 : 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isNarrow ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ],
      ),
    );
  }
}

/// 最近小说封面组件
class RecentNovelCover extends StatelessWidget {
  const RecentNovelCover({
    super.key,
    required this.novel,
    required this.bgColor,
    required this.index,
  });

  final NovelSummary novel;
  final Color bgColor;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        gradient: LinearGradient(
          colors: [
            bgColor,
            bgColor.withOpacity(0.7),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 根据ID生成不同的抽象设计
          _buildCoverDesign(bgColor, novel.id, index),

          // 进度条
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: novel.completionPercentage,
              backgroundColor: Colors.black12,
              color: theme.colorScheme.primary.withOpacity(0.7),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }

  // 构建封面设计
  Widget _buildCoverDesign(Color baseColor, String id, int index) {
    final designType = index % 5;

    switch (designType) {
      case 0:
        return _buildCircleDesign(baseColor);
      case 1:
        return _buildStripeDesign(baseColor);
      case 2:
        return _buildWaveDesign(baseColor);
      case 3:
        return _buildGridDesign(baseColor);
      default:
        return _buildGeometricDesign(baseColor);
    }
  }

  // 圆形设计
  Widget _buildCircleDesign(Color baseColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _CirclePainter(
            baseColor: baseColor,
            color: baseColor.withOpacity(0.5),
          ),
          size: const Size.square(200),
        ),
        Center(
          child: Icon(
            Icons.auto_stories,
            size: 24,
            color: Colors.black.withOpacity(0.15),
          ),
        ),
      ],
    );
  }

  // 条纹设计
  Widget _buildStripeDesign(Color baseColor) {
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
                    width: 3,
                    color: baseColor.withGreen(180).withOpacity(0.8),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 28,
                  bottom: 20,
                  child: Container(
                    width: 4,
                    color: baseColor.withBlue(180).withOpacity(0.7),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor.withRed(200),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 15,
                  left: 40,
                  child: Container(
                    width: 12,
                    height: 12,
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
            size: 24,
            color: Colors.black.withOpacity(0.15),
          ),
        ),
      ],
    );
  }

  // 波浪设计
  Widget _buildWaveDesign(Color baseColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.5,
          child: ClipPath(
            clipper: _WaveClipper(),
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
            size: 24,
            color: Colors.black.withOpacity(0.15),
          ),
        ),
      ],
    );
  }

  // 网格设计
  Widget _buildGridDesign(Color baseColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _GridPainter(
            color: baseColor.withOpacity(0.5),
            lineWidth: 0.8,
            spacing: 8.0,
          ),
          size: const Size.square(200),
        ),
        Center(
          child: Icon(
            Icons.chrome_reader_mode,
            size: 24,
            color: Colors.black.withOpacity(0.15),
          ),
        ),
      ],
    );
  }

  // 几何设计
  Widget _buildGeometricDesign(Color baseColor) {
    return Stack(
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
                      width: 40,
                      height: 40,
                      color: baseColor.withBlue(200).withGreen(150),
                    ),
                  ),
                  Positioned(
                    bottom: 15,
                    right: 15,
                    child: Container(
                      width: 60,
                      height: 25,
                      color: baseColor.withRed(220).withGreen(180),
                    ),
                  ),
                  Positioned(
                    top: 35,
                    right: 30,
                    child: Container(
                      width: 15,
                      height: 50,
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
            size: 24,
            color: Colors.black.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}

/// 最近小说信息组件
class RecentNovelInfo extends StatelessWidget {
  const RecentNovelInfo({
    super.key,
    required this.novel,
    this.isCompact = false,
  });

  final NovelSummary novel;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(isCompact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            novel.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 13 : 16,
            ),
          ),
          SizedBox(height: isCompact ? 3 : 6),

          // 在紧凑模式下，只显示时间或系列（优先显示系列）
          if (isCompact) ...[
            novel.seriesName.isNotEmpty
                ? _buildSeriesInfo(theme)
                : _buildTimeInfo(theme),

            const SizedBox(height: 3),

            // 显示进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: novel.completionPercentage,
                backgroundColor: Colors.grey.shade200,
                color: theme.colorScheme.primary,
                minHeight: 2,
              ),
            ),
          ] else ...[
            // 标准模式下显示更多信息
            _buildTimeInfo(theme),
            const SizedBox(height: 4),

            Row(
              children: [
                Icon(
                  Icons.text_fields,
                  size: 12,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${novel.wordCount} 字',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (novel.seriesName.isNotEmpty) ...[
                  const SizedBox(width: 8),
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
              ],
            ),

            const SizedBox(height: 6),

            // 标准模式下的进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: novel.completionPercentage,
                backgroundColor: Colors.grey.shade200,
                color: theme.colorScheme.primary,
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 2),

            // 只在标准模式下显示完成度文本
            Text(
              '完成度: ${(novel.completionPercentage * 100).toInt()}%',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建系列信息组件
  Widget _buildSeriesInfo(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.bookmark_border,
          size: 10,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            novel.seriesName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  // 构建时间信息组件
  Widget _buildTimeInfo(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: isCompact ? 10 : 12,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            isCompact
                ? DateFormatter.formatRelative(novel.lastEditTime)
                : '上次: ${DateFormatter.formatRelative(novel.lastEditTime)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 9 : 11,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  // 构建字数信息组件
  Widget _buildWordCountInfo(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.text_fields,
          size: 10,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 3),
        Text(
          '${novel.wordCount} 字',
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// 波浪裁剪器
class _WaveClipper extends CustomClipper<Path> {
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

// 网格绘制器
class _GridPainter extends CustomPainter {
  final Color color;
  final double lineWidth;
  final double spacing;

  _GridPainter({
    required this.color,
    required this.lineWidth,
    required this.spacing,
  });

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

// 圆形绘制器
class _CirclePainter extends CustomPainter {
  final Color color;
  final Color baseColor;

  _CirclePainter({
    required this.color,
    required this.baseColor,
  });

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
