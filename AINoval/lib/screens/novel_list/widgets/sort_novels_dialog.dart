import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SortNovelsDialog extends StatelessWidget {
  const SortNovelsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final currentSortOption = (context.read<NovelListBloc>().state as NovelListLoaded).sortOption;

    return AlertDialog(
      title: const Text('排序方式'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: SortOption.values.map((option) {
          return RadioListTile<SortOption>(
            title: Text(_getSortOptionText(option)),
            value: option,
            groupValue: currentSortOption,
            onChanged: (SortOption? value) {
              if (value != null) {
                context.read<NovelListBloc>().add(SortNovels(sortOption: value));
                Navigator.of(context).pop();
              }
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  String _getSortOptionText(SortOption option) {
    switch (option) {
      case SortOption.lastEdited:
        return '最后编辑';
      case SortOption.title:
        return '标题';
      case SortOption.wordCount:
        return '字数';
      case SortOption.creationDate:
        return '创建日期';
      case SortOption.actCount:
        return '卷数';
      case SortOption.chapterCount:
        return '章节数';
      case SortOption.sceneCount:
        return '场景数';
      default:
        return '';
    }
  }
} 