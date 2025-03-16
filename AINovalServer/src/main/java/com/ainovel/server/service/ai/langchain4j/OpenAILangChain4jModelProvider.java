package com.ainovel.server.service.ai.langchain4j;

import com.ainovel.server.domain.model.AIRequest;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.chat.StreamingChatLanguageModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

import java.net.InetSocketAddress;
import java.net.Proxy;
import java.time.Duration;
import java.util.Map;

/**
 * OpenAI的LangChain4j实现
 */
@Slf4j
public class OpenAILangChain4jModelProvider extends LangChain4jModelProvider {

    private static final String DEFAULT_API_ENDPOINT = "https://api.openai.com/v1";
    private static final Map<String, Double> TOKEN_PRICES = Map.of(
            "gpt-3.5-turbo", 0.0015,
            "gpt-3.5-turbo-16k", 0.003,
            "gpt-4", 0.03,
            "gpt-4-32k", 0.06,
            "gpt-4-turbo", 0.01,
            "gpt-4o", 0.01
    );

    /**
     * 构造函数
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     */
    public OpenAILangChain4jModelProvider(String modelName, String apiKey, String apiEndpoint) {
        super("openai", modelName, apiKey, apiEndpoint);
    }

    @Override
    protected void initModels() {
        try {
            // 获取API端点
            String baseUrl = getApiEndpoint(DEFAULT_API_ENDPOINT);
            
            // 配置系统代理
            configureSystemProxy();
            
            // 创建非流式模型
            this.chatModel = OpenAiChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .baseUrl(baseUrl)
                    .timeout(Duration.ofSeconds(60))
                    .build();
            
            // 创建流式模型
            this.streamingChatModel = OpenAiStreamingChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .baseUrl(baseUrl)
                    .timeout(Duration.ofSeconds(60))
                    .build();
            
            log.info("OpenAI模型初始化成功: {}", modelName);
        } catch (Exception e) {
            log.error("初始化OpenAI模型时出错", e);
            this.chatModel = null;
            this.streamingChatModel = null;
        }
    }
    
    @Override
    public Mono<Double> estimateCost(AIRequest request) {
        // 获取模型价格（每1000个令牌的美元价格）
        double pricePerThousandTokens = TOKEN_PRICES.getOrDefault(modelName, 0.01);
        
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