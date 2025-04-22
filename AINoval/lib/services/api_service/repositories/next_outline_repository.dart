import 'package:ainoval/models/next_outline/next_outline_dto.dart';
import 'package:ainoval/models/next_outline/outline_generation_chunk.dart';

/// 剧情推演仓库接口
abstract class NextOutlineRepository {
  /// 流式生成剧情大纲
  /// 
  /// [novelId] 小说ID
  /// [request] 生成请求
  Stream<OutlineGenerationChunk> generateNextOutlinesStream(
    String novelId, 
    GenerateNextOutlinesRequest request
  );
  
  /// 重新生成单个剧情大纲选项
  /// 
  /// [novelId] 小说ID
  /// [request] 重新生成请求
  Stream<OutlineGenerationChunk> regenerateOutlineOption(
    String novelId, 
    RegenerateOptionRequest request
  );
  
  /// 保存选中的剧情大纲
  /// 
  /// [novelId] 小说ID
  /// [request] 保存请求
  Future<SaveNextOutlineResponse> saveNextOutline(
    String novelId, 
    SaveNextOutlineRequest request
  );
}
