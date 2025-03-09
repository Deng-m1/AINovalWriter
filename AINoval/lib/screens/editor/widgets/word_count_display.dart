import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:ainoval/utils/word_count_analyzer.dart';

class WordCountDisplay extends StatefulWidget {
  
  const WordCountDisplay({
    super.key,
    required this.controller,
  });
  final QuillController controller;

  @override
  State<WordCountDisplay> createState() => _WordCountDisplayState();
}

class _WordCountDisplayState extends State<WordCountDisplay> {
  WordCountStats _stats = const WordCountStats(
    words: 0,
    charactersWithSpaces: 0,
    charactersNoSpaces: 0,
    paragraphs: 0,
    readTimeMinutes: 0,
  );
  
  @override
  void initState() {
    super.initState();
    _updateStats();
    
    // 监听内容变化
    widget.controller.document.changes.listen((_) {
      _updateStats();
    });
  }
  
  void _updateStats() {
    final text = widget.controller.document.toPlainText();
    final stats = WordCountAnalyzer.analyze(text);
    
    setState(() {
      _stats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showStatsDialog(context),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '${_stats.words}字',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  // 显示详细统计信息对话框
  void _showStatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('字数统计'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('总字数', '${_stats.words}'),
            _buildStatRow('字符数（含空格）', '${_stats.charactersWithSpaces}'),
            _buildStatRow('字符数（不含空格）', '${_stats.charactersNoSpaces}'),
            _buildStatRow('段落数', '${_stats.paragraphs}'),
            _buildStatRow('预计阅读时间', '${_stats.readTimeMinutes}分钟'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  // 构建统计行
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
} 