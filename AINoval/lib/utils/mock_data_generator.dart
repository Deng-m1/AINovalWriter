import 'dart:math';

import 'package:ainoval/models/novel_structure.dart';
import 'package:uuid/uuid.dart';

/// 模拟数据生成器，用于生成符合数据结构的模拟数据
class MockDataGenerator {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();
  
  /// 生成模拟小说数据
  static Novel generateMockNovel(String id, String title) {
    final now = DateTime.now();
    
    // 创建摘要
    final summary1 = Summary(
      id: 'summary_${_uuid.v4()}',
      content: 'While reading, Emperor Zhu Yijun is startled by a servant announcing Eunuch Feng\'s accidental drowning. Overwhelmed, Zhu Yijun reacts with disbelief and distress, questioning the event\'s timing, as he had recently administered poison to Feng. Upon seeing his mother, Empress Dowager Li, Zhu Yijun expresses his concern and grief. They visit Feng\'s residence, where news of Feng\'s death is confirmed, causing Zhu Yijun to dramatically faint. Physicians determine Zhu Yijun\'s collapse stems from grief and shock, and Empress Dowager Li summons Zhang Juzheng.',
    );
    
    final summary2 = Summary(
      id: 'summary_${_uuid.v4()}',
      content: 'Zhang Juzheng arrives at the palace and meets with Empress Dowager Li. They discuss the suspicious circumstances of Feng\'s death and the political implications. Zhang suggests an investigation while maintaining public appearances.',
    );
    
    // 创建场景
    final scene1 = Scene(
      id: 'scene_${_uuid.v4()}',
      content: '{"ops":[{"insert":"朱翊钧读完手中的奏折，正全神贯注地看着，有两滴清澈的水珠，不时还会滑下来。\\n\\n露出一抹儿呢没有挂去，龙袍穿在身上感觉很分外。\\n\\n"来人，不好了！"\\n\\n一声喊叫打破了宫中的宁静，紧接着脚步声越来越近，朝廷上下不知所措。\\n\\n朱翊钧抬眼一瞧，看到了一个嬷嬷，有些惊恐的抬起头，"出了何事。"\\n\\n转头，陛下，"太监吓得跪在地上说道："陛下，冯公公落水了，被人从水里救上来了。"\\n\\n"什么？"朱翊钧一脸惊愕的站起身，不敢置信的追问太监的身边，"你再说一遍！"\\n\\n太监抬头一声就跪在了地上说道："陛下，冯公公落水了。陛下不必惊慌，人已经救上来了。"\\n\\n"怎么会这样呢？怎么会这样呢？"朱翊钧一脸茫然的举起了手，"不可能！"\\n\\n这个时候，远处响起了脚步声，一个衣着华丽的女人在一群人的簇拥下走了进来。\\n\\n他们走到朱翊钧的面前，李太后问道："孩儿这是怎么了？你可千万别信。"\\n\\n朱翊钧抬起头看了一眼母亲李太后后，十分忧心的说道："母后，他们说冯保落水了，是不是？"\\n\\n太监抬地一声就跪在了地上说道："陛下，冯公公落水了。陛下不必惊慌，人已经救上来了。"\\n\\n"怎么会这样呢？怎么会这样呢？"朱翊钧一脸茫然的举起了手，"不可能！"\\n"}]}',
      wordCount: 1168,
      summary: summary1,
      lastEdited: now.subtract(const Duration(days: 1)),
    );
    
    final scene2 = Scene(
      id: 'scene_${_uuid.v4()}',
      content: '{"ops":[{"insert":"张居正匆匆赶到宫中，李太后已经在等候。\\n\\n"张先生，情况如何？"李太后问道。\\n\\n张居正行礼后回答："回太后，冯公公确实溺水身亡，但死因尚不明确。"\\n\\n"这太蹊跷了，"李太后低声说，"冯保水性很好，怎会溺水？"\\n\\n"微臣也有疑虑，但现在最重要的是稳定局势，以免朝中生变。"\\n\\n李太后点头："你说得对，先不要声张。皇上情绪很不稳定，你去看看他吧。"\\n"}]}',
      wordCount: 350,
      summary: summary2,
      lastEdited: now.subtract(const Duration(hours: 5)),
    );
    
    // 创建章节
    final chapter1 = Chapter(
      id: 'chapter_${_uuid.v4()}',
      title: 'Chapter 1',
      order: 1,
      scenes: [scene1],
    );
    
    final chapter2 = Chapter(
      id: 'chapter_${_uuid.v4()}',
      title: 'Chapter 2',
      order: 2,
      scenes: [scene2],
    );
    
    // 创建Act
    final act1 = Act(
      id: 'act_${_uuid.v4()}',
      title: 'Act 1',
      order: 1,
      chapters: [chapter1, chapter2],
    );
    
    // 创建第二个Act
    final summary3 = Summary(
      id: 'summary_${_uuid.v4()}',
      content: 'The emperor meets with his advisors to discuss the political situation after Feng\'s death. They strategize on how to maintain stability and prevent power struggles.',
    );
    
    final scene3 = Scene(
      id: 'scene_${_uuid.v4()}',
      content: '{"ops":[{"insert":"朱翊钧坐在御书房中，面前站着几位重臣。\\n\\n"诸位爱卿，冯保之死已成定局，但朝中不可动荡。"朱翊钧沉声道。\\n\\n张居正拱手道："陛下圣明。臣以为，应当尽快安排冯公公的后事，并妥善处理内廷事务，以免有人趁机生事。"\\n\\n"张先生所言极是，"申时行附和道，"内廷之事关系重大，不可有失。"\\n"}]}',
      wordCount: 420,
      summary: summary3,
      lastEdited: now.subtract(const Duration(hours: 2)),
    );
    
    final chapter3 = Chapter(
      id: 'chapter_${_uuid.v4()}',
      title: 'Chapter 3',
      order: 1,
      scenes: [scene3],
    );
    
    final act2 = Act(
      id: 'act_${_uuid.v4()}',
      title: 'Act 2',
      order: 2,
      chapters: [chapter3],
    );
    
    // 创建小说
    return Novel(
      id: id,
      title: title,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
      acts: [act1, act2],
    );
  }
  
  /// 生成空的小说结构
  static Novel generateEmptyNovel(String id, String title) {
    final now = DateTime.now();
    
    // 创建一个空的Act
    final act1 = Act(
      id: 'act_${_uuid.v4()}',
      title: 'Act 1',
      order: 1,
      chapters: [],
    );
    
    // 创建小说
    return Novel(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      acts: [act1],
    );
  }
  
  /// 生成一个空的场景
  static Scene generateEmptyScene() {
    final now = DateTime.now();
    
    final summary = Summary(
      id: 'summary_${_uuid.v4()}',
      content: '',
    );
    
    return Scene(
      id: 'scene_${_uuid.v4()}',
      content: '{"ops":[{"insert":"\\n"}]}',
      wordCount: 0,
      summary: summary,
      lastEdited: now,
    );
  }
} 