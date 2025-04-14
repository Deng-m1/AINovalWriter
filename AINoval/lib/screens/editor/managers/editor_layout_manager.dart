import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 编辑器布局管理器
/// 负责管理编辑器的布局和尺寸
class EditorLayoutManager extends ChangeNotifier {
  EditorLayoutManager() {
    _loadSavedDimensions();
  }

  // 侧边栏可见性状态
  bool isEditorSidebarVisible = true;
  bool isAIChatSidebarVisible = false;
  bool isSettingsPanelVisible = false;
  bool isNovelSettingsVisible = false;
  bool isAISummaryPanelVisible = false;
  bool isAISceneGenerationPanelVisible = false;

  // 侧边栏宽度
  double editorSidebarWidth = 280;
  double chatSidebarWidth = 380;

  // 侧边栏宽度限制
  static const double minEditorSidebarWidth = 220;
  static const double maxEditorSidebarWidth = 400;
  static const double minChatSidebarWidth = 280;
  static const double maxChatSidebarWidth = 500;

  // 持久化键
  static const String editorSidebarWidthPrefKey = 'editor_sidebar_width';
  static const String chatSidebarWidthPrefKey = 'chat_sidebar_width';

  // 加载保存的尺寸
  Future<void> _loadSavedDimensions() async {
    await _loadSavedEditorSidebarWidth();
    await _loadSavedChatSidebarWidth();
  }

  // 加载保存的编辑器侧边栏宽度
  Future<void> _loadSavedEditorSidebarWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedWidth = prefs.getDouble(editorSidebarWidthPrefKey);
      if (savedWidth != null) {
        if (savedWidth >= minEditorSidebarWidth &&
            savedWidth <= maxEditorSidebarWidth) {
          editorSidebarWidth = savedWidth;
        }
      }
    } catch (e) {
      AppLogger.e('EditorLayoutManager', '加载编辑器侧边栏宽度失败', e);
    }
  }

  // 保存编辑器侧边栏宽度
  Future<void> saveEditorSidebarWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(editorSidebarWidthPrefKey, editorSidebarWidth);
    } catch (e) {
      AppLogger.e('EditorLayoutManager', '保存编辑器侧边栏宽度失败', e);
    }
  }

  // 加载保存的聊天侧边栏宽度
  Future<void> _loadSavedChatSidebarWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedWidth = prefs.getDouble(chatSidebarWidthPrefKey);
      if (savedWidth != null) {
        if (savedWidth >= minChatSidebarWidth &&
            savedWidth <= maxChatSidebarWidth) {
          chatSidebarWidth = savedWidth;
        }
      }
    } catch (e) {
      AppLogger.e('EditorLayoutManager', '加载侧边栏宽度失败', e);
    }
  }

  // 保存聊天侧边栏宽度
  Future<void> saveChatSidebarWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(chatSidebarWidthPrefKey, chatSidebarWidth);
    } catch (e) {
      AppLogger.e('EditorLayoutManager', '保存侧边栏宽度失败', e);
    }
  }

  // 更新编辑器侧边栏宽度
  void updateEditorSidebarWidth(double delta) {
    editorSidebarWidth = (editorSidebarWidth + delta).clamp(
      minEditorSidebarWidth,
      maxEditorSidebarWidth,
    );
  }

  // 更新聊天侧边栏宽度
  void updateChatSidebarWidth(double delta) {
    chatSidebarWidth = (chatSidebarWidth - delta).clamp(
      minChatSidebarWidth,
      maxChatSidebarWidth,
    );
  }

  // 切换编辑器侧边栏可见性
  void toggleEditorSidebar() {
    isEditorSidebarVisible = !isEditorSidebarVisible;
    notifyListeners();
  }

  // 切换AI聊天侧边栏可见性
  void toggleAIChatSidebar() {
    isAIChatSidebarVisible = !isAIChatSidebarVisible;
    if (isAIChatSidebarVisible) {
      isSettingsPanelVisible = false;
      isNovelSettingsVisible = false;
      isAISceneGenerationPanelVisible = false;
      isAISummaryPanelVisible = false;
    }
    notifyListeners();
  }

  // 切换AI场景生成面板可见性
  void toggleAISceneGenerationPanel() {
    isAISceneGenerationPanelVisible = !isAISceneGenerationPanelVisible;
    if (isAISceneGenerationPanelVisible) {
      isAIChatSidebarVisible = false;
      isSettingsPanelVisible = false;
      isNovelSettingsVisible = false;
      isAISummaryPanelVisible = false;
    }
    notifyListeners();
  }

  // 切换AI摘要面板可见性
  void toggleAISummaryPanel() {
    isAISummaryPanelVisible = !isAISummaryPanelVisible;
    if (isAISummaryPanelVisible) {
      isAIChatSidebarVisible = false;
      isSettingsPanelVisible = false;
      isNovelSettingsVisible = false;
      isAISceneGenerationPanelVisible = false;
    }
    notifyListeners();
  }

  // 切换设置面板可见性
  void toggleSettingsPanel() {
    isSettingsPanelVisible = !isSettingsPanelVisible;
    if (isSettingsPanelVisible) {
      isAIChatSidebarVisible = false;
      isNovelSettingsVisible = false;
      isAISceneGenerationPanelVisible = false;
      isAISummaryPanelVisible = false;
    }
    notifyListeners();
  }

  // 切换小说设置视图可见性
  void toggleNovelSettings() {
    isNovelSettingsVisible = !isNovelSettingsVisible;
    if (isNovelSettingsVisible) {
      isAIChatSidebarVisible = false;
      isSettingsPanelVisible = false;
      isAISceneGenerationPanelVisible = false;
      isAISummaryPanelVisible = false;
    }
    notifyListeners();
  }
}
