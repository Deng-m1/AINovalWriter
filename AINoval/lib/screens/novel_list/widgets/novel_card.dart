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
  
  // 构建网格视图中的卡片
  Widget _buildGridCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  image: novel.coverImagePath.isNotEmpty
                      ? DecorationImage(
                          image: AssetImage(novel.coverImagePath),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: novel.coverImagePath.isEmpty
                    ? const Center(child: Icon(Icons.book, size: 50))
                    : null,
              ),
            ),
            
            // 信息区域
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    novel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // 系列名称（如果有）
                  if (novel.seriesName.isNotEmpty)
                    Text(
                      novel.seriesName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 字数统计
                      Text(
                        '${novel.wordCount} 字',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      
                      // 最后编辑时间
                      Text(
                        DateFormatter.formatRelative(novel.lastEditTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 进度条
                  LinearProgressIndicator(
                    value: novel.completionPercentage,
                    backgroundColor: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建列表视图中的卡片
  Widget _buildListCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 封面图
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                  image: novel.coverImagePath.isNotEmpty
                      ? DecorationImage(
                          image: AssetImage(novel.coverImagePath),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: novel.coverImagePath.isEmpty
                    ? const Icon(Icons.book, size: 30)
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // 信息区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      novel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // 系列名称（如果有）
                    if (novel.seriesName.isNotEmpty)
                      Text(
                        novel.seriesName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // 字数和时间
                    Row(
                      children: [
                        Text(
                          '${novel.wordCount} 字',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '上次编辑于 ${DateFormatter.formatRelative(novel.lastEditTime)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 进度条
                    LinearProgressIndicator(
                      value: novel.completionPercentage,
                      backgroundColor: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
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