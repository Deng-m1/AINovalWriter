# API服务架构

API服务是AINoval应用程序与后端服务器通信的核心组件，负责处理网络请求和数据转换。

## 架构设计

API服务采用分层架构设计，分为四个层次：

### 1. 基础层 (Base Layer)

基础层包含API客户端和异常处理：

- **ApiClient**: 基于Dio的HTTP客户端，提供基本的网络请求功能
- **MockClient**: 模拟客户端，用于开发和测试
- **ApiException**: 统一的API异常类，用于处理和传递错误信息

### 2. 仓库层 (Repository Layer)

仓库层定义了数据访问接口和实现：

- **接口**:
  - `NovelRepository`: 小说相关操作接口
  - `ChatRepository`: 聊天相关操作接口
  - `EditorRepository`: 编辑器相关操作接口

- **实现**:
  - `NovelRepositoryImpl`: 小说仓库实现
  - `ChatRepositoryImpl`: 聊天仓库实现
  - `EditorRepositoryImpl`: 编辑器仓库实现
  - `MockNovelRepository`: 模拟小说仓库实现
  - `MockChatRepository`: 模拟聊天仓库实现
  - `MockEditorRepository`: 模拟编辑器仓库实现

### 3. 工厂层 (Factory Layer)

工厂层负责创建和管理仓库实例：

- **ApiServiceFactory**: 单例工厂类，负责创建和管理客户端和仓库实例

### 4. 服务层 (Service Layer)

服务层提供统一的API接口：

- **ApiService**: 对外统一接口，封装所有与后端通信的操作

## 使用方法

### 基本用法

```dart
// 创建API服务实例
final apiService = ApiService();

// 获取小说列表
final novels = await apiService.fetchNovels();

// 创建新小说
final newNovel = await apiService.createNovel('我的新小说');

// 获取聊天会话列表
final chatSessions = await apiService.fetchChatSessions(novelId);

// 释放资源
apiService.dispose();
```

### 依赖注入（用于测试）

```dart
// 创建模拟工厂
final mockFactory = ApiServiceFactory(useMock: true);

// 使用模拟工厂创建API服务
final apiService = ApiService(factory: mockFactory);

// 使用API服务（将返回模拟数据）
final novels = await apiService.fetchNovels();
```

### 错误处理

API服务使用`ApiException`类统一处理错误：

```dart
try {
  final novel = await apiService.fetchNovel('non-existent-id');
} on ApiException catch (e) {
  print('API错误: ${e.statusCode} - ${e.message}');
} catch (e) {
  print('其他错误: $e');
}
```

### 模拟数据

API服务支持使用模拟数据，便于开发和测试：

```dart
// 创建使用模拟数据的API服务
final mockApiService = ApiService(factory: ApiServiceFactory(useMock: true));

// 使用API服务（将返回模拟数据）
final novels = await apiService.fetchNovels(); // 返回模拟小说列表
```

## 架构优势

1. **模块化**: 每个组件都有明确的职责，便于维护和扩展
2. **可测试性**: 通过接口和依赖注入，便于单元测试
3. **可维护性**: 清晰的分层结构，降低代码复杂度
4. **灵活性**: 可以轻松切换不同的实现（如真实API和模拟数据）
5. **统一错误处理**: 通过`ApiException`类统一处理错误
6. **支持模拟数据**: 便于开发和测试

## 重构说明

API服务已经完成重构，主要改进包括：

1. 采用Dio包提供更高级的HTTP功能
2. 实现仓库模式，使代码更加模块化
3. 分离接口和实现，提高可测试性
4. 使用工厂模式管理仓库实例
5. 统一错误处理
6. 支持模拟数据
7. 更清晰的代码结构

新的架构设计使API服务更加模块化、可测试、可维护和灵活，可以轻松扩展新功能。