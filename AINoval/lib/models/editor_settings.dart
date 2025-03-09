import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class EditorSettings extends Equatable {
  
  const EditorSettings({
    this.fontSize = 16.0,
    this.fontFamily = 'Roboto',
    this.lineSpacing = 1.5,
    this.spellCheckEnabled = true,
    this.themeMode = ThemeMode.system,
    this.autoSaveEnabled = true,
    this.autoSaveInterval = const Duration(minutes: 2),
  });
  
  // 从JSON转换
  factory EditorSettings.fromJson(Map<String, dynamic> json) {
    return EditorSettings(
      fontSize: json['fontSize']?.toDouble() ?? 16.0,
      fontFamily: json['fontFamily'] ?? 'Roboto',
      lineSpacing: json['lineSpacing']?.toDouble() ?? 1.5,
      spellCheckEnabled: json['spellCheckEnabled'] ?? true,
      themeMode: ThemeMode.values[json['themeMode'] ?? 0],
      autoSaveEnabled: json['autoSaveEnabled'] ?? true,
      autoSaveInterval: Duration(seconds: json['autoSaveIntervalSeconds'] ?? 120),
    );
  }
  final double fontSize;
  final String fontFamily;
  final double lineSpacing;
  final bool spellCheckEnabled;
  final ThemeMode themeMode;
  final bool autoSaveEnabled;
  final Duration autoSaveInterval;
  
  @override
  List<Object?> get props => [
    fontSize, 
    fontFamily, 
    lineSpacing, 
    spellCheckEnabled, 
    themeMode, 
    autoSaveEnabled,
    autoSaveInterval,
  ];
  
  // 创建副本但更新部分内容
  EditorSettings copyWith({
    double? fontSize,
    String? fontFamily,
    double? lineSpacing,
    bool? spellCheckEnabled,
    ThemeMode? themeMode,
    bool? autoSaveEnabled,
    Duration? autoSaveInterval,
  }) {
    return EditorSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      spellCheckEnabled: spellCheckEnabled ?? this.spellCheckEnabled,
      themeMode: themeMode ?? this.themeMode,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
      autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'lineSpacing': lineSpacing,
      'spellCheckEnabled': spellCheckEnabled,
      'themeMode': themeMode.index,
      'autoSaveEnabled': autoSaveEnabled,
      'autoSaveIntervalSeconds': autoSaveInterval.inSeconds,
    };
  }
} 