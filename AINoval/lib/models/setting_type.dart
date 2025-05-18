// AINoval/lib/models/setting_type.dart
enum SettingType {
  character('CHARACTER', '角色'),
  location('LOCATION', '地点'),
  item('ITEM', '物品'),
  lore('LORE', '背景知识'),
  faction('FACTION', '组织/势力'),
  event('EVENT', '事件'),
  concept('CONCEPT', '概念/规则'),
  creature('CREATURE', '生物/种族'),
  magicSystem('MAGIC_SYSTEM', '魔法体系'),
  technology('TECHNOLOGY', '科技设定'),
  other('OTHER', '其他');

  const SettingType(this.value, this.displayName);
  final String value;
  final String displayName;

  static SettingType fromValue(String value) {
    return SettingType.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => SettingType.other,
    );
  }
}

// Helper for UI if needed
class SettingTypeOption {
  final SettingType type;
  bool isSelected;

  SettingTypeOption(this.type, {this.isSelected = false});
} 