# AI模型提供商架构设计文档

## 1. 概述

本文档描述了AINoval系统中AI模型提供商部分的架构设计。该设计遵循多种设计模式，提供了一个灵活、可扩展和可维护的架构，能够轻松集成多种AI模型提供商（如OpenAI、Anthropic、Google Gemini等）。

## 2. 架构目标

- **模块化**: 各个组件之间高内聚、低耦合
- **可扩展性**: 能够轻松添加新的AI模型提供商
- **灵活性**: 支持不同的实现方式和功能
- **可测试性**: 各组件可独立测试
- **可配置性**: 运行时可配置系统行为

## 3. 设计模式应用

本架构应用了以下设计模式：

- **工厂模式（Factory Pattern）**: 使用`AIModelProviderFactory`创建不同的AI模型提供商实例
- **策略模式（Strategy Pattern）**: 使用`ProviderCapabilityDetector`定义不同提供商的能力检测策略
- **门面模式（Facade Pattern）**: 使用`ProviderCapabilityService`简化提供商能力的使用
- **注册表模式（Registry Pattern）**: 使用`AIProviderRegistry`统一管理提供商能力信息
- **构建者模式（Builder Pattern）**: 使用`ProxyConfig.builder()`创建配置对象

## 4. 核心组件

### 4.1 模型与数据

- **ModelListingCapability**: 枚举，定义了不同的模型列表能力（无列表、需要密钥、不需要密钥）
- **ModelInfo**: 模型信息类，包含模型ID、名称、描述、价格等信息
- **ProxyConfig**: 代理配置类，封装代理服务器设置

### 4.2 工厂

- **AIModelProviderFactory**: 负责创建各种AI提供商实例，隐藏具体实现细节

### 4.3 提供商能力

- **ProviderCapabilityDetector**: 接口，定义了提供商能力检测的策略
- **OpenAICapabilityDetector**: 实现类，针对OpenAI提供商的能力检测
- **ProviderCapabilityService**: 服务类，整合注册表和多个能力检测器

### 4.4 注册表

- **AIProviderRegistry**: 注册表类，存储提供商能力、默认端点、默认模型等信息

### 4.5 配置

- **ProviderServiceConfig**: 配置类，提供全局的AI提供商服务设置

### 4.6 控制器

- **ProviderCapabilityController**: REST控制器，提供能力查询和API密钥测试接口

## 5. 交互流程

### 5.1 初始化流程

1. 系统启动时，`AIProviderRegistry`初始化默认提供商能力和端点
2. `ProviderCapabilityService`引用所有的`ProviderCapabilityDetector`实现
3. `ProviderCapabilityService`初始化时，将检测器的默认模型注册到注册表中

### 5.2 提供商实例创建流程

1. 客户端请求创建AI提供商实例
2. `AIServiceImpl`调用`AIModelProviderFactory.createProvider()`
3. 工厂根据提供商类型创建相应的实例并返回

### 5.3 模型列表获取流程

1. 客户端请求获取某个提供商的模型列表
2. 系统先从`ProviderCapabilityService`获取提供商能力
3. 根据提供商能力，决定是否需要API密钥
4. 使用适当的方法获取模型列表并返回

### 5.4 API密钥测试流程

1. 客户端提交API密钥测试请求
2. `ProviderCapabilityController`接收请求并调用`ProviderCapabilityService`
3. 服务通过适当的检测器测试API密钥并返回结果

## 6. 扩展方式

### 6.1 添加新的AI提供商

1. 创建提供商的LangChain4j实现或原生实现
2. 创建提供商的能力检测器实现
3. 在工厂类中添加创建新提供商的代码
4. 在注册表初始化时添加新提供商的默认设置

### 6.2 添加新的能力检测

1. 在`ProviderCapabilityDetector`接口中添加新的方法
2. 在各实现类中实现该方法
3. 在`ProviderCapabilityService`中添加新的服务方法

## 7. 配置项

- **ai.use-langchain4j**: 是否使用LangChain4j库实现
- **ai.enable-provider-auto-detection**: 是否启用提供商自动检测
- **ai.default-provider**: 默认提供商
- **ai.default-model**: 默认模型
- **ai.connect-timeout**: 连接超时（秒）
- **ai.read-timeout**: 读取超时（秒）
- **proxy.enabled**: 是否启用代理
- **proxy.host**: 代理主机
- **proxy.port**: 代理端口

## 8. 优势与收益

- **统一接口**: 各提供商实现相同接口，使用方式一致
- **能力感知**: 自动识别提供商能力，减少配置工作
- **简化扩展**: 添加新提供商只需几个简单步骤
- **运行时配置**: 可在运行时调整系统行为
- **健壮性**: 更好地处理错误和异常情况

## 9. 注意事项

- 提供商API可能随时变化，需要定期更新实现
- API密钥安全存储非常重要
- 代理配置需要根据实际网络环境调整 