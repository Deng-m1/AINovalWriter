# 前端 AI 功能（场景摘要互转）及提示词管理 - 需求文档

## 1. 背景与目标

**背景:** AINovalWriter 的 Flutter 前端 (`AINoval`) 需要集成新增的后端 AI 功能，包括场景与摘要的相互生成，以及用户自定义 AI 功能提示词的管理。
**目标:** 本次迭代旨在为用户提供流畅、直观的界面来使用新的 AI 辅助创作功能，并在设置中提供对这些功能提示词的个性化管理能力。

**核心价值:**
* 在创作流程中无缝集成 AI 辅助（摘要生成、场景草稿生成）。
* 提供用户友好的界面来管理 AI 功能的提示词，实现个性化输出。
* 通过侧边编辑区展示 AI 生成结果，方便用户预览、修改和采纳。

## 2. 用户故事

* **作为一名作者，我希望** 在应用设置中找到一个专门的区域，可以查看和修改“场景生成摘要”和“摘要生成场景”功能的默认提示词，**以便** 让 AI 生成的内容更符合我的写作风格和需求。
* **作为一名作者，我希望** 在编辑某个场景时，可以轻松点击一个按钮，让 AI 快速为该场景生成摘要，并在一个临时的编辑区域展示给我，**以便** 我快速了解场景核心内容或将其用于章节概要。
* **作为一名作者，我希望** 在编辑器界面中，可以通过输入一段摘要或大纲，让 AI 帮我生成相应的场景内容草稿，并通过流式输出展示在侧边编辑区，**以便** 我能快速获得创作起点，并决定是否采纳或修改。
* **作为一名作者，我希望** 在 AI 功能调用时，能看到清晰的加载状态，并在出错时获得明确的提示，**以便** 了解当前系统状态。

## 3. 详细需求 (Flutter - AINoval)

### 3.1 用户提示词管理 UI

**3.1.1 功能入口**
* 在现有的设置界面 (`lib/screens/settings/settings_panel.dart`) 中新增一个可展开的区域或独立的标签页，标题为“AI 提示词管理” (AI Prompt Management)。

**3.1.2 UI 界面 (`PromptSettingsWidget` - 新建)**
* **功能点选择:** 提供下拉菜单 (`DropdownButton`) 或一组单选按钮 (`RadioButton`) 让用户选择要管理的 AI 功能点 (`AIFeatureType`: Scene-to-Summary, Summary-to-Scene)。
* **提示词编辑区:**
    * 显示当前选定功能点的提示词模板。
    * 使用一个多行文本输入框 (`TextField` with `maxLines` 设为适中值如 5-10，并允许滚动)，允许用户编辑。
    * **加载逻辑:** 当用户选择一个功能点时，调用 `PromptBloc` 获取对应的提示词（优先用户自定义，其次默认），填充到输入框。如果正在加载，显示 `LoadingIndicator`。
* **默认提示词展示:** 在编辑区下方，使用只读文本 (`SelectableText`) 展示该功能点的系统默认提示词，供用户参考。
* **操作按钮:**
    * **“保存” (`Save`):** (`ElevatedButton` 或 `TextButton`) 将当前编辑框中的内容保存为该功能点的用户自定义提示词。按钮在内容有修改且非加载/保存状态时启用。点击后按钮显示加载状态，完成后提示结果。
    * **“重置为默认” (`Reset to Default`):** (`TextButton` 或 `OutlinedButton`) 清除用户的自定义提示词，恢复使用系统默认。点击后弹出确认对话框 (`AlertDialog`)，确认后调用 BLoC 执行操作，按钮显示加载状态，完成后提示结果并刷新编辑框内容为默认值。
* **状态显示:**
    * 整体加载或操作时，可在区域顶部或按钮上显示 `CircularProgressIndicator`。
    * 操作成功或失败时，使用 `ScaffoldMessenger.of(context).showSnackBar(...)` 显示简短提示。
    * 获取提示词失败时，在编辑区位置显示错误信息和“重试”按钮。

**3.1.3 状态管理 (`PromptBloc` - 新建)**
* **依赖:** `PromptRepository` (新建)。
* **Models (`lib/models/prompt_models.dart` - 新建或扩展):**
    * `enum AIFeatureType { sceneToSummary, summaryToScene }` (与后端对应)
    * `class PromptData { final String userPrompt; final String defaultPrompt; final bool isCustomized; ... }`
* **State (`PromptState`):**
    * `promptStatus`: Enum (`initial`, `loading`, `success`, `failure`)
    * `prompts`: `Map<AIFeatureType, PromptData>`
    * `currentFeature`: `AIFeatureType?`
    * `errorMessage`: `String?`
    * `saveStatus`: Enum (`idle`, `saving`, `saveSuccess`, `saveFailure`)
* **Events (`PromptEvent`):**
    * `LoadAllPromptsRequested`
    * `SelectFeatureRequested(AIFeatureType featureType)`
    * `SavePromptRequested(AIFeatureType featureType, String promptText)`
    * `ResetPromptRequested(AIFeatureType featureType)`
* **逻辑:**
    * 初始化时触发 `LoadAllPromptsRequested`。
    * 处理事件，调用 `PromptRepository`。
    * 管理加载、保存、错误状态。
    * 更新 `prompts` Map 和 `saveStatus`。

**3.1.4 API 服务层 (`PromptRepository` - 新建)**
* **路径:** `lib/services/api_service/repositories/prompt_repository.dart`
* **接口 (`PromptRepository`):**
    * `Future<Map<AIFeatureType, PromptData>> getAllPrompts()` (调用 `GET /api/users/me/prompts` 和 `GET /api/users/me/prompts/{featureType}` 获取默认值组合)
    * `Future<PromptData> getPrompt(AIFeatureType featureType)` (调用 `GET /api/users/me/prompts/{featureType}`)
    * `Future<PromptData> savePrompt(AIFeatureType featureType, String promptText)` (调用 `PUT /api/users/me/prompts/{featureType}`)
    * `Future<void> deletePrompt(AIFeatureType featureType)` (调用 `DELETE /api/users/me/prompts/{featureType}`)
* **实现 (`PromptRepositoryImpl`):**
    * 依赖 `ApiClient`。
    * 实现接口方法，处理 API 请求和响应，进行 DTO 映射。
    * **DTOs (`lib/models/api/prompt_dtos.dart` - 新建):** 定义与后端 API 对应的 `UserPromptTemplateDto`, `PromptTemplateDto`, `UpdatePromptRequest`。

### 3.2 场景生成摘要功能

**3.2.1 功能入口**
* 在 `lib/screens/editor/components/scene_editor.dart` 内部，或者在 `lib/screens/editor/widgets/editor_toolbar.dart` 中，添加一个 `IconButton`。
    * 图标: 建议使用 `Icons.summarize` 或类似的图标。
    * Tooltip: "生成摘要"。
    * 状态: 当 `EditorBloc` 的 state 中有活动的 `sceneId` 时启用。

**3.2.2 交互流程与侧边编辑区 (`AISummarySidePanel` - 新建 Widget)**
1.  **触发:** 用户点击“生成摘要”按钮。
2.  **状态更新:** `EditorBloc` 发出 `SummarizeCurrentSceneRequested` 事件。按钮显示 `CircularProgressIndicator` 替代图标。
3.  **API 调用:** BLoC 内部调用 `EditorRepository.summarizeScene(sceneId)`。
4.  **结果处理:**
    * **成功:**
        * `EditorBloc` 更新状态 (`summaryGenerationStatus = success`, `generatedSummary = result`, `isSummaryPanelVisible = true`)。
        * `EditorScreen` 根据 `isSummaryPanelVisible` 状态，使用 `AnimatedSwitcher` 或类似方式，在屏幕右侧显示 `AISummarySidePanel`。
        * **`AISummarySidePanel` (位于 `lib/screens/editor/widgets/`)**:
            * 使用 `Card` 或 `Container` 包含内容，设置合适的 `padding` 和 `margin`。
            * 标题 `Text("AI 生成的摘要")`。
            * 可编辑的多行 `TextField`，使用 `TextEditingController` 初始化并显示 `generatedSummary`。
            * `Row` 包含操作按钮:
                * `IconButton(icon: Icon(Icons.copy), tooltip: "复制", onPressed: ...)`
                * `IconButton(icon: Icon(Icons.close), tooltip: "关闭", onPressed: () => context.read<EditorBloc>().add(CloseSummaryPanel()))`
            * (可选) `TextButton("重新生成", onPressed: ...)`
    * **失败:**
        * `EditorBloc` 更新状态 (`summaryGenerationStatus = failure`, `summaryError = errorMsg`, `isSummaryPanelVisible = false`)。
        * `EditorScreen` 或按钮处显示 `SnackBar` 提示错误信息。

**3.2.3 状态管理 (`EditorBloc` 增强)**
* **State (`EditorState` - `lib/blocs/editor/editor_state.dart`):**
    * 添加 `summaryGenerationStatus`: Enum (`idle`, `loading`, `success`, `failure`)。
    * 添加 `generatedSummary`: `String?`。
    * 添加 `summaryError`: `String?`。
    * 添加 `isSummaryPanelVisible`: `bool` (初始 false)。
* **Events (`EditorEvent` - `lib/blocs/editor/editor_event.dart`):**
    * 添加 `SummarizeCurrentSceneRequested`。
    * 添加 `CloseSummaryPanel`。
* **Bloc Logic (`EditorBloc` - `lib/blocs/editor/editor_bloc.dart`):**
    * 注册 `SummarizeCurrentSceneRequested` 事件处理器：
        * `emit(state.copyWith(summaryGenerationStatus: loading, isSummaryPanelVisible: false))`
        * 调用 `editorRepository.summarizeScene(currentSceneId)`。
        * 成功时 `emit(state.copyWith(status: success, generatedSummary: result, isSummaryPanelVisible: true))`。
        * 失败时 `emit(state.copyWith(status: failure, summaryError: error, isSummaryPanelVisible: false))`。
    * 注册 `CloseSummaryPanel` 事件处理器：
        * `emit(state.copyWith(isSummaryPanelVisible: false))`。

**3.2.4 API 服务层 (`EditorRepository` 增强)**
* **路径:** `lib/services/api_service/repositories/editor_repository.dart`
* **接口/实现:** 添加 `Future<String> summarizeScene(String sceneId)` 方法，调用后端 `POST /api/ai/scenes/{sceneId}/summarize`。
* **DTOs (`lib/models/api/editor_dtos.dart` - 新建或扩展):** 定义 `SummarizeSceneResponse`。

### 3.3 摘要生成场景功能

**3.3.1 功能入口**
* 在 `lib/screens/editor/widgets/editor_toolbar.dart` 中添加一个 `IconButton`。
    * 图标: 建议使用 `Icons.auto_stories` 或 `Icons.create`。
    * Tooltip: "AI 生成场景"。
    * 状态: 始终启用（或当有 Novel 加载时启用）。

**3.3.2 输入对话框 (`GenerateSceneDialog` - 新建 Widget)**
* **路径:** `lib/screens/editor/widgets/generate_scene_dialog.dart`
* **触发:** 用户点击“AI 生成场景”按钮时，使用 `showDialog(...)` 显示此 Widget。
* **UI:**
    * 使用 `AlertDialog` 或自定义 Dialog 布局。
    * `TextField` 用于输入“摘要/大纲” (多行)。
    * (可选) `DropdownButtonFormField` 用于选择“目标章节” (数据源需要从 `EditorBloc` 获取当前小说的章节列表)。
    * `TextField` 用于输入“风格指令” (可选)。
    * “生成”按钮 (`ElevatedButton`): 点击时 `Navigator.pop(context, result)` 返回输入内容。
    * “取消”按钮 (`TextButton`): 点击时 `Navigator.pop(context)`。
* **数据传递:** 通过 `Navigator.pop` 将用户输入的数据（summary, chapterId, style）返回给调用处。

**3.3.3 交互流程与侧边编辑区 (`AISceneGenerationSidePanel` - 新建 Widget)**
1.  **触发:** `EditorScreen` 收到对话框返回的数据后，`EditorBloc` 发出 `GenerateSceneFromSummaryRequested` 事件。
2.  **状态更新:** `EditorBloc` 进入 `streaming` 状态，UI 在侧边栏位置显示 `AISceneGenerationSidePanel` 并显示加载状态。
3.  **API 调用 (SSE):** BLoC 内部调用 `EditorRepository.generateSceneFromSummaryStream(...)`，并监听返回的 `Stream<String>`。
4.  **结果处理 (流式):**
    * **打开侧边编辑区:** (`AISceneGenerationSidePanel` 位于 `lib/screens/editor/widgets/`)。
    * **`AISceneGenerationSidePanel` UI:**
        * 标题 `Text("AI 生成的场景")`。
        * 状态显示: 根据 `sceneGenerationStatus` 显示 "正在生成...", "已完成", "已停止", 或错误信息。
        * 多行 `TextField`，使用 `TextEditingController`。当 BLoC 状态更新 `generatedSceneContent` 时，更新 `controller.text`。
        * `Row` 包含操作按钮:
            * `IconButton(icon: Icon(Icons.copy), tooltip: "复制", onPressed: ...)`
            * `IconButton(icon: Icon(Icons.add_circle_outline), tooltip: "插入原文", onPressed: ...)` (仅在 `completed` 或 `stopped` 状态可用)
            * `IconButton(icon: Icon(Icons.stop_circle_outlined), tooltip: "停止生成", onPressed: ...)` (仅在 `streaming` 状态可用)
            * `IconButton(icon: Icon(Icons.close), tooltip: "关闭", onPressed: () => context.read<EditorBloc>().add(CloseSceneGenerationPanel()))`
    * **BLoC 监听 Stream:**
        * `onData`: `add(SceneChunkReceived(chunk))` -> BLoC 累加 `chunk` 到 `generatedSceneContent` 并 `emit` 新状态。
        * `onError`: `add(SceneGenerationFailed(error))` -> BLoC 更新状态为 `failure`。
        * `onDone`: `add(SceneGenerationCompleted())` -> BLoC 更新状态为 `completed`。

**3.3.4 状态管理 (`EditorBloc` 增强)**
* **State (`EditorState`):**
    * 添加 `sceneGenerationStatus`: Enum (`idle`, `streaming`, `completed`, `failure`, `stopped`)。
    * 添加 `generatedSceneContent`: `String` (初始 "")。
    * 添加 `sceneGenerationError`: `String?`。
    * 添加 `isSceneGenerationPanelVisible`: `bool` (初始 false)。
    * 添加 `StreamSubscription? sceneGenerationSubscription`。
* **Events (`EditorEvent`):**
    * 添加 `GenerateSceneFromSummaryRequested(String summary, String? chapterId, String? style)`。
    * 添加 `_SceneChunkReceived(String chunk)` (内部事件)。
    * 添加 `_SceneGenerationCompleted` (内部事件)。
    * 添加 `_SceneGenerationFailed(String error)` (内部事件)。
    * 添加 `StopSceneGeneration`。
    * 添加 `CloseSceneGenerationPanel`。
* **Bloc Logic (`EditorBloc`):**
    * 注册 `GenerateSceneFromSummaryRequested` 处理器：
        * `emit(state.copyWith(status: streaming, isPanelVisible: true, content: ""))`。
        * 取消之前的 `sceneGenerationSubscription` (如果存在)。
        * 调用 `editorRepository.generateSceneFromSummaryStream(...)` 并 `listen`：
            * `onData: (chunk) => add(_SceneChunkReceived(chunk))`
            * `onError: (e) => add(_SceneGenerationFailed(e.toString()))`
            * `onDone: () => add(_SceneGenerationCompleted())`
        * 保存新的 `StreamSubscription`。
    * 注册 `_SceneChunkReceived` 处理器: `emit(state.copyWith(content: state.content + chunk))`。
    * 注册 `_SceneGenerationCompleted` 处理器: `emit(state.copyWith(status: completed))`，并取消 subscription。
    * 注册 `_SceneGenerationFailed` 处理器: `emit(state.copyWith(status: failure, error: error))`，并取消 subscription。
    * 注册 `StopSceneGeneration` 处理器: 取消 subscription，`emit(state.copyWith(status: stopped))`。
    * 注册 `CloseSceneGenerationPanel` 处理器: 取消 subscription，`emit(state.copyWith(isPanelVisible: false, status: idle))`。

**3.3.5 API 服务层 (`EditorRepository` 增强)**
* **接口/实现:** 添加 `Stream<String> generateSceneFromSummaryStream(String novelId, String summary, String? chapterId, String? style)` 方法。
    * 依赖 `SseClient` (`lib/services/api_service/base/sse_client.dart`)。
    * 构建 `GenerateSceneFromSummaryRequest` DTO。
    * 调用 `SseClient.connect(url, method: 'POST', body: requestDto)` 连接后端 SSE 端点。
    * 解析 SSE 事件流，过滤出 `event: message` 的事件，提取 `data` 部分，作为 `Stream<String>` 返回。需要处理 JSON 格式的错误事件。
* **DTOs (`lib/models/api/editor_dtos.dart`):** 定义 `GenerateSceneFromSummaryRequest`。

### 3.4 UI/UX 要求

* **加载状态:** 所有异步操作必须有清晰的加载指示器 (`CircularProgressIndicator` 或类似)。流式生成应有明确的“正在生成...”提示，完成后提示“已完成”。
* **错误处理:** API 调用失败或 SSE 错误，应使用 `SnackBar` 或在侧边栏内显示用户友好的错误信息。
* **侧边编辑区:**
    * 应从 `EditorScreen` 右侧滑入/滑出，或在固定区域显示/隐藏。
    * 宽度适中，不遮挡过多主编辑区。
    * 文本区域 (`TextField`) 应设为 `readOnly: false` 以允许用户修改，但主要交互通过按钮完成。
    * 按钮 Tooltip 清晰。
* **按钮状态:** 动态启用/禁用按钮，例如“插入原文”仅在生成完成/停止后可用，“停止生成”仅在流式进行中可用。
* **响应式:** 侧边栏和对话框在不同屏幕尺寸下应表现良好。

## 4. 非功能性需求

* **性能:** 侧边栏的流式文本更新应流畅，不卡顿主线程。
* **状态一致性:** BLoC 状态与 UI 显示严格同步。
* **错误边界:** 使用 `BlocBuilder` / `BlocListener` 时，妥善处理可能的状态变化和错误。

## 5. 依赖与影响

* **后端:** 依赖后端 API 的正确实现，包括 SSE 接口的事件格式 (`message`, `error`, `complete`)。
* **Flutter 项目:**
    * **新增:** `PromptBloc`, `PromptRepository`, `PromptSettingsWidget`, `AISummarySidePanel`, `GenerateSceneDialog`, `AISceneGenerationSidePanel`, 相关 Models/DTOs。
    * **修改:** `EditorBloc`, `EditorState`, `EditorEvent`, `EditorRepository`, `EditorScreen`, `SettingsPanel`, `EditorToolbar`, `SceneEditor`。
    * **可能修改:** `SseClient` (确保能处理 `error`, `complete` 事件和 JSON 错误数据)。
