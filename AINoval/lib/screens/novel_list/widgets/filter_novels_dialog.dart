import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FilterNovelsDialog extends StatefulWidget {
  const FilterNovelsDialog({super.key});

  @override
  State<FilterNovelsDialog> createState() => _FilterNovelsDialogState();
}

class _FilterNovelsDialogState extends State<FilterNovelsDialog> {
  late FilterOption _currentFilterOption;
  final TextEditingController _seriesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentFilterOption = (context.read<NovelListBloc>().state as NovelListLoaded).filterOption;
    _seriesController.text = _currentFilterOption.series ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('过滤选项'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('按系列过滤:'),
            TextField(
              controller: _seriesController,
              decoration: const InputDecoration(
                hintText: '输入系列名称',
              ),
              onChanged: (value) {
                // 用户输入时可以实时更新预览，或者在点击应用时更新
              },
            ),
            // 在这里可以添加更多过滤条件，例如字数范围、完成状态等
            // SwitchListTile for completion status, RangeSlider for word count, etc.
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final newFilterOption = FilterOption(
              series: _seriesController.text.trim().isNotEmpty ? _seriesController.text.trim() : null,
              // 其他过滤条件从UI元素获取
            );
            context.read<NovelListBloc>().add(FilterNovels(filterOption: newFilterOption));
            Navigator.of(context).pop();
          },
          child: const Text('应用'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _seriesController.dispose();
    super.dispose();
  }
} 