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
  bool isAIContinueWritingPanelVisible = false;
  
  // 多面板显示时的顺序和位置
  final List<String> visiblePanels = [];
  static const String aiChatPanel = 'aiChat';
  static const String aiSummaryPanel = 'aiSummary';
  static const String aiScenePanel = 'aiScene';
  static const String aiContinueWritingPanel = 'aiContinueWriting';

  // 侧边栏宽度
  double editorSidebarWidth = 280;
  double chatSidebarWidth = 380;
  
  // 多面板模式下的单个面板宽度
  Map<String, double> panelWidths = {
    aiChatPanel: 350,
    aiSummaryPanel: 350,
    aiScenePanel: 350,
    aiContinueWritingPanel: 350,
  };

  // 侧边栏宽度限制
  static const double minEditorSidebarWidth = 220;
  static const double maxEditorSidebarWidth = 400;
  static const double minChatSidebarWidth = 280;
  static const double maxChatSidebarWidth = 500;
  static const double minPanelWidth = 280;
  static const double maxPanelWidth = 400;

  // 持久化键
  static const String editorSidebarWidthPrefKey = 'editor_sidebar_width';
  static const String chatSidebarWidthPrefKey = 'chat_sidebar_width';
  static const String panelWidthsPrefKey = 'multi_panel_widths';
  static const String visiblePanelsPrefKey = 'visible_panels';

  // 加载保存的尺寸
  Future<void> _loadSavedDimensions() async {
    await _loadSavedEditorSidebarWidth();
    await _loadSavedChatSidebarWidth();
    await _loadSavedPanelWidths();
    await _loadSavedVisiblePanels();
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
  
  // 加载保存的面板宽度
  Future<void> _loadSavedPanelWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedWidthsString = prefs.getString(panelWidthsPrefKey);
      if (savedWidthsString != null) {
        final savedWidthsList = savedWidthsString.split(',');
        if (savedWidthsList.isNotEmpty) {
          panelWidths[aiChatPanel] = double.tryParse(savedWidthsList.elementAtOrNull(0) ?? panelWidths[aiChatPanel].toString())!.clamp(minPanelWidth, maxPanelWidth);
          panelWidths[aiSummaryPanel] = double.tryParse(savedWidthsList.elementAtOrNull(1) ?? panelWidths[aiSummaryPanel].toString())!.clamp(minPanelWidth, maxPanelWidth);
          panelWidths[aiScenePanel] = double.tryParse(savedWidthsList.elementAtOrNull(2) ?? panelWidths[aiScenePanel].toString())!.clamp(minPanelWidth, maxPanelWidth);
          if (savedWidthsList.length > 3) {
            panelWidths[aiContinueWritingPanel] = double.tryParse(savedWidthsList.elementAtOrNull(3) ?? panelWidths[aiContinueWritingPanel].toString())!.clamp(minPanelWidth, maxPanelWidth);
          }
        }
      }
    } catch (e) {
      AppLogger.e('EditorLayoutManager', '加载面板宽度失败', e);
    }
  }
  
  // 加载保存的可见面板
  Future<void> _loadSavedVisiblePanels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPanels = prefs.getStringList(visiblePanelsPrefKey);
      if (savedPanels != null) {
        visiblePanels.clear();
        visiblePanels.addAll(savedPanels);
        
        // 更新各面板的可见性状态
        isAIChatSidebarVisible = visiblePanels.contains(aiChatPanel);
        isAISummaryPanelVisible = visiblePanels.contains(aiSummaryPanel);
        isAISceneGenerationPanelVisible = visiblePanels.contains(aiScenePanel);
        isAIContinueWritingPanelVisible = visiblePanels.contains(aiContinueWritingPanel);
      }
    } catch (e) {
      AppLogger.e('EditorLayoutManager', '加载可见面板失败', e);
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
  
  // 保存面板宽度
  Future<void> savePanelWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final widthsString = [
        panelWidths[aiChatPanel],
        panelWidths[aiSummaryPanel],
        panelWidths[aiScenePanel],
        panelWidths[aiContinueWritingPanel]
      ].join(',');
      await prefs.setString(panelWidthsPrefKey, widthsString);
    } catch (e) {
      AppLogger.e('EditorLayoutManager', '保存面板宽度失败', e);
    }
  }
  
  // 保存可见面板
  Future<void> saveVisiblePanels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(visiblePanelsPrefKey, visiblePanels);
    } catch (e) {
      AppLogger.e('EditorLayoutManager', '保存可见面板失败', e);
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
  
  // 更新指定面板宽度
  void updatePanelWidth(String panelId, double delta) {
    if (panelWidths.containsKey(panelId)) {
      panelWidths[panelId] = (panelWidths[panelId]! - delta).clamp(
        minPanelWidth,
        maxPanelWidth,
      );
      notifyListeners();
    }
  }

  // 切换编辑器侧边栏可见性
  void toggleEditorSidebar() {
    isEditorSidebarVisible = !isEditorSidebarVisible;
    notifyListeners();
  }

  // 切换AI聊天侧边栏可见性
  void toggleAIChatSidebar() {
    // 在多面板模式下
    if (visiblePanels.contains(aiChatPanel)) {
      // 如果已经可见，则移除
      visiblePanels.remove(aiChatPanel);
      isAIChatSidebarVisible = false;
    } else {
      // 如果不可见，则添加
      visiblePanels.add(aiChatPanel);
      isAIChatSidebarVisible = true;
    }
    saveVisiblePanels();
    notifyListeners();
  }

  // 切换AI场景生成面板可见性
  void toggleAISceneGenerationPanel() {
    // 在多面板模式下
    if (visiblePanels.contains(aiScenePanel)) {
      // 如果已经可见，则移除
      visiblePanels.remove(aiScenePanel);
      isAISceneGenerationPanelVisible = false;
    } else {
      // 如果不可见，则添加
      visiblePanels.add(aiScenePanel);
      isAISceneGenerationPanelVisible = true;
    }
    saveVisiblePanels();
    notifyListeners();
  }

  // 切换AI摘要面板可见性
  void toggleAISummaryPanel() {
    // 在多面板模式下
    if (visiblePanels.contains(aiSummaryPanel)) {
      // 如果已经可见，则移除
      visiblePanels.remove(aiSummaryPanel);
      isAISummaryPanelVisible = false;
    } else {
      // 如果不可见，则添加
      visiblePanels.add(aiSummaryPanel);
      isAISummaryPanelVisible = true;
    }
    saveVisiblePanels();
    notifyListeners();
  }

  // 新增：切换AI自动续写面板可见性
  void toggleAIContinueWritingPanel() {
    if (visiblePanels.contains(aiContinueWritingPanel)) {
      visiblePanels.remove(aiContinueWritingPanel);
      isAIContinueWritingPanelVisible = false;
    } else {
      visiblePanels.add(aiContinueWritingPanel);
      isAIContinueWritingPanelVisible = true;
    }
    saveVisiblePanels();
    notifyListeners();
  }

  // 切换设置面板可见性
  void toggleSettingsPanel() {
    isSettingsPanelVisible = !isSettingsPanelVisible;
    if (isSettingsPanelVisible) {
      // 设置面板是全屏遮罩，不影响其他面板的显示
    }
    notifyListeners();
  }

  // 切换小说设置视图可见性
  void toggleNovelSettings() {
    isNovelSettingsVisible = !isNovelSettingsVisible;
    if (isNovelSettingsVisible) {
      // 小说设置视图会替换主编辑区域，不影响侧边面板
    }
    notifyListeners();
  }
  
  // 获取面板是否为最后一个
  bool isLastPanel(String panelId) {
    return visiblePanels.length == 1 && visiblePanels.contains(panelId);
  }
  
  // 重新排序面板
  void reorderPanels(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = visiblePanels.removeAt(oldIndex);
    visiblePanels.insert(newIndex, item);
    saveVisiblePanels();
    notifyListeners();
  }
}
