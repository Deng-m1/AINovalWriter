import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/base/mock_client.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart';
import 'package:ainoval/services/mock_data_service.dart';

/// 小说仓库实现
class NovelRepositoryImpl implements NovelRepository {
  final ApiClient _apiClient;
  final MockClient _mockClient;
  final MockDataService _mockService;
  
  NovelRepositoryImpl({
    ApiClient? apiClient,
    MockClient? mockClient,
    MockDataService? mockService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _mockClient = mockClient ?? MockClient(),
       _mockService = mockService ?? MockDataService();
  
  /// 获取当前用户ID
  String? get _currentUserId => AppConfig.userId;
  
  /// 获取所有小说
  @override
  Future<List<Novel>> fetchNovels() async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      return _mockService.getAllNovels();
    }
    
    try {
      // 获取当前用户ID
      final userId = _currentUserId;
      if (userId == null) {
        throw ApiException(401, '未登录或用户ID不可用');
      }
      
      // 根据用户ID获取小说列表
      final data = await _apiClient.get('/novels/author/$userId');
      return _convertToNovelList(data);
    } catch (e) {
      print('获取小说列表失败: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getAllNovels();
    }
  }
  
  /// 获取单个小说
  @override
  Future<Novel> fetchNovel(String id) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      final novel = _mockService.getNovel(id);
      if (novel != null) {
        return novel;
      }
      throw ApiException(404, '在模拟数据中未找到小说');
    }
    
    try {
      final data = await _apiClient.get('/novels/$id');
      final novel = _convertToSingleNovel(data);
      
      if (novel == null) {
        throw ApiException(404, '小说不存在或数据格式不正确');
      }
      
      return novel;
    } catch (e) {
      print('获取小说详情失败: $e');
      // 如果API请求失败，回退到模拟数据
      final novel = _mockService.getNovel(id);
      if (novel != null) {
        return novel;
      }
      throw ApiException(404, '小说不存在');
    }
  }
  
  /// 创建小说
  @override
  Future<Novel> createNovel(String title, {String? description, String? coverImage}) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 创建模拟小说
      final novel = _mockService.createNovel(title);
      return novel;
    }
    
    try {
      // 获取当前用户ID
      final userId = _currentUserId;
      if (userId == null) {
        throw ApiException(401, '未登录或用户ID不可用');
      }
      
      // 准备请求体
      final body = {
        'title': title,
        'description': description ?? '',
        'coverImage': coverImage,
        'author': {
          'id': userId,
          'username': AppConfig.username ?? 'user'
        },
        'status': 'draft',
        'structure': {
          'acts': []
        },
        'metadata': {
          'wordCount': 0,
          'readTime': 0,
          'version': 1
        }
      };
      
      // 发送创建请求
      final data = await _apiClient.post('/novels', data: body);
      final novel = _convertToSingleNovel(data);
      
      if (novel == null) {
        throw ApiException(-1, '创建小说失败：服务器返回的数据格式不正确');
      }
      
      return novel;
    } catch (e) {
      print('创建小说失败: $e');
      throw ApiException(-1, '创建小说失败: $e');
    }
  }
  
  /// 根据作者ID获取小说列表
  @override
  Future<List<Novel>> fetchNovelsByAuthor(String authorId) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      return _mockService.getAllNovels();
    }
    
    try {
      final data = await _apiClient.get('/novels/author/$authorId');
      return _convertToNovelList(data);
    } catch (e) {
      print('获取作者小说列表失败: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getAllNovels();
    }
  }
  
  /// 搜索小说
  @override
  Future<List<Novel>> searchNovelsByTitle(String title) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      return _mockService.getAllNovels().where(
        (novel) => novel.title.toLowerCase().contains(title.toLowerCase())
      ).toList();
    }
    
    try {
      final data = await _apiClient.get('/novels/search', queryParameters: {'title': title});
      final novels = _convertToNovelList(data);
      
      // 如果搜索结果为空，回退到模拟数据
      if (novels.isEmpty) {
        return _mockService.getAllNovels().where(
          (novel) => novel.title.toLowerCase().contains(title.toLowerCase())
        ).toList();
      }
      
      return novels;
    } catch (e) {
      print('搜索小说失败: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getAllNovels().where(
        (novel) => novel.title.toLowerCase().contains(title.toLowerCase())
      ).toList();
    }
  }
  
  /// 更新小说
  @override
  Future<Novel> updateNovel(Novel novel) async {
    // 如果使用模拟数据，直接更新
    if (AppConfig.shouldUseMockData) {
      _mockService.updateNovel(novel);
      return novel;
    }
    
    try {
      // 将前端模型转换为后端模型
      final novelJson = {
        'id': novel.id,
        'title': novel.title,
        'coverImage': novel.coverImagePath,
        'structure': {
          'acts': novel.acts.map((act) => {
            'id': act.id,
            'title': act.title,
            'order': act.order,
            'chapters': act.chapters.map((chapter) => {
              'id': chapter.id,
              'title': chapter.title,
              'order': chapter.order,
            }).toList(),
          }).toList(),
        },
      };
      
      final data = await _apiClient.put('/novels/${novel.id}', data: novelJson);
      final updatedNovel = _convertToSingleNovel(data);
      
      if (updatedNovel == null) {
        print('警告：更新小说返回的数据格式不正确，使用原始小说数据');
        return novel;
      }
      
      return updatedNovel;
    } catch (e) {
      print('更新小说失败: $e');
      // 如果API请求失败，更新模拟数据
      _mockService.updateNovel(novel);
      return novel;
    }
  }
  
  /// 删除小说
  @override
  Future<void> deleteNovel(String id) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      return;
    }
    
    try {
      await _apiClient.delete('/novels/$id');
    } catch (e) {
      print('删除小说失败: $e');
      throw ApiException(-1, '删除小说失败: $e');
    }
  }
  
  /// 获取场景内容
  @override
  Future<Scene> fetchSceneContent(
    String novelId, 
    String actId, 
    String chapterId,
    String sceneId
  ) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      final scene = _mockService.getSceneContent(novelId, actId, chapterId, sceneId);
      if (scene != null) {
        return scene;
      }
      return Scene.createEmpty();
    }
    
    try {
      // 使用新的API路径获取场景内容
      final data = await _apiClient.get('/novels/$novelId/chapters/$chapterId/scenes/$sceneId');
      return _convertToSceneModel(data);
    } catch (e) {
      print('获取场景内容失败: $e');
      
      // 尝试通过章节获取场景列表，然后找到对应的场景
      try {
        final data = await _apiClient.get('/novels/$novelId/chapters/$chapterId/scenes');
        if (data is List && data.isNotEmpty) {
          // 尝试在列表中找到对应的场景
          for (final sceneData in data) {
            if (sceneData['id'] == sceneId) {
              return _convertToSceneModel(sceneData);
            }
          }
          // 如果找不到对应的场景，使用第一个场景
          return _convertToSceneModel(data[0]);
        }
      } catch (e2) {
        print('获取章节场景列表失败: $e2');
      }
      
      // 如果API请求失败，回退到模拟数据
      final scene = _mockService.getSceneContent(novelId, actId, chapterId, sceneId);
      if (scene != null) {
        return scene;
      }
      return Scene.createEmpty();
    }
  }
  
  /// 更新场景内容
  @override
  Future<Scene> updateSceneContent(
    String novelId, 
    String actId, 
    String chapterId, 
    String sceneId,
    Scene scene
  ) async {
    // 如果使用模拟数据，直接更新
    if (AppConfig.shouldUseMockData) {
      _mockService.updateSceneContent(novelId, actId, chapterId, sceneId, scene);
      return scene;
    }
    
    try {
      // 将前端模型转换为后端模型
      final sceneJson = {
        'id': scene.id,
        'novelId': novelId,
        'chapterId': chapterId,
        'content': scene.content,
        'summary': scene.summary.content,
        'wordCount': scene.wordCount,
        'title': '场景 ${scene.id}', // 添加标题
      };
      
      // 使用新的API路径更新场景内容
      final data = await _apiClient.put('/novels/$novelId/chapters/$chapterId/scenes/$sceneId', data: sceneJson);
      return _convertToSceneModel(data);
    } catch (e) {
      print('更新场景内容失败: $e');
      
      // 如果更新失败，尝试创建场景
      try {
        final sceneJson = {
          'id': scene.id,
          'novelId': novelId,
          'chapterId': chapterId,
          'content': scene.content,
          'summary': scene.summary.content,
          'wordCount': scene.wordCount,
          'title': '场景 ${scene.id}', // 添加标题
        };
        
        final data = await _apiClient.post('/novels/$novelId/chapters/$chapterId/scenes', data: sceneJson);
        return _convertToSceneModel(data);
      } catch (e2) {
        print('创建场景失败: $e2');
        
        // 如果API请求失败，更新模拟数据
        _mockService.updateSceneContent(novelId, actId, chapterId, sceneId, scene);
        return scene;
      }
    }
  }
  
  /// 更新摘要内容
  @override
  Future<Summary> updateSummary(
    String novelId, 
    String actId, 
    String chapterId,
    String sceneId,
    Summary summary
  ) async {
    // 如果使用模拟数据，直接更新
    if (AppConfig.shouldUseMockData) {
      _mockService.updateSummary(novelId, actId, chapterId, sceneId, summary);
      return summary;
    }
    
    try {
      // 获取当前场景
      final scene = await fetchSceneContent(novelId, actId, chapterId, sceneId);
      
      // 更新摘要
      final updatedScene = await updateSceneContent(
        novelId, 
        actId, 
        chapterId, 
        sceneId,
        scene.copyWith(summary: summary),
      );
      
      return updatedScene.summary;
    } catch (e) {
      print('更新摘要失败: $e');
      // 如果API请求失败，更新模拟数据
      _mockService.updateSummary(novelId, actId, chapterId, sceneId, summary);
      return summary;
    }
  }
  
  /// 处理WebFlux流式响应数据，统一处理数据类型
  dynamic _handleFluxResponse(dynamic data) {
    if (data == null) return null;
    
    // 如果是列表类型，确保列表中的每个元素都是Map类型
    if (data is List) {
      return data;
    } 
    // 如果是Map类型，直接返回
    else if (data is Map<String, dynamic>) {
      return data;
    } 
    // 其他类型，记录警告并返回null
    else {
      print('警告：API返回了意外的数据类型: ${data.runtimeType}');
      return null;
    }
  }
  
  /// 将WebFlux响应转换为Novel列表
  List<Novel> _convertToNovelList(dynamic data) {
    final processedData = _handleFluxResponse(data);
    
    if (processedData == null) {
      return [];
    }
    
    if (processedData is List) {
      // 处理列表数据
      return processedData.map((item) {
        if (item is Map<String, dynamic>) {
          return _convertToNovelModel(item);
        } else {
          print('警告：列表中的项目不是有效的小说数据: $item');
          // 返回一个错误占位小说对象
          final now = DateTime.now();
          return Novel(
            id: 'error_${now.millisecondsSinceEpoch}',
            title: '数据错误',
            createdAt: now,
            updatedAt: now,
            acts: [],
          );
        }
      }).toList();
    } else if (processedData is Map<String, dynamic>) {
      // 处理单个对象
      return [_convertToNovelModel(processedData)];
    }
    
    return [];
  }
  
  /// 将WebFlux响应转换为单个Novel
  Novel? _convertToSingleNovel(dynamic data) {
    final processedData = _handleFluxResponse(data);
    
    if (processedData == null) {
      return null;
    }
    
    if (processedData is List && processedData.isNotEmpty) {
      // 如果是列表，取第一个元素
      final firstItem = processedData.first;
      if (firstItem is Map<String, dynamic>) {
        return _convertToNovelModel(firstItem);
      }
    } else if (processedData is Map<String, dynamic>) {
      // 如果是单个对象，直接转换
      return _convertToNovelModel(processedData);
    }
    
    return null;
  }
  
  /// 将后端Novel模型转换为前端Novel模型
  Novel _convertToNovelModel(Map<String, dynamic> json) {
    // 提取结构信息
    final structure = json['structure'] as Map<String, dynamic>? ?? {};
    final acts = (structure['acts'] as List?)?.map((actJson) {
      final act = actJson as Map<String, dynamic>;
      final chapters = (act['chapters'] as List?)?.map((chapterJson) {
        final chapter = chapterJson as Map<String, dynamic>;
        return Chapter(
          id: chapter['id'],
          title: chapter['title'],
          order: chapter['order'],
          scenes: [], // 场景需要单独获取
        );
      }).toList() ?? [];
      
      return Act(
        id: act['id'],
        title: act['title'],
        order: act['order'],
        chapters: chapters,
      );
    }).toList() ?? [];
    
    // 提取元数据
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    
    // 解析创建时间和更新时间
    DateTime createdAt;
    DateTime updatedAt;
    
    if (json.containsKey('createdAt')) {
      createdAt = _parseDateTime(json['createdAt']);
    } else {
      createdAt = DateTime.now();
    }
    
    if (json.containsKey('updatedAt')) {
      updatedAt = _parseDateTime(json['updatedAt']);
    } else {
      updatedAt = createdAt;
    }
    
    return Novel(
      id: json['id'],
      title: json['title'],
      coverImagePath: json['coverImage'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      acts: acts,
    );
  }
  
  /// 将后端Scene模型转换为前端Scene模型
  Scene _convertToSceneModel(Map<String, dynamic> json) {
    // 解析更新时间
    DateTime lastEdited;
    if (json.containsKey('updatedAt')) {
      lastEdited = _parseDateTime(json['updatedAt']);
    } else {
      lastEdited = DateTime.now();
    }
    
    final sceneId = json['id'] ?? 'scene_${DateTime.now().millisecondsSinceEpoch}';
    
    return Scene(
      id: sceneId,
      content: json['content'] ?? '',
      wordCount: json['wordCount'] ?? 0,
      summary: Summary(
        id: 'summary_$sceneId',
        content: json['summary'] ?? '',
      ),
      lastEdited: lastEdited,
    );
  }
  
  /// 解析Java LocalDateTime或Instant为Dart DateTime
  DateTime _parseDateTime(dynamic dateTimeValue) {
    if (dateTimeValue is String) {
      // 如果是字符串格式，直接解析
      return DateTime.parse(dateTimeValue);
    } else if (dateTimeValue is List) {
      // 如果是Java LocalDateTime数组格式 [year, month, day, hour, minute, second, nanoOfSecond]
      try {
        final year = dateTimeValue[0] as int;
        final month = dateTimeValue[1] as int;
        final day = dateTimeValue[2] as int;
        final hour = dateTimeValue.length > 3 ? dateTimeValue[3] as int : 0;
        final minute = dateTimeValue.length > 4 ? dateTimeValue[4] as int : 0;
        final second = dateTimeValue.length > 5 ? dateTimeValue[5] as int : 0;
        
        // 使用标准DateTime，不使用chrono库
        return DateTime(
          year,
          month,
          day,
          hour,
          minute,
          second,
        );
      } catch (e) {
        print('解析LocalDateTime失败: $e, 值: $dateTimeValue');
        // 解析失败时返回当前时间
        return DateTime.now();
      }
    } else if (dateTimeValue is double) {
      // 如果是Instant格式的时间戳（秒为单位）
      try {
        // 将秒转换为毫秒
        final milliseconds = (dateTimeValue * 1000).round();
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      } catch (e) {
        print('解析Instant时间戳失败: $e, 值: $dateTimeValue');
        return DateTime.now();
      }
    } else if (dateTimeValue is int) {
      // 如果是毫秒时间戳
      try {
        return DateTime.fromMillisecondsSinceEpoch(dateTimeValue);
      } catch (e) {
        print('解析毫秒时间戳失败: $e, 值: $dateTimeValue');
        return DateTime.now();
      }
    } else {
      // 其他情况返回当前时间
      print('未知的日期时间格式: $dateTimeValue (${dateTimeValue.runtimeType})');
      return DateTime.now();
    }
  }
}