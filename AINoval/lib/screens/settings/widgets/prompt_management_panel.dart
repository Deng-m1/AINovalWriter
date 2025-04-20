import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/blocs/prompt/prompt_template_events.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/screens/settings/widgets/prompt_template_library.dart';
import 'package:ainoval/screens/settings/widgets/prompt_editor_panel.dart';
import 'package:ainoval/screens/settings/widgets/template_permission_indicator.dart';
import 'package:ainoval/config/app_config.dart';
import 'package:flutter/rendering.dart';

/// 提示词管理面板
class PromptManagementPanel extends StatefulWidget {
  const PromptManagementPanel({Key? key}) : super(key: key);

  @override
  State<PromptManagementPanel> createState() => _PromptManagementPanelState();
}

class _PromptManagementPanelState extends State<PromptManagementPanel> with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  late TabController _tabController;
  bool _isEdited = false;
  
  // 当前编辑的模板
  PromptTemplate? _currentEditingTemplate;
  
  // 是否处于编辑模板模式
  bool _isEditingTemplate = false;
  
  // 是否是新建模板
  bool _isNewTemplate = false;
  
  // 新建模板的功能类型
  AIFeatureType? _newTemplateFeatureType;
  
  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    // 初始化标签控制器
    _tabController = TabController(length: 2, vsync: this);
    
    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 0.0, // 确保从0开始
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    // 立即启动动画
    _animationController.forward();
    
    // 加载所有提示词
    context.read<PromptBloc>().add(const LoadAllPromptsRequested());
    // 加载提示词模板
    context.read<PromptBloc>().add(const LoadPromptTemplatesRequested());
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 确保动画正在运行
    if (!_animationController.isAnimating && _animationController.value < 1.0) {
      _animationController.forward();
    }
  }
  
  @override
  void dispose() {
    _promptController.dispose();
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PromptBloc, PromptState>(
      listener: (context, state) {
        // 当选择了提示词类型时，更新编辑器内容
        if (state.selectedPrompt != null && !_isEdited) {
          _promptController.text = state.selectedPrompt!.activePrompt;
        }
        
        // 显示错误信息
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(state.errorMessage!),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(8),
            ),
          );
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题区域 - 磨砂玻璃效果
              _buildGlassHeader(theme, isDark),
              
              const SizedBox(height: 16),
              
              // 如果正在编辑模板，显示返回按钮
              if (_isEditingTemplate)
                AnimatedSlide(
                  offset: Offset(0, _animationController.value - 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutQuart,
                  child: AnimatedOpacity(
                    opacity: _animationController.value,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('返回模板库'),
                        onPressed: _cancelTemplateEditing,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              
              // 内容区域 - 使用Expanded确保填充可用空间
              Expanded(
                child: !_isEditingTemplate
                  ? AnimatedSlide(
                      offset: Offset(0, (_animationController.value - 1) * 0.5),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuart,
                      child: AnimatedOpacity(
                        opacity: _animationController.value,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOut,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark 
                                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.85)
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                  ? Colors.black.withOpacity(0.25)
                                  : Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                                spreadRadius: -2,
                              ),
                            ],
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withOpacity(isDark ? 0.3 : 0.5),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // 标签栏 - 玻璃效果
                              _buildGlassTabBar(theme, isDark),
                              
                              // TabBarView内容
                              Expanded(
                                child: TabBarView(
                                  physics: const BouncingScrollPhysics(),
                                  controller: _tabController,
                                  children: [
                                    // 预设提示词标签页
                                    _buildPromptSettingsTab(context, state),
                                    
                                    // 模板库标签页 - 使用新组件
                                    PromptTemplateLibrary(
                                      onCopyToPrivate: _handleCopyToPrivate,
                                      onView: _handleViewTemplate,
                                      onEdit: _handleEditTemplate,
                                      onDelete: _handleDeleteTemplate,
                                      onToggleFavorite: _handleToggleFavorite,
                                      onCreateNew: _createNewTemplate,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark 
                              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.85)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                ? Colors.black.withOpacity(0.25)
                                : Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                              spreadRadius: -2,
                            ),
                          ],
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withOpacity(isDark ? 0.3 : 0.5),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          // 使用key确保在参数变化时重建
                          child: PromptEditorPanel(
                            // 使用固定key
                            key: ValueKey('editor_panel'),
                            template: _currentEditingTemplate,
                            isNew: _isNewTemplate,
                            featureType: _newTemplateFeatureType ?? AIFeatureType.sceneToSummary, // 提供默认值防止null
                            onSaveSuccess: _handleTemplateSaveSuccess,
                            onCancel: _cancelTemplateEditing,
                            onCopyToPrivate: _handleCopyCurrentToPrivate,
                          ),
                        ),
                      ),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// 构建玻璃化标题栏
  Widget _buildGlassHeader(ThemeData theme, bool isDark) {
    return AnimatedSlide(
      offset: Offset(0, _animationController.value - 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutQuart,
      child: AnimatedOpacity(
        opacity: _animationController.value,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
              padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                        theme.colorScheme.primaryContainer.withOpacity(0.65),
                        theme.colorScheme.primaryContainer.withOpacity(0.45),
                              ]
                            : [
                        theme.colorScheme.primaryContainer.withOpacity(0.85),
                        theme.colorScheme.primaryContainer.withOpacity(0.65),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                      ? Colors.black.withOpacity(0.25)
                      : Colors.black.withOpacity(0.12),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    blurRadius: 20,
                          offset: const Offset(0, 4),
                    spreadRadius: -2,
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                    padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 24,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '提示词管理',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                        const SizedBox(height: 4),
                              Text(
                                '管理AI生成功能的提示词模板，提升AI生成效果',
                                style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
  
  /// 构建玻璃化标签栏
  Widget _buildGlassTabBar(ThemeData theme, bool isDark) {
    return ClipRRect(
                        borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
                        ),
                        child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                ? [
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.75),
                    theme.colorScheme.surfaceContainerHigh.withOpacity(0.65),
                  ]
                : [
                    theme.colorScheme.surfaceContainerLowest.withOpacity(0.8),
                    theme.colorScheme.surfaceContainerLow.withOpacity(0.7),
                  ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
                              borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tune, size: 16),
                    const SizedBox(width: 8),
                    const Text('预设提示词'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_books, size: 16),
                    const SizedBox(width: 8),
                    const Text('模板库'),
                  ],
                ),
              ),
                              ],
                              labelColor: theme.colorScheme.primary,
                              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                              indicatorColor: theme.colorScheme.primary,
                              indicatorSize: TabBarIndicatorSize.label,
                              indicatorWeight: 3,
            labelPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                              dividerColor: Colors.transparent,
                            ),
                          ),
      ),
    );
  }
  
  /// 构建提示词设置标签页
  Widget _buildPromptSettingsTab(BuildContext context, PromptState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 650,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 功能类型选择
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildFeatureTypeSelector(context, state),
            ),
            const SizedBox(height: 12),
            
            // 提示词编辑区域
            if (state.selectedFeatureType != null) ...[
              Expanded(child: _buildPromptEditor(context, state)),
            ] else ...[
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceContainerLow.withOpacity(0.7)
                          : theme.colorScheme.surfaceContainerLowest.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 32,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '请选择一个功能类型',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '在上方选择一个功能类型以编辑其提示词',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// 构建功能类型选择区域
  Widget _buildFeatureTypeSelector(BuildContext context, PromptState state) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.category,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
        Text(
          '功能类型',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
        ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // 功能类型选择卡片
        Row(
          children: [
            _buildFeatureTypeCard(
              context,
              AIFeatureType.sceneToSummary,
              '场景生成摘要',
              '根据场景内容自动生成摘要',
              Icons.summarize,
              state.selectedFeatureType == AIFeatureType.sceneToSummary,
            ),
            const SizedBox(width: 16),
            _buildFeatureTypeCard(
              context,
              AIFeatureType.summaryToScene,
              '摘要生成场景',
              '根据摘要生成完整场景内容',
              Icons.description,
              state.selectedFeatureType == AIFeatureType.summaryToScene,
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建功能类型选择卡片
  Widget _buildFeatureTypeCard(
    BuildContext context,
    AIFeatureType featureType,
    String title,
    String description,
    IconData icon,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                  : theme.colorScheme.primaryContainer.withOpacity(0.4))
              : (isDark
                  ? theme.colorScheme.surfaceContainerLow.withOpacity(0.7)
                  : theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        child: InkWell(
            borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.read<PromptBloc>().add(SelectFeatureRequested(featureType));
            setState(() => _isEdited = false);
          },
          child: Padding(
              padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected 
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : (isDark
                                  ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
                                  : theme.colorScheme.surfaceVariant),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.15),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.onSurfaceVariant,
                          size: 18,
                      ),
                    ),
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                          color: isSelected 
                              ? theme.colorScheme.primary 
                              : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                          size: 16,
                    ),
                  ],
                ),
                  const SizedBox(height: 12),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建提示词编辑区域
  Widget _buildPromptEditor(BuildContext context, PromptState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedPrompt = state.selectedPrompt;
    final isCustomized = selectedPrompt?.isCustomized ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 顶部区域：标题和状态指示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
            Text(
              '提示词编辑',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
            ),
            
            // 自定义状态指示
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCustomized 
                      ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                      : (isDark
                          ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
                          : theme.colorScheme.surfaceVariant),
                borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isCustomized
                          ? theme.colorScheme.primary.withOpacity(0.1)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCustomized ? Icons.edit : Icons.lock_outline,
                      size: 14,
                    color: isCustomized 
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                  ),
                    const SizedBox(width: 6),
                  Text(
                    isCustomized ? '已自定义' : '系统默认',
                    style: TextStyle(
                      fontSize: 12,
                        fontWeight: isCustomized ? FontWeight.w600 : FontWeight.w500,
                      color: isCustomized 
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
        const SizedBox(height: 12),
        
        // 中间区域：编辑器和模板选择并排显示
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：提示词编辑区域
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // 可用变量占位符指示
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                  ? [
                                      theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                      theme.colorScheme.surfaceContainerHigh.withOpacity(0.3),
                                    ]
                                  : [
                                      theme.colorScheme.primaryContainer.withOpacity(0.2),
                                      theme.colorScheme.primaryContainer.withOpacity(0.1),
                                    ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.code,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                          Text(
                            '可用变量:',
                            style: TextStyle(
                                    fontWeight: FontWeight.w600,
                              fontSize: 12,
                                    color: theme.colorScheme.primary,
                            ),
                          ),
                                const SizedBox(width: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: _buildVariablePlaceholders(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    
                    // 提示词文本编辑器
                    Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? theme.colorScheme.surfaceContainerLow.withOpacity(0.6)
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                      child: TextField(
                        controller: _promptController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                  color: theme.colorScheme.outline,
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          hintText: '请输入提示词',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                              ),
                          filled: true,
                              fillColor: isDark
                                  ? theme.colorScheme.surfaceContainerLow.withOpacity(0.3)
                                  : theme.colorScheme.surface,
                              contentPadding: const EdgeInsets.all(16),
                              isDense: true,
                        ),
                        onChanged: (_) {
                          setState(() => _isEdited = true);
                        },
                      ),
                    ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                      '为AI生成提供指导性的提示词，控制生成风格和内容',
                      style: TextStyle(
                        fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                      ),
                    ),
                  ],
                ),
              ),
              
                const SizedBox(width: 16),
              
              // 右侧：模板选择区域
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // 标题
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                  ? [
                                      theme.colorScheme.primaryContainer.withOpacity(0.3),
                                      theme.colorScheme.primaryContainer.withOpacity(0.2),
                                    ]
                                  : [
                                      theme.colorScheme.primaryContainer.withOpacity(0.3),
                                      theme.colorScheme.primaryContainer.withOpacity(0.2),
                                    ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                            Icons.auto_awesome,
                            size: 14,
                                    color: theme.colorScheme.primary,
                          ),
                                ),
                                const SizedBox(width: 8),
                          Text(
                            '快速模板',
                            style: TextStyle(
                                    fontWeight: FontWeight.w600,
                              fontSize: 12,
                                    color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    
                      // 模板列表
                    Expanded(
                      child: _buildTemplateList(context, state),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 底部区域：操作按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 重置按钮
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
                label: const Text(
                  '重置',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
              ),
              onPressed: () {
                // 弹出确认对话框
                _showResetConfirmationDialog(context, state);
              },
            ),
              const SizedBox(width: 16),
            // 保存按钮
            FilledButton.icon(
              icon: const Icon(Icons.save, size: 16),
                label: const Text(
                  '保存',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 1,
                  shadowColor: theme.colorScheme.shadow.withOpacity(0.3),
              ),
              onPressed: () {
                if (state.selectedFeatureType != null) {
                  context.read<PromptBloc>().add(
                    SavePromptRequested(
                      state.selectedFeatureType!,
                      _promptController.text,
                    ),
                  );
                  setState(() => _isEdited = false);
                  
                  // 显示保存成功提示
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            const Text('提示词已保存'),
                          ],
                        ),
                      behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(8),
                    ),
                  );
                }
              },
            ),
          ],
          ),
        ),
      ],
    );
  }
  
  /// 构建变量占位符标签
  List<Widget> _buildVariablePlaceholders(BuildContext context) {
    final theme = Theme.of(context);
    // 根据当前选择的功能类型显示不同的占位符
    final selectedType = context.read<PromptBloc>().state.selectedFeatureType;
    
    List<String> variables = [];
    
    // 根据不同功能类型提供不同的占位符
    if (selectedType == AIFeatureType.sceneToSummary) {
      variables = ['input', 'context']; // 场景生成摘要变量
    } else if (selectedType == AIFeatureType.summaryToScene) {
      variables = ['input', 'context']; // 摘要生成场景变量
    }
    
    return variables.map((variable) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tooltip(
          message: variable == 'input' ? '输入内容' : '上下文信息',
        child: InkWell(
          onTap: () {
            // 在光标位置插入变量
            final TextEditingController controller = _promptController;
            final int cursorPos = controller.selection.baseOffset;
            
            if (cursorPos >= 0) {
              final String text = controller.text;
              final String newText = text.substring(0, cursorPos) +
                  '{$variable}' +
                  text.substring(cursorPos);
              
              controller.text = newText;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: cursorPos + variable.length + 2), // +2 for the curly braces
              );
            } else {
              // 如果光标位置无效，则附加到末尾
              controller.text = controller.text + '{$variable}';
            }
            
            setState(() => _isEdited = true);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    variable == 'input' ? Icons.insert_drive_file : Icons.layers,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                Text(
                  '{$variable}',
                  style: TextStyle(
                      fontSize: 13,
                    fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
  
  /// 构建模板列表
  Widget _buildTemplateList(BuildContext context, PromptState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedType = state.selectedFeatureType;
    
    // 根据选择的功能类型选择合适的提示词模板列表
    final templates = selectedType == AIFeatureType.sceneToSummary
        ? state.summaryPrompts // 摘要模板
        : state.stylePrompts;   // 风格模板
    
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
              Icons.description_outlined,
                size: 36,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无可用模板',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请前往模板库添加模板',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // 使用ListView.builder确保模板列表可滚动
    return ListView.builder(
      itemCount: templates.length,
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final template = templates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.6),
              width: 1,
            ),
          ),
          color: isDark
              ? theme.colorScheme.surfaceContainerLow.withOpacity(0.7)
              : theme.colorScheme.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // 应用模板内容到编辑器
              _promptController.text = template.content;
              setState(() => _isEdited = true);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text('已应用模板: ${template.title}'),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(8),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            onLongPress: () {
              // 长按查看模板详情
              _showTemplateDetailDialog(context, template);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                        Icons.description_outlined,
                          size: 14,
                          color: theme.colorScheme.primary,
                      ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          template.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    template.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// 显示重置确认对话框
  void _showResetConfirmationDialog(BuildContext context, PromptState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surface,
        title: Row(
                            children: [
                              Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('确认重置'),
          ],
        ),
        content: const Text('确定要恢复为系统默认提示词吗？自定义内容将会丢失。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
                                style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
              ),
              FilledButton(
                onPressed: () {
                    Navigator.of(context).pop();
              if (state.selectedFeatureType != null) {
                context.read<PromptBloc>().add(
                  ResetPromptRequested(state.selectedFeatureType!),
                );
                setState(() => _isEdited = false);
              }
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 显示模板详情对话框
  void _showTemplateDetailDialog(BuildContext context, PromptItem template) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
              Icons.description_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                template.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerLow.withOpacity(0.7)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    template.content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '关闭',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.content_paste, size: 18),
            label: const Text('应用'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // 应用模板内容到当前编辑器
              if (context.read<PromptBloc>().state.selectedFeatureType != null) {
                _promptController.text = template.content;
                setState(() => _isEdited = true);
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
        children: [
                        Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text('已应用模板: ${template.title}'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(8),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// 处理复制到私有模板
  void _handleCopyToPrivate(PromptTemplate template) {
    // 调用BLoC复制模板
    context.read<PromptBloc>().add(
      CopyPublicTemplateRequested(templateId: template.id),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('已复制模板"${template.name}"到私有模板'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }
  
  /// 处理查看模板
  void _handleViewTemplate(PromptTemplate template) {
    setState(() {
      _currentEditingTemplate = template;
      _isEditingTemplate = true;
      _isNewTemplate = false;
    });
  }
  
  /// 处理编辑模板
  void _handleEditTemplate(PromptTemplate template) {
    setState(() {
      _currentEditingTemplate = template;
      _isEditingTemplate = true;
      _isNewTemplate = false;
    });
  }
  
  /// 处理删除模板
  void _handleDeleteTemplate(PromptTemplate template) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // 弹出确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surface,
        title: Row(
          children: [
            Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('确认删除'),
          ],
        ),
        content: Text('确定要删除模板"${template.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 调用BLoC删除模板
              this.context.read<PromptBloc>().add(
                DeleteTemplateRequested(templateId: template.id),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  /// 处理模板收藏状态切换
  void _handleToggleFavorite(PromptTemplate template) {
    context.read<PromptBloc>().add(
      ToggleTemplateFavoriteRequested(templateId: template.id),
    );
  }
  
  /// 取消模板编辑
  void _cancelTemplateEditing() {
    setState(() {
      _isEditingTemplate = false;
      _currentEditingTemplate = null;
      _isNewTemplate = false;
      _newTemplateFeatureType = null;
    });
    
    // 重置并重启动画，而不是销毁重建动画控制器
    _animationController.reset();
    
    // 确保在下一帧开始时动画能正常启动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }
  
  /// 处理模板保存成功
  void _handleTemplateSaveSuccess() {
    setState(() {
      _isEditingTemplate = false;
      _currentEditingTemplate = null;
      _isNewTemplate = false;
      _newTemplateFeatureType = null;
    });
    
    // 重置并重启动画，而不是销毁重建动画控制器
    _animationController.reset();
    
    // 确保在下一帧开始时动画能正常启动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
    
    // 刷新模板列表
    context.read<PromptBloc>().add(const LoadPromptTemplatesRequested());
    
    // 显示保存成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Text('模板已成功保存'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }
  
  /// 处理复制当前显示的模板到私有模板
  void _handleCopyCurrentToPrivate() {
    if (_currentEditingTemplate != null && _currentEditingTemplate!.isPublic) {
      context.read<PromptBloc>().add(
        CopyPublicTemplateRequested(templateId: _currentEditingTemplate!.id),
      );
      
      // 复制后取消编辑模式
      setState(() {
        _isEditingTemplate = false;
        _currentEditingTemplate = null;
      });
      
      // 重置并重启动画，而不是销毁重建动画控制器
      _animationController.reset();
      
      // 确保在下一帧开始时动画能正常启动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _animationController.forward();
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('已复制"${_currentEditingTemplate!.name}"到私有模板'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(8),
        ),
      );
    }
  }
  
  /// 创建新模板
  void _createNewTemplate(AIFeatureType featureType) {
    // 添加调试信息
    print('创建新模板, featureType: $featureType');
    
    // 确保featureType不为null
    if (featureType == null) {
      print('错误: featureType不能为null，使用默认值');
      featureType = AIFeatureType.sceneToSummary; // 使用默认值
    }
    
    // 创建临时空PromptTemplate用于调试
    try {
      // 先将动画重置到初始状态
      _animationController.reset();
      _animationController.value = 0.0;
      
      // 然后更新状态
      setState(() {
        _isEditingTemplate = true;
        _isNewTemplate = true;
        _currentEditingTemplate = null;
        _newTemplateFeatureType = featureType;
      });
      
      // 打印状态更新后的信息
      print('创建新模板状态已更新: _isEditingTemplate=$_isEditingTemplate, _isNewTemplate=$_isNewTemplate, '
            '_newTemplateFeatureType=$_newTemplateFeatureType');
      
      // 确保在下一帧开始时动画能正常启动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('准备启动动画...');
          _animationController.forward(from: 0.0);
          print('动画已启动: value=${_animationController.value}');
        }
      });
    } catch (e) {
      print('创建新模板时发生异常: $e');
    }
  }
} 