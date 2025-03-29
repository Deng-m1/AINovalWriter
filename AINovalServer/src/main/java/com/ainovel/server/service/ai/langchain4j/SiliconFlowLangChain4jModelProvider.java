package com.ainovel.server.service.ai.langchain4j;

import com.ainovel.server.domain.model.AIRequest;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

import java.net.InetSocketAddress;
import java.net.Proxy;
import java.time.Duration;
import java.util.Map;

/**
 * SiliconFlow的LangChain4j实现
 * 使用OpenAI兼容模式
 */
@Slf4j
public class SiliconFlowLangChain4jModelProvider extends LangChain4jModelProvider {

    private static final String DEFAULT_API_ENDPOINT = "https://api.siliconflow.cn/v1";
    private static final Map<String, Double> TOKEN_PRICES = Map.of(
            "moonshot-v1-8k", 0.0015,
            "moonshot-v1-32k", 0.003,
            "moonshot-v1-128k", 0.006
    );

    /**
     * 构造函数
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     */
    public SiliconFlowLangChain4jModelProvider(String modelName, String apiKey, String apiEndpoint) {
        super("siliconflow", modelName, apiKey, apiEndpoint);
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
                    .logRequests(true)
                    .logResponses(true)
                    .timeout(Duration.ofSeconds(60))
                    .build();
            
            // 创建流式模型
            this.streamingChatModel = OpenAiStreamingChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .baseUrl(baseUrl)
                    .logRequests(true)
                    .logResponses(true)
                    .timeout(Duration.ofSeconds(60))
                    .build();
            
            log.info("SiliconFlow模型初始化成功: {}", modelName);
        } catch (Exception e) {
            log.error("初始化SiliconFlow模型时出错", e);
            this.chatModel = null;
            this.streamingChatModel = null;
        }
    }
    
    /**
     * 测试SiliconFlow API
     * @return 测试结果
     */
    public String testSiliconFlowApi() {
        if (chatModel == null) {
            return "模型未初始化";
        }
        
        // 注意：由于LangChain4j API的变化，此测试方法需要更新
        // 暂时返回一个提示信息
        return "API测试功能暂未实现，请使用generateContent方法进行测试";
    }
    
    @Override
    public Mono<Double> estimateCost(AIRequest request) {
        // 获取模型价格（每1000个令牌的美元价格）
        double pricePerThousandTokens = TOKEN_PRICES.getOrDefault(modelName, 0.0015);
        
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