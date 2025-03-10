# AINoval - AI驱动的小说创作平台

AINoval是一个专为小说创作者设计的AI辅助写作平台，它提供了直观的创作界面、强大的知识库管理以及智能的AI辅助功能，帮助作家更高效地进行创作。

## 主要功能

### 第一迭代（当前版本）

- **小说列表管理**：查看、创建、搜索和分类您的所有小说作品
- **基础编辑器**：支持富文本编辑，包括文本格式化、字数统计和自动保存
- **个性化设置**：调整字体大小、行间距、主题等编辑器参数

### 计划中的功能

- AI聊天辅助：获取智能写作建议、内容分析和续写提示
- 小说结构计划：章节和场景管理，支持拖拽重排
- Codex知识库：管理小说中的人物、地点、情节等元素
- 文件导出：支持多种格式导出您的作品

## 技术栈

- **前端框架**：Flutter
- **状态管理**：flutter_bloc
- **文本编辑**：flutter_quill
- **本地存储**：Hive/SharedPreferences

## 开始使用

### 环境要求

- Flutter 3.0.0或更高版本
- Dart 3.0.0或更高版本

### 运行前的准备工作

在首次运行前，需要创建以下资源目录结构：

```
AINoval/
├── assets/
│   ├── images/    # 图片资源目录
│   ├── icons/     # 图标资源目录
│   └── fonts/     # 字体资源目录
│       ├── Roboto-Regular.ttf    # 基础字体文件
│       ├── Roboto-Bold.ttf       # 粗体字体文件
│       ├── Roboto-Italic.ttf     # 斜体字体文件
│       ├── NotoSansSC-Regular.ttf # 中文字体文件
│       └── NotoSansSC-Bold.ttf    # 中文粗体字体文件
```

可以从Google Fonts下载所需的字体文件，或使用系统自带字体。

### 运行项目

1. 克隆仓库
   ```
   git clone https://github.com/yourusername/ainoval.git
   ```

2. 安装依赖
   ```
   cd ainoval
   flutter pub get
   ```

3. 运行应用
   ```
   flutter run
   ```

## 项目结构

```
lib/
├── blocs/               # 业务逻辑组件
├── models/              # 数据模型
├── repositories/        # 数据仓库
├── screens/             # 页面
│   ├── novel_list/      # 小说列表页面
│   ├── editor/          # 编辑器页面
├── services/            # 服务
├── utils/               # 工具类
└── main.dart            # 应用入口
```

## 贡献

如果您想为AINoval做出贡献，请查看我们的贡献指南和行为准则。

## 许可

本项目采用MIT许可证 - 查看LICENSE文件了解详情。

## 联系我们

如有问题或建议，请通过以下方式联系我们：
- 电子邮件: contact@ainoval.com
- GitHub问题: [https://github.com/yourusername/ainoval/issues](https://github.com/yourusername/ainoval/issues)

## 项目结构

项目采用了清晰的分层架构：

- **BLoC模式**：用于状态管理
- **Repository模式**：用于数据访问
- **服务层**：提供API和本地存储服务

## 环境配置

项目支持两种环境：

1. **开发环境**：使用模拟数据，适合本地开发和测试
2. **生产环境**：连接真实API，适合生产部署

环境配置在 `lib/config/app_config.dart` 文件中定义：

```dart
/// 应用环境枚举
enum Environment {
  development,
  production,
}

/// 应用配置类
class AppConfig {
  /// 当前环境
  static Environment _environment = kDebugMode ? Environment.development : Environment.production;
  
  /// 是否应该使用模拟数据
  static bool get shouldUseMockData => _forceMockData || _environment == Environment.development;
  
  /// API基础URL
  static String get apiBaseUrl {
    switch (_environment) {
      case Environment.development:
        return 'http://localhost:8080/api';
      case Environment.production:
        return 'https://api.ainoval.com/api';
    }
  }
}
```

## 模拟数据

模拟数据集中在 `lib/services/mock_data_service.dart` 文件中，提供了以下功能：

- 小说数据模拟
- 场景内容模拟
- 聊天会话模拟
- 修订历史模拟

使用模拟数据的好处：

1. 无需依赖后端服务即可开发前端
2. 快速测试各种场景和边缘情况
3. 提供一致的测试数据

## 开发指南

### 运行项目

```bash
# 获取依赖
flutter pub get

# 运行项目
flutter run
```

### 切换环境

在代码中手动切换环境：

```dart
// 切换到开发环境（使用模拟数据）
AppConfig.setEnvironment(Environment.development);

// 切换到生产环境（使用真实API）
AppConfig.setEnvironment(Environment.production);

// 强制使用模拟数据（无论环境如何）
AppConfig.setUseMockData(true);
```

### 添加新的模拟数据

1. 在 `MockDataService` 类中添加新的方法
2. 确保方法返回与真实API相同的数据结构
3. 在相应的服务中使用模拟数据

## 最佳实践

1. **环境区分**：始终使用 `AppConfig.shouldUseMockData` 来判断是否使用模拟数据
2. **错误处理**：在API请求失败时回退到模拟数据
3. **数据一致性**：确保模拟数据与真实API返回的数据结构一致
4. **本地缓存**：使用 `LocalStorageService` 缓存数据，减少API请求
5. **数据流向**：遵循 Repository -> Service -> Model 的数据流向
6. **异常处理**：在每个层级都进行适当的异常处理，确保应用稳定性
7. **模块化设计**：保持各个模块的独立性，便于维护和扩展 