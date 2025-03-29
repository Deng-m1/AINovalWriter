package com.ainovel.server.service.ai.langchain4j;

import java.util.Map;

import com.ainovel.server.config.ProxyConfig;
import com.ainovel.server.domain.model.AIRequest;

import dev.langchain4j.model.googleai.GoogleAiGeminiChatModel;
import dev.langchain4j.model.googleai.GoogleAiGeminiStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * Gemini的LangChain4j实现
 *
 * 注意：Gemini模型与其他模型有不同的配置参数 1. 不支持baseUrl和timeout方法 2.
 * 支持temperature、maxOutputTokens、topK和topP等特有参数 3.
 * 详细文档请参考：https://docs.langchain4j.dev/integrations/language-models/google-ai-gemini/
 */
@Slf4j
public class GeminiLangChain4jModelProvider extends LangChain4jModelProvider {

    private static final String DEFAULT_API_ENDPOINT = "https://generativelanguage.googleapis.com/";
    private static final Map<String, Double> TOKEN_PRICES = Map.of(
            "gemini-pro", 0.0001,
            "gemini-pro-vision", 0.0001,
            "gemini-1.5-pro", 0.0007,
            "gemini-1.5-flash", 0.0001
    );

    /**
     * 构造函数
     *
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     * @param proxyConfig 代理配置 (由 Spring 注入)
     */
    public GeminiLangChain4jModelProvider(
            String modelName,
            String apiKey,
            String apiEndpoint,
            ProxyConfig proxyConfig
    ) {
        super("gemini", modelName, apiKey, apiEndpoint, proxyConfig);
    }

    @Override
    protected void initModels() {
        try {
            log.info("Gemini Provider (模型: {}): 调用 initModels，将配置系统代理...", modelName);
            // 配置系统代理 (现在会调用上面重写的 configureSystemProxy 方法)
            configureSystemProxy();

            log.info("尝试为Gemini模型 {} 初始化 LangChain4j 客户端...", modelName);
            // 创建非流式模型
            // 注意：Gemini模型不支持baseUrl和timeout方法，但支持其他特有参数
            this.chatModel = GoogleAiGeminiChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .temperature(0.7)
                    .maxOutputTokens(2048)
                    .topK(40)
                    .topP(0.95)
                    .logRequestsAndResponses(true)
                    .build();

            // 创建流式模型
            this.streamingChatModel = GoogleAiGeminiStreamingChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .temperature(0.7)
                    .maxOutputTokens(2048)
                    .topK(40)
                    .topP(0.95)
                    .build();

            log.info("Gemini模型 {} 的 LangChain4j 客户端初始化成功。", modelName);
        } catch (Exception e) {
            log.error("初始化Gemini模型 {} 时出错: {}", modelName, e.getMessage(), e);
            this.chatModel = null;
            this.streamingChatModel = null;
        }
    }

    @Override
    public Mono<Double> estimateCost(AIRequest request) {
        // 获取模型价格（每1000个令牌的美元价格）
        double pricePerThousandTokens = TOKEN_PRICES.getOrDefault(modelName, 0.0001);

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
