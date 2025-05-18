import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ainoval/models/novel_structure.dart'; // Novel 模型
import 'package:ainoval/services/api_service/repositories/editor_repository.dart'; // 引入 Repository
import 'package:ainoval/utils/logger.dart';

part 'sidebar_event.dart';
part 'sidebar_state.dart';

class SidebarBloc extends Bloc<SidebarEvent, SidebarState> {
  final EditorRepository _editorRepository; // 依赖注入 EditorRepository

  SidebarBloc({required EditorRepository editorRepository})
      : _editorRepository = editorRepository,
        super(SidebarInitial()) {
    on<LoadNovelStructure>(_onLoadNovelStructure);
  }

  Future<void> _onLoadNovelStructure(
      LoadNovelStructure event, Emitter<SidebarState> emit) async {
    emit(SidebarLoading());
    try {
      AppLogger.i('SidebarBloc', '开始加载小说结构和场景摘要: ${event.novelId}');
      
      // 使用专门的API获取包含场景摘要的小说结构
      final novelWithSummaries = await _editorRepository.getNovelWithSceneSummaries(event.novelId, readOnly: true);
      
      if (novelWithSummaries != null) {
        AppLogger.i('SidebarBloc', '成功加载小说结构和场景摘要');
        
        // 记录每个章节的摘要信息，用于调试
        int chaptersWithScene = 0;
        int totalScenes = 0;
        for (final act in novelWithSummaries.acts) {
          for (final chapter in act.chapters) {
            if (chapter.scenes.isNotEmpty) {
              chaptersWithScene++;
              totalScenes += chapter.scenes.length;
            }
          }
        }
        
        AppLogger.i('SidebarBloc', '小说结构信息: 共${novelWithSummaries.acts.length}卷, '
            '${chaptersWithScene}章含有场景, 总计${totalScenes}个场景');
            
        emit(SidebarLoaded(novelStructure: novelWithSummaries));
      } else {
        AppLogger.e('SidebarBloc', '加载小说结构和场景摘要失败: 返回null');
        emit(const SidebarError(message: '无法加载小说结构'));
      }
    } catch (e) {
      AppLogger.e('SidebarBloc', '加载小说结构和场景摘要失败', e);
      emit(SidebarError(message: '加载小说结构失败: ${e.toString()}'));
    }
  }
} 