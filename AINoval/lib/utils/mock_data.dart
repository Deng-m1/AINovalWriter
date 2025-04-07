import 'dart:math';

import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:uuid/uuid.dart';

class MockData {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();
  
  // 生成随机小说列表
  static List<NovelSummary> getNovels() {
    final List<NovelSummary> novels = [];
    
    // 创建测试用例
    novels.add(
      NovelSummary(
        id: '1',
        title: '真有钱了怎么办',
        lastEditTime: DateTime.now().subtract(const Duration(minutes: 30)),
        wordCount: 45709,
        seriesName: '',
        completionPercentage: 0.7,
        coverUrl: '',
      ),
    );
    
    // 添加更多随机小说
    final titles = [
      '风吹稻浪',
      '月光下的守望者',
      '城市边缘',
      '时间的形状',
      '梦境迷宫',
      '蓝色海岸线',
      '记忆碎片',
      '星际旅行指南',
      '未知的边界',
      '寂静花园',
    ];
    
    final seriesNames = ['', '奇幻世界', '都市传说', '科幻空间', '历史长河'];
    
    for (int i = 0; i < 11; i++) {
      final title = titles[_random.nextInt(titles.length)];
      final seriesName = _random.nextBool() 
          ? seriesNames[_random.nextInt(seriesNames.length)]
          : '';
      final daysAgo = _random.nextInt(30);
      
      novels.add(
        NovelSummary(
          id: '${i+2}',
          title: title,
          lastEditTime: DateTime.now().subtract(Duration(days: daysAgo)),
          wordCount: _random.nextInt(100000),
          seriesName: seriesName,
          completionPercentage: _random.nextDouble(),
          coverUrl: '',
        ),
      );
    }
    
    return novels;
  }
  
  // 创建新小说
  static NovelSummary createNovel(String title, {String? seriesName}) {
    return NovelSummary(
      id: _uuid.v4(),
      title: title,
      lastEditTime: DateTime.now(),
      wordCount: 0,
      seriesName: seriesName ?? '',
      completionPercentage: 0.0,
      coverUrl: '',
    );
  }
  
  // 导入小说
  static NovelSummary importNovel(String filePath) {
    // 从文件路径获取文件名作为小说名
    final fileName = filePath.split('/').last.split('.').first;
    
    return NovelSummary(
      id: _uuid.v4(),
      title: '导入: $fileName',
      lastEditTime: DateTime.now(),
      wordCount: _random.nextInt(50000) + 10000,
      seriesName: '',
      completionPercentage: 1.0,
      coverUrl: '',
    );
  }
  
  // 生成编辑器内容
  static EditorContent getEditorContent(String novelId, String chapterId) {
    // 模拟内容 - 使用Delta格式的JSON字符串
    final chapters = {
      '1': _generateChapter1Content(),
      '2': _generateChapter2Content(),
    };
    
    return EditorContent(
      id: chapterId,
      content: chapters[chapterId] ?? _generateEmptyContent(),
      lastSaved: DateTime.now().subtract(Duration(hours: _random.nextInt(24))),
      revisions: getRevisionHistory(novelId, chapterId),
    );
  }
  
  // 生成修订历史
  static List<Revision> getRevisionHistory(String novelId, String chapterId) {
    final List<Revision> revisions = [];
    
    // 添加几个假的修订版本
    final baseDate = DateTime.now().subtract(const Duration(days: 30));
    
    for (int i = 0; i < 5; i++) {
      revisions.add(
        Revision(
          id: _uuid.v4(),
          content: _generateRevisionContent(i),
          timestamp: baseDate.add(Duration(days: i * 3)),
          authorId: 'user_1',
          comment: i == 0 
              ? '初始版本' 
              : '修订 ${i + 1}：${_random.nextBool() ? '添加内容' : '修改内容'}',
        ),
      );
    }
    
    return revisions;
  }
  
  // 生成空内容
  static String _generateEmptyContent() {
    return '{"ops":[{"insert":"\\n"}]}';
  }
  
  // 生成章节1的内容
  static String _generateChapter1Content() {
    return '{"ops":[{"insert":"第一章\\n\\n在这个宁静的小镇上，春天悄然而至。桃花开了，柳树发芽了，小河的冰雪融化，潺潺的流水声唤醒了沉睡的大地。\\n\\n李小明站在自家门前的小路上，深吸了一口气，花香混着泥土的芬芳，让他感到无比舒畅。这是他回到家乡的第一个春天，离开了喧嚣的城市，他终于可以好好感受大自然的变化了。\\n\\n\\"小明，吃早饭了！\\"母亲的呼唤声从屋内传来。\\n\\n\\"来了！\\"李小明转身走进屋内，餐桌上摆着热腾腾的小米粥和刚出锅的煎饼，这是他最喜欢的早餐组合。\\n\\n就在这时，他的手机响了，是一条陌生号码发来的短信：\\"欢迎回家，我们期待与你的合作。\\"\\n\\n李小明盯着这条莫名其妙的短信，眉头不由自主地皱了起来。\\n"}]}';
  }
  
  // 生成章节2的内容
  static String _generateChapter2Content() {
    return '{"ops":[{"insert":"第二章\\n\\n一周后，李小明终于弄清楚了那条神秘短信的来源。原来是镇上新开的一家科技公司，他们不知怎么得知李小明曾在大城市的互联网公司工作，想请他担任技术顾问。\\n\\n这家名为\\"绿野科技\\"的公司位于镇子的西边，一栋翻新过的老厂房里。外表看起来普普通通，但走进去却是另一番天地：现代化的办公设备，宽敞明亮的工作区，甚至还有一个小型植物园。\\n\\n\\"我们的目标是开发能够帮助农村地区发展的技术产品，\\"公司创始人张远这样告诉李小明，\\"你在大数据方面的经验对我们很有价值。\\"\\n\\n李小明好奇地问：\\"为什么选择在这样一个小镇创业？\\"\\n\\n张远笑了笑：\\"因为真正的创新需要不同的视角，我们想做的是从农村实际需求出发的产品，而不是在大城市想象中的农村需求。\\"\\n\\n这个回答让李小明眼前一亮。或许，这就是他回到家乡后一直在寻找的机会。\\n"}]}';
  }
  
  // 生成修订版本内容
  static String _generateRevisionContent(int versionIndex) {
    if (versionIndex == 0) {
      return '{"ops":[{"insert":"第一章草稿\\n\\n这是初始版本的内容。后续会继续修改完善。\\n"}]}';
    } else {
      final versions = [
        '{"ops":[{"insert":"第一章\\n\\n小镇的春天来了。花开了，草绿了。\\n\\n李小明回到了家乡，离开了城市的喧嚣。\\n"}]}',
        '{"ops":[{"insert":"第一章\\n\\n小镇的春天来了。桃花开了，柳树发芽了，小河的冰雪融化。\\n\\n李小明站在自家门前，深吸了一口气，花香混着泥土的芬芳。这是他回到家乡的第一个春天。\\n"}]}',
        '{"ops":[{"insert":"第一章\\n\\n在这个宁静的小镇上，春天悄然而至。桃花开了，柳树发芽了，小河的冰雪融化，潺潺的流水声唤醒了沉睡的大地。\\n\\n李小明站在自家门前的小路上，深吸了一口气，花香混着泥土的芬芳，让他感到无比舒畅。这是他回到家乡的第一个春天，离开了喧嚣的城市，他终于可以好好感受大自然的变化了。\\n"}]}',
        '{"ops":[{"insert":"第一章\\n\\n在这个宁静的小镇上，春天悄然而至。桃花开了，柳树发芽了，小河的冰雪融化，潺潺的流水声唤醒了沉睡的大地。\\n\\n李小明站在自家门前的小路上，深吸了一口气，花香混着泥土的芬芳，让他感到无比舒畅。这是他回到家乡的第一个春天，离开了喧嚣的城市，他终于可以好好感受大自然的变化了。\\n\\n\\"小明，吃早饭了！\\"母亲的呼唤声从屋内传来。\\n\\n\\"来了！\\"李小明转身走进屋内，餐桌上摆着热腾腾的小米粥和刚出锅的煎饼，这是他最喜欢的早餐组合。\\n"}]}',
      ];
      
      return versions[versionIndex - 1];
    }
  }
} 