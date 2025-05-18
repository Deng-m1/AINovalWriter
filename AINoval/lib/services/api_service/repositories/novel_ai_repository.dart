import 'package:ainoval/models/novel_setting_item.dart';

abstract class NovelAIRepository {
  Future<List<NovelSettingItem>> generateNovelSettings({
    required String novelId,
    required String startChapterId,
    String? endChapterId,
    required List<String> settingTypes,
    required int maxSettingsPerType,
    required String additionalInstructions,
  });
} 