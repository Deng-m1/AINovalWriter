package com.ainovel.server.service.ai.langchain4j;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.WebClient;

import com.ainovel.server.config.ProxyConfig;
import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.ModelInfo;

import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * TogetherAI的LangChain4j实现 使用OpenAI兼容API
 */
@Slf4j
public class TogetherAILangChain4jModelProvider extends LangChain4jModelProvider {

    private static final String DEFAULT_API_ENDPOINT = "https://api.together.xyz/v1";
    private static final Map<String, Double> TOKEN_PRICES;

    static {
        Map<String, Double> prices = new HashMap<>();
        prices.put("mistralai/Mixtral-8x7B-Instruct-v0.1", 0.0006);
        prices.put("meta-llama/Llama-3-70b-chat", 0.0009);
        prices.put("meta-llama/Llama-3-8b-chat", 0.0002);
        prices.put("google/gemma-7b-it", 0.0001);
        prices.put("Qwen/Qwen2.5-7B-Instruct", 0.0002);
        TOKEN_PRICES = Collections.unmodifiableMap(prices);
    }

    /**
     * 构造函数
     *
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     * @param proxyConfig 代理配置
     */
    public TogetherAILangChain4jModelProvider(
            String modelName,
            String apiKey,
            String apiEndpoint,
            ProxyConfig proxyConfig
    ) {
        super("togetherai", modelName, apiKey, apiEndpoint, proxyConfig);
    }

    @Override
    protected void initModels() {
        try {
            // 获取API端点
            String baseUrl = getApiEndpoint(DEFAULT_API_ENDPOINT);

            // 配置系统代理
            configureSystemProxy();

            log.info("初始化TogetherAI模型: {}, API端点: {}", modelName, baseUrl);

            // 创建非流式模型
            this.chatModel = OpenAiChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .baseUrl(baseUrl)
                    .logRequests(true)
                    .logResponses(true)
                    .timeout(Duration.ofSeconds(300))
                    .build();

            // 创建流式模型
            this.streamingChatModel = OpenAiStreamingChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .baseUrl(baseUrl)
                    .logRequests(true)
                    .logResponses(true)
                    .timeout(Duration.ofSeconds(300))
                    .build();

            log.info("TogetherAI模型初始化成功: {}", modelName);
        } catch (Exception e) {
            log.error("初始化TogetherAI模型时出错: {}", e.getMessage(), e);
            this.chatModel = null;
            this.streamingChatModel = null;
        }
    }

    @Override
    public Mono<Double> estimateCost(AIRequest request) {
        // 获取模型价格（每1000个令牌的美元价格）
        double pricePerThousandTokens = TOKEN_PRICES.getOrDefault(modelName, 0.0006);

        // 估算输入令牌数
        int inputTokens = estimateInputTokens(request);

        // 估算输出令牌数
        int outputTokens = request.getMaxTokens() != null ? request.getMaxTokens() : 1000;

        // 计算总令牌数
        int totalTokens = inputTokens + outputTokens;

        // 计算成本（美元）
        double costInUSD = (totalTokens / 1000.0) * pricePerThousandTokens;

        // 转换为人民币（假设汇率为7.2）
        double costInCNY = costInUSD * 7.2;

        return Mono.just(costInCNY);
    }

    @Override
    public Flux<ModelInfo> listModelsWithApiKey(String apiKey, String apiEndpoint) {
        if (isApiKeyEmpty(apiKey)) {
            return Flux.error(new RuntimeException("API密钥不能为空"));
        }

        log.info("获取TogetherAI模型列表");

        // 获取API端点
        String baseUrl = apiEndpoint != null && !apiEndpoint.trim().isEmpty() ?
                apiEndpoint : DEFAULT_API_ENDPOINT;

        // 创建WebClient
        WebClient webClient = WebClient.builder()
                .baseUrl(baseUrl)
                .build();

        // 调用TogetherAI API获取模型列表
        return webClient.get()
                .uri("/models")
                .header("Authorization", "Bearer " + apiKey)
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .bodyToMono(String.class)
                .flatMapMany(response -> {
                    try {
                        // 解析响应
                        log.debug("TogetherAI模型列表响应: {}", response);

                        // 这里应该使用JSON解析库来解析响应
                        // 简化起见，返回预定义的模型列表
                        return Flux.fromIterable(getDefaultTogetherAIModels());
                    } catch (Exception e) {
                        log.error("解析TogetherAI模型列表时出错", e);
                        return Flux.fromIterable(getDefaultTogetherAIModels());
                    }
                })
                .onErrorResume(e -> {
                    log.error("获取TogetherAI模型列表时出错", e);
                    // 出错时返回预定义的模型列表
                    return Flux.fromIterable(getDefaultTogetherAIModels());
                });
    }

    /**
     * 获取默认的TogetherAI模型列表
     *
     * @return 模型信息列表
     */
    private List<ModelInfo> getDefaultTogetherAIModels() {
        List<ModelInfo> models = new ArrayList<>();

        models.add(ModelInfo.basic("mistralai/Mixtral-8x7B-Instruct-v0.1", "Mixtral 8x7B Instruct", "togetherai")
                .withDescription("Mixtral 8x7B是一个高性能的稀疏混合专家模型，在多种基准测试中表现优异")
                .withMaxTokens(32768)
                .withUnifiedPrice(0.0006));

        models.add(ModelInfo.basic("meta-llama/Llama-3-70b-chat", "Llama 3 70B Chat", "togetherai")
                .withDescription("Meta发布的Llama 3 70B模型，为对话进行了优化")
                .withMaxTokens(8192)
                .withUnifiedPrice(0.0009));

        models.add(ModelInfo.basic("meta-llama/Llama-3-8b-chat", "Llama 3 8B Chat", "togetherai")
                .withDescription("Meta发布的Llama 3 8B模型，体积小但保持了良好的性能")
                .withMaxTokens(8192)
                .withUnifiedPrice(0.0002));

        models.add(ModelInfo.basic("google/gemma-7b-it", "Gemma 7B IT", "togetherai")
                .withDescription("Google发布的轻量级开源模型，在效率和性能之间取得平衡")
                .withMaxTokens(8192)
                .withUnifiedPrice(0.0001));

        models.add(ModelInfo.basic("Qwen/Qwen2.5-7B-Instruct", "Qwen 2.5 7B Instruct", "togetherai")
                .withDescription("通义千问2.5 7B指令模型，阿里巴巴开发的高性能多语言模型")
                .withMaxTokens(32768)
                .withUnifiedPrice(0.0002));

        return models;
    }
} 