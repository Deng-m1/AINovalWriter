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