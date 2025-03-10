import 'package:equatable/equatable.dart';

/// 编辑器设置模型
class EditorSettings extends Equatable {
  
  const EditorSettings({
    this.fontSize = 16.0,
    this.fontFamily = 'Serif',
    this.lineSpacing = 1.5,
    this.spellCheckEnabled = true,
    this.autoSaveEnabled = true,
    this.autoSaveIntervalMinutes = 2,
    this.darkModeEnabled = false,
  });
  
  /// 从Map创建EditorSettings实例
  factory EditorSettings.fromMap(Map<String, dynamic> map) {
    return EditorSettings(
      fontSize: map['fontSize']?.toDouble() ?? 16.0,
      fontFamily: map['fontFamily'] ?? 'Serif',
      lineSpacing: map['lineSpacing']?.toDouble() ?? 1.5,
      spellCheckEnabled: map['spellCheckEnabled'] ?? true,
      autoSaveEnabled: map['autoSaveEnabled'] ?? true,
      autoSaveIntervalMinutes: map['autoSaveIntervalMinutes'] ?? 2,
      darkModeEnabled: map['darkModeEnabled'] ?? false,
    );
  }
  final double fontSize;
  final String fontFamily;
  final double lineSpacing;
  final bool spellCheckEnabled;
  final bool autoSaveEnabled;
  final int autoSaveIntervalMinutes;
  final bool darkModeEnabled;
  
  @override
  List<Object?> get props => [
    fontSize,
    fontFamily,
    lineSpacing,
    spellCheckEnabled,
    autoSaveEnabled,
    autoSaveIntervalMinutes,
    darkModeEnabled,
  ];
  
  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'lineSpacing': lineSpacing,
      'spellCheckEnabled': spellCheckEnabled,
      'autoSaveEnabled': autoSaveEnabled,
      'autoSaveIntervalMinutes': autoSaveIntervalMinutes,
      'darkModeEnabled': darkModeEnabled,
    };
  }
  
  /// 创建EditorSettings的副本
  EditorSettings copyWith({
    double? fontSize,
    String? fontFamily,
    double? lineSpacing,
    bool? spellCheckEnabled,
    bool? autoSaveEnabled,
    int? autoSaveIntervalMinutes,
    bool? darkModeEnabled,
  }) {
    return EditorSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      spellCheckEnabled: spellCheckEnabled ?? this.spellCheckEnabled,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
      autoSaveIntervalMinutes: autoSaveIntervalMinutes ?? this.autoSaveIntervalMinutes,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
    );
  }
} 