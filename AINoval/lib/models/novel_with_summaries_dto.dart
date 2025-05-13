import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/models/scene_summary_dto.dart';
import 'package:ainoval/utils/logger.dart';

/// 包含场景摘要的小说DTO
/// 用于映射服务器返回的包含场景摘要的小说结构
class NovelWithSummariesDto {
  final Novel novel;
  final Map<String, List<SceneSummaryDto>> sceneSummariesByChapter;

  NovelWithSummariesDto({
    required this.novel,
    required this.sceneSummariesByChapter,
  });

  /// 从JSON创建NovelWithSummariesDto实例
  factory NovelWithSummariesDto.fromJson(Map<String, dynamic> json) {
    try {
      AppLogger.i('NovelWithSummariesDto', '开始解析小说和场景摘要数据');
      
      // 确保novel字段存在且是Map类型
      if (!json.containsKey('novel') || !(json['novel'] is Map<String, dynamic>)) {
        AppLogger.w('NovelWithSummariesDto', '返回数据中缺少novel字段或格式不正确');
        throw FormatException('返回数据缺少novel字段或格式不正确');
      }
      
      // 解析小说基本信息
      final novelJson = json['novel'] as Map<String, dynamic>;
      
      // 确保结构字段正确，特别是acts字段
      if (novelJson.containsKey('structure') && novelJson['structure'] is Map) {
        final structureMap = novelJson['structure'] as Map<String, dynamic>;
        
        // 检查并确保acts字段是List类型
        if (structureMap.containsKey('acts') && !(structureMap['acts'] is List)) {
          AppLogger.w('NovelWithSummariesDto', 'novel.structure.acts不是列表类型，正在修正');
          structureMap['acts'] = <Map<String, dynamic>>[];
        }
      } else {
        // 如果没有structure字段或不是Map类型，添加一个空的structure
        novelJson['structure'] = {'acts': <Map<String, dynamic>>[]};
        AppLogger.w('NovelWithSummariesDto', '返回数据中缺少novel.structure字段，已添加空结构');
      }
      
      // 解析Novel
      final novel = Novel.fromJson(novelJson);
      AppLogger.i('NovelWithSummariesDto', '小说基本信息解析成功: ${novel.title}');

      // 解析场景摘要
      final sceneSummariesMap = <String, List<SceneSummaryDto>>{};
      
      // 检查sceneSummariesByChapter字段是否存在且是Map类型
      if (json.containsKey('sceneSummariesByChapter') && json['sceneSummariesByChapter'] is Map) {
        final summariesData = json['sceneSummariesByChapter'] as Map<String, dynamic>;
        
        summariesData.forEach((chapterId, summariesList) {
          if (summariesList is List) {
            try {
              final sceneList = <SceneSummaryDto>[];
              
              for (var summaryItem in summariesList) {
                if (summaryItem is Map<String, dynamic>) {
                  sceneList.add(SceneSummaryDto.fromJson(summaryItem));
                } else {
                  AppLogger.w('NovelWithSummariesDto', '场景摘要数据格式错误: $summaryItem');
                }
              }
              
              if (sceneList.isNotEmpty) {
                sceneSummariesMap[chapterId] = sceneList;
              }
            } catch (e) {
              AppLogger.e('NovelWithSummariesDto', '解析章节 $chapterId 的场景摘要失败', e);
            }
          } else {
            AppLogger.w('NovelWithSummariesDto', '章节 $chapterId 的场景摘要不是列表格式');
          }
        });
      } else {
        AppLogger.w('NovelWithSummariesDto', '返回数据中缺少sceneSummariesByChapter字段或格式不正确');
      }

      AppLogger.i('NovelWithSummariesDto', '解析完成，共有 ${sceneSummariesMap.length} 个章节包含场景摘要');
      return NovelWithSummariesDto(
        novel: novel,
        sceneSummariesByChapter: sceneSummariesMap,
      );
    } catch (e) {
      AppLogger.e('NovelWithSummariesDto', '从JSON创建NovelWithSummariesDto实例失败', e);
      
      // 尝试创建一个空的对象，确保不会完全失败
      try {
        if (json.containsKey('novel') && json['novel'] is Map<String, dynamic>) {
          // 尝试只解析小说部分
          final novel = Novel.fromJson(json['novel'] as Map<String, dynamic>);
          return NovelWithSummariesDto(
            novel: novel,
            sceneSummariesByChapter: {},
          );
        }
      } catch (_) {
        // 如果还是失败，创建一个完全空的对象
        AppLogger.e('NovelWithSummariesDto', '尝试创建备用对象也失败');
      }
      
      rethrow;
    }
  }

  /// 将DTO中的场景摘要信息合并到Novel模型中
  Novel mergeSceneSummariesToNovel() {
    try {
      // 创建小说的副本，避免修改原始模型
      Novel updatedNovel = novel;

      // 遍历小说中的卷和章节
      final List<Act> updatedActs = novel.acts.map((act) {
        final List<Chapter> updatedChapters = act.chapters.map((chapter) {
          // 检查这个章节是否有场景摘要
          if (sceneSummariesByChapter.containsKey(chapter.id)) {
            final summaries = sceneSummariesByChapter[chapter.id]!;
            
            // 根据场景摘要创建场景对象
            final List<Scene> scenes = summaries.map((summaryDto) {
              return Scene(
                id: summaryDto.id,
                content: '', // 摘要模式下不需要完整内容
                wordCount: summaryDto.wordCount,
                summary: Summary(
                  id: '${summaryDto.id}_summary',
                  content: summaryDto.summary,
                ),
                lastEdited: summaryDto.updatedAt,
                title: summaryDto.title,
                chapterId: summaryDto.chapterId,
              );
            }).toList();
            
            // 创建更新后的章节
            return chapter.copyWith(scenes: scenes);
          }
          
          // 如果没有摘要信息，保持原样
          return chapter;
        }).toList();
        
        // 创建更新后的卷
        return act.copyWith(chapters: updatedChapters);
      }).toList();
      
      // 创建更新后的小说
      updatedNovel = updatedNovel.copyWith(acts: updatedActs);
      
      return updatedNovel;
    } catch (e) {
      AppLogger.e('NovelWithSummariesDto', '合并场景摘要到Novel模型失败', e);
      return novel;  // 出错时返回原始小说模型
    }
  }
} 