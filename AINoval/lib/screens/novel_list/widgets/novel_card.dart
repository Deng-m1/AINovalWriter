import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/utils/date_formatter.dart';
import 'package:flutter/material.dart';

class NovelCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return isGridView ? _buildGridCard(context) : _buildListCard(context);
  }

  // 构建网格视图中的卡片 - 更新后的设计
  Widget _buildGridCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图 - 使用 Expanded 替代 AspectRatio
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _getRandomPastelColor(), // 随机柔和颜色背景
                ),
                child: Stack(
                  children: [
                    // 根据原型图生成随机设计元素
                    if (novel.id.hashCode % 2 == 0)
                      _buildDesignOne()
                    else
                      _buildDesignTwo(),
                  ],
                ),
              ),
            ),
            
            // 信息区域 - 简化版本
            Padding(
              padding: const EdgeInsets.all(8), // 从 10 减小到 8
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    novel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13, // 从 14 减小到 13
                    ),
                  ),
                  const SizedBox(height: 1), // 从 2 减小到 1
                  Text(
                    DateFormatter.formatRelative(novel.lastEditTime),
                    style: TextStyle(
                      fontSize: 10, // 从 11 减小到 10
                      color: Colors.grey.shade600,
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
  
  // 第一种设计模式（矩形条纹）
  Widget _buildDesignOne() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.teal.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade400,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 第二种设计模式（垂直条纹）
  Widget _buildDesignTwo() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 4,
                        height: 60,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade400,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 获取随机柔和颜色
  Color _getRandomPastelColor() {
    final List<Color> colors = [
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.pink.shade50,
      Colors.purple.shade50,
      Colors.teal.shade50,
      Colors.amber.shade50,
      Colors.cyan.shade50,
      Colors.deepOrange.shade50,
      Colors.indigo.shade50,
    ];
    
    return colors[novel.id.hashCode % colors.length];
  }

  // 构建列表视图中的卡片 - 更新后的设计
  Widget _buildListCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10), // 从 12 减小到 10
      elevation: 1.5, // 从 2 减小到 1.5
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6), // 从 8 减小到 6
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6), // 从 8 减小到 6
        child: Padding(
          padding: const EdgeInsets.all(10), // 从 12 减小到 10
          child: Row(
            children: [
              // 封面图 - 简洁版
              Container(
                width: 40, // 从 50 减小到 40
                height: 55, // 从 70 减小到 55
                decoration: BoxDecoration(
                  color: _getRandomPastelColor(),
                  borderRadius: BorderRadius.circular(3), // 从 4 减小到 3
                ),
                child: Center(
                  child: novel.id.hashCode % 2 == 0
                      ? Icon(Icons.book, color: Colors.grey.shade400, size: 20) // 从 24 减小到 20
                      : Icon(Icons.auto_stories, color: Colors.grey.shade400, size: 20), // 从 24 减小到 20
                ),
              ),

              const SizedBox(width: 12), // 从 16 减小到 12

              // 信息区域 - 简化版本
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14, // 从 15 减小到 14
                      ),
                    ),

                    if (novel.seriesName.isNotEmpty) ...[
                      const SizedBox(height: 2), // 从 4 减小到 2
                      Text(
                        novel.seriesName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11, // 从 12 减小到 11
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],

                    const SizedBox(height: 6), // 从 8 减小到 6
                    Text(
                      DateFormatter.formatRelative(novel.lastEditTime),
                      style: TextStyle(
                        fontSize: 11, // 从 12 减小到 11
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
