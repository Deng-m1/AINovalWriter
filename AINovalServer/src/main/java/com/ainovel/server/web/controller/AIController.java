package com.ainovel.server.web.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.BaseAIRequest;
import com.ainovel.server.domain.model.User;
import com.ainovel.server.domain.model.User.AIModelConfig;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.UserService;
import com.ainovel.server.service.ai.GeminiModelProvider;
import com.ainovel.server.service.ai.SiliconFlowModelProvider;
import com.ainovel.server.web.dto.ApiKeyValidationRequest;
import com.ainovel.server.web.dto.ApiKeyValidationResponse;
import com.ainovel.server.web.dto.ProxyConfigRequest;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 基础AI控制器
 * 只处理与AI模型交互的基础功能，不包含业务逻辑
 */
@RestController
@RequestMapping("/api/ai")
public class AIController {
    @Qualifier("aiServiceImpl")
    private final AIService aiService;
    private final UserService userService;
    
    @Autowired
    public AIController(@Qualifier("AIServiceImpl") AIService aiService, UserService userService) {
        this.aiService = aiService;
        this.userService = userService;
    }
    
    /**
     * 生成内容（非流式）
     * @param request 基础AI请求
     * @return AI响应
     */
    @PostMapping("/generate")
    public Mono<AIResponse> generateContent(@RequestBody BaseAIRequest request) {
        return aiService.generateContent(request);
    }
    
    /**
     * 生成内容（流式）
     * @param request 基础AI请求
     * @return 流式AI响应
     */
    @PostMapping(value = "/generate/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> generateContentStream(@RequestBody BaseAIRequest request) {
        return aiService.generateContentStream(request)
                .map(content -> ServerSentEvent.<String>builder()
                        .data(content)
                        .build());
    }
    
    /**
     * 获取可用的AI模型列表
     * @return 模型列表
     */
    @GetMapping("/models")
    public Flux<String> getAvailableModels() {
        return aiService.getAvailableModels();
    }
    
    /**
     * 获取可用的AI提供商列表
     * @return 提供商列表
     */
    @GetMapping("/providers")
    public Flux<String> getAvailableProviders() {
        return aiService.getAvailableProviders();
    }
    
    /**
     * 获取提供商支持的模型列表
     * @param provider 提供商名称
     * @return 模型列表
     */
    @GetMapping("/providers/{provider}/models")
    public Flux<String> getModelsForProvider(@PathVariable String provider) {
        return aiService.getModelsForProvider(provider);
    }
    
    /**
     * 获取模型分组信息
     * @return 模型分组信息
     */
    @GetMapping("/model-groups")
    public Map<String, List<String>> getModelGroups() {
        return aiService.getModelGroups();
    }
    
    /**
     * 获取模型的提供商名称
     * @param modelName 模型名称
     * @return 提供商名称
     */
    @GetMapping("/models/{modelName}/provider")
    public String getProviderForModel(@PathVariable String modelName) {
        return aiService.getProviderForModel(modelName);
    }
    
    /**
     * 估算请求成本
     * @param request 基础AI请求
     * @return 估算成本（单位：元）
     */
    @PostMapping("/estimate-cost")
    public Mono<Double> estimateCost(@RequestBody BaseAIRequest request) {
        return aiService.estimateCost(request);
    }
    
    /**
     * 验证API密钥是否有效
     * @param request 验证请求
     * @return 验证结果
     */
    @PostMapping("/validate-api-key")
    public Mono<ApiKeyValidationResponse> validateApiKey(@RequestBody ApiKeyValidationRequest request) {
        return aiService.validateApiKey(
                request.getUserId(),
                request.getProvider(),
                request.getModelName(),
                request.getApiKey()
        )
        .map(isValid -> new ApiKeyValidationResponse(isValid));
    }
    
    /**
     * 清除用户的模型提供商缓存
     * @param userId 用户ID
     * @return 操作结果
     */
    @PostMapping("/user/{userId}/clear-cache")
    public Mono<Void> clearUserProviderCache(@PathVariable String userId) {
        return aiService.clearUserProviderCache(userId);
    }
    
    /**
     * 清除所有模型提供商缓存
     * @return 操作结果
     */
    @PostMapping("/clear-all-cache")
    public Mono<Void> clearAllProviderCache() {
        return aiService.clearAllProviderCache();
    }
    
    /**
     * 设置模型提供商的代理
     * @param userId 用户ID
     * @param modelName 模型名称
     * @param request 代理配置请求
     * @return 操作结果
     */
    @PostMapping("/user/{userId}/models/{modelName}/set-proxy")
    public Mono<Void> setModelProviderProxy(
            @PathVariable String userId,
            @PathVariable String modelName,
            @RequestBody ProxyConfigRequest request) {
        return aiService.setModelProviderProxy(
                userId,
                modelName,
                request.getProxyHost(),
                request.getProxyPort());
    }
    
    /**
     * 禁用模型提供商的代理
     * @param userId 用户ID
     * @param modelName 模型名称
     * @return 操作结果
     */
    @PostMapping("/user/{userId}/models/{modelName}/disable-proxy")
    public Mono<Void> disableModelProviderProxy(
            @PathVariable String userId,
            @PathVariable String modelName) {
        return aiService.disableModelProviderProxy(userId, modelName);
    }
    
    /**
     * 检查模型提供商的代理是否已启用
     * @param userId 用户ID
     * @param modelName 模型名称
     * @return 是否已启用
     */
    @GetMapping("/user/{userId}/models/{modelName}/proxy-status")
    public Mono<Boolean> isModelProviderProxyEnabled(
            @PathVariable String userId,
            @PathVariable String modelName) {
        return aiService.isModelProviderProxyEnabled(userId, modelName);
    }
    
    /**
     * 获取用户的AI模型配置列表
     * @param userId 用户ID
     * @return AI模型配置列表
     */
    @GetMapping("/user/{userId}/models")
    public Flux<AIModelConfig> getUserAIModels(@PathVariable String userId) {
        return userService.getUserAIModelConfigs(userId);
    }
    
    /**
     * 获取用户的默认AI模型配置
     * @param userId 用户ID
     * @return 默认AI模型配置
     */
    @GetMapping("/user/{userId}/default-model")
    public Mono<AIModelConfig> getUserDefaultAIModel(@PathVariable String userId) {
        return userService.getUserDefaultAIModelConfig(userId);
    }
    
    /**
     * 添加AI模型配置
     * @param userId 用户ID
     * @param config AI模型配置
     * @return 更新后的用户
     */
    @PostMapping("/user/{userId}/models")
    public Mono<AIModelConfig> addAIModelConfig(@PathVariable String userId, @RequestBody AIModelConfig config) {
        return userService.addAIModelConfig(userId, config)
                .map(user -> user.getAIModelConfig(config.getProvider(), config.getModelName()));
    }
    
    /**
     * 设置默认AI模型配置
     * @param userId 用户ID
     * @param configIndex 配置索引
     * @return 更新后的用户
     */
    @PostMapping("/user/{userId}/models/{configIndex}/set-default")
    public Mono<AIModelConfig> setDefaultAIModelConfig(@PathVariable String userId, @PathVariable int configIndex) {
        return userService.setDefaultAIModelConfig(userId, configIndex)
                .map(User::getDefaultAIModelConfig);
    }
    
    /**
     * 删除AI模型配置
     * @param userId 用户ID
     * @param configIndex 配置索引
     * @return 操作结果
     */
    @PostMapping("/user/{userId}/models/{configIndex}/delete")
    public Mono<Void> deleteAIModelConfig(@PathVariable String userId, @PathVariable int configIndex) {
        return userService.deleteAIModelConfig(userId, configIndex)
                .then();
    }
    
    /**
     * 测试Gemini API连接
     * @param apiKey Gemini API密钥
     * @param modelName 模型名称（可选，默认为gemini-2.0-pro）
     * @return 测试结果
     */
    @GetMapping("/test/gemini")
    public Mono<String> testGeminiApi(
            @RequestParam("apiKey") String apiKey, @RequestParam(name = "modelName", required = false) String modelName) {
        
        // 创建一个临时的GeminiModelProvider实例进行测试
        GeminiModelProvider geminiProvider = new GeminiModelProvider(modelName, apiKey, null);
        return geminiProvider.testGeminiApi();
    }

    @GetMapping("/test/siliconFlow")
    public Mono<String> testSiliconFlowApi(
            @RequestParam("apiKey") String apiKey, @RequestParam(name = "modelName", required = false) String modelName) {

        // 创建一个临时的SiliconFlowModelProvider实例进行测试
        SiliconFlowModelProvider siliconFlowProvider = new SiliconFlowModelProvider(modelName, apiKey, null);
        return siliconFlowProvider.testSiliconFlowApi();
    }
} 