package com.ainovel.server.service.ai.langchain4j;

import java.time.Duration;
import java.util.Map;

import com.ainovel.server.domain.model.AIRequest;

import dev.langchain4j.model.anthropic.AnthropicChatModel;
import dev.langchain4j.model.anthropic.AnthropicStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * Anthropic的LangChain4j实现
 */
@Slf4j
public class AnthropicLangChain4jModelProvider extends LangChain4jModelProvider {

    private static final String DEFAULT_API_ENDPOINT = "https://api.anthropic.com";
    private static final Map<String, Double> TOKEN_PRICES = Map.of(
            "claude-3-opus-20240229", 0.015,
            "claude-3-sonnet-20240229", 0.003,
            "claude-3-haiku-20240307", 0.00025,
            "claude-2.1", 0.008,
            "claude-2.0", 0.008,
            "claude-instant-1.2", 0.0008
    );

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
}
