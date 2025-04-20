package com.ainovel.server.service.ai.langchain4j;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.WebClient;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.ModelInfo;

import dev.langchain4j.model.anthropic.AnthropicChatModel;
import dev.langchain4j.model.anthropic.AnthropicStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * Anthropic的LangChain4j实现
 */
@Slf4j
public class AnthropicLangChain4jModelProvider extends LangChain4jModelProvider {

    private static final String DEFAULT_API_ENDPOINT = "https://api.anthropic.com";
    private static final Map<String, Double> TOKEN_PRICES;

    static {
        Map<String, Double> prices = new HashMap<>();
        prices.put("claude-3-opus-20240229", 0.015);
        prices.put("claude-3-sonnet-20240229", 0.003);
        prices.put("claude-3-haiku-20240307", 0.00025);
        prices.put("claude-2.1", 0.008);
        prices.put("claude-2.0", 0.008);
        prices.put("claude-instant-1.2", 0.0008);
        TOKEN_PRICES = Collections.unmodifiableMap(prices);
    }

    /**
     * 构造函数
     *
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     */
    public AnthropicLangChain4jModelProvider(String modelName, String apiKey, String apiEndpoint) {
        super("anthropic", modelName, apiKey, apiEndpoint);
    }

    @Override
    protected void initModels() {
        try {
            // 获取API端点
            String baseUrl = getApiEndpoint(DEFAULT_API_ENDPOINT);

            // 配置系统代理
            configureSystemProxy();

            // 创建非流式模型
            this.chatModel = AnthropicChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .baseUrl(baseUrl)
                    .timeout(Duration.ofSeconds(300))
                    .build();

            // 创建流式模型
            this.streamingChatModel = AnthropicStreamingChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .baseUrl(baseUrl)
                    .timeout(Duration.ofSeconds(300))
                    .build();

            log.info("Anthropic模型初始化成功: {}", modelName);
        } catch (Exception e) {
            log.error("初始化Anthropic模型时出错", e);
            this.chatModel = null;
            this.streamingChatModel = null;
        }
    }

    @Override
    public Mono<Double> estimateCost(AIRequest request) {
        // 获取模型价格（每1000个令牌的美元价格）
        double pricePerThousandTokens = TOKEN_PRICES.getOrDefault(modelName, 0.003);

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

    /**
     * Anthropic需要API密钥才能获取模型列表
     * 覆盖基类的listModelsWithApiKey方法
     *
     * @param apiKey API密钥
     * @param apiEndpoint 可选的API端点
     * @return 模型信息列表
     */
    @Override
    public Flux<ModelInfo> listModelsWithApiKey(String apiKey, String apiEndpoint) {
        if (isApiKeyEmpty(apiKey)) {
            return Flux.error(new RuntimeException("API密钥不能为空"));
        }

        log.info("获取Anthropic模型列表");

        // 获取API端点
        String baseUrl = apiEndpoint != null && !apiEndpoint.trim().isEmpty() ?
                apiEndpoint : DEFAULT_API_ENDPOINT;

        // 创建WebClient
        WebClient webClient = WebClient.builder()
                .baseUrl(baseUrl)
                .build();

        // 调用Anthropic API获取模型列表
        return webClient.get()
                .uri("/v1/models")
                .header("x-api-key", apiKey)
                .header("anthropic-version", "2023-06-01")
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .bodyToMono(String.class)
                .flatMapMany(response -> {
                    try {
                        // 解析响应
                        log.debug("Anthropic模型列表响应: {}", response);

                        // 这里应该使用JSON解析库来解析响应
                        // 简化起见，返回预定义的模型列表
                        return Flux.fromIterable(getDefaultAnthropicModels());
                    } catch (Exception e) {
                        log.error("解析Anthropic模型列表时出错", e);
                        return Flux.fromIterable(getDefaultAnthropicModels());
                    }
                })
                .onErrorResume(e -> {
                    log.error("获取Anthropic模型列表时出错", e);
                    // 出错时返回预定义的模型列表
                    return Flux.fromIterable(getDefaultAnthropicModels());
                });
    }

    /**
     * 获取默认的Anthropic模型列表
     *
     * @return 模型信息列表
     */
    private List<ModelInfo> getDefaultAnthropicModels() {
        List<ModelInfo> models = new ArrayList<>();

        models.add(ModelInfo.basic("claude-3-opus-20240229", "Claude 3 Opus", "anthropic")
                .withDescription("Anthropic的Claude 3 Opus模型 - 最强大的Claude模型")
                .withMaxTokens(200000)
                .withInputPrice(0.015)
                .withOutputPrice(0.075));

        models.add(ModelInfo.basic("claude-3-sonnet-20240229", "Claude 3 Sonnet", "anthropic")
                .withDescription("Anthropic的Claude 3 Sonnet模型 - 平衡能力和速度")
                .withMaxTokens(200000)
                .withInputPrice(0.003)
                .withOutputPrice(0.015));

        models.add(ModelInfo.basic("claude-3-haiku-20240307", "Claude 3 Haiku", "anthropic")
                .withDescription("Anthropic的Claude 3 Haiku模型 - 最快速的Claude模型")
                .withMaxTokens(200000)
                .withInputPrice(0.00025)
                .withOutputPrice(0.00125));

        models.add(ModelInfo.basic("claude-2.1", "Claude 2.1", "anthropic")
                .withDescription("Anthropic的Claude 2.1模型")
                .withMaxTokens(100000)
                .withUnifiedPrice(0.008));

        models.add(ModelInfo.basic("claude-2.0", "Claude 2.0", "anthropic")
                .withDescription("Anthropic的Claude 2.0模型")
                .withMaxTokens(100000)
                .withUnifiedPrice(0.008));

        models.add(ModelInfo.basic("claude-instant-1.2", "Claude Instant 1.2", "anthropic")
                .withDescription("Anthropic的Claude Instant 1.2模型 - 更快速的版本")
                .withMaxTokens(100000)
                .withUnifiedPrice(0.0008));

        return models;
    }
}
