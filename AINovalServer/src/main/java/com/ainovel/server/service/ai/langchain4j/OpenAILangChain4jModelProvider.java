package com.ainovel.server.service.ai.langchain4j;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

import com.ainovel.server.domain.model.AIRequest;

import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

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
     *
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
                    .baseUrl(this.apiEndpoint != null ? this.apiEndpoint : baseUrl)
                    .timeout(Duration.ofSeconds(300))
                    .logRequests(true)
                    .logResponses(true)
                    .build();

            // 创建流式模型
            this.streamingChatModel = OpenAiStreamingChatModel.builder()
                    .apiKey(apiKey)
                    .modelName(modelName)
                    .baseUrl(this.apiEndpoint != null ? this.apiEndpoint : baseUrl)
                    .timeout(Duration.ofSeconds(300))
                    .logRequests(true)
                    .logResponses(true)
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

    @Override
    public Flux<String> generateContentStream(AIRequest request) {
        log.info("开始OpenAI流式生成，模型: {}", modelName);

        // 记录连接开始时间
        final long connectionStartTime = System.currentTimeMillis();
        final AtomicLong firstResponseTime = new AtomicLong(0);

        return super.generateContentStream(request)
                .doOnSubscribe(sub -> {
                    log.info("OpenAI流式生成已订阅，等待首次响应...");
                })
                .doOnNext(content -> {
                    // 记录首次响应时间
                    if (firstResponseTime.get() == 0 && !"heartbeat".equals(content) && !content.startsWith("错误：")) {
                        firstResponseTime.set(System.currentTimeMillis());
                        log.info("OpenAI首次响应耗时: {}ms, 模型: {}",
                                (firstResponseTime.get() - connectionStartTime), modelName);
                    }

                    if (!"heartbeat".equals(content) && !content.startsWith("错误：")) {
                        log.debug("OpenAI生成内容: {}", content);
                    }
                })
                .doOnComplete(() -> {
                    if (firstResponseTime.get() > 0) {
                        log.info("OpenAI流式生成完成，总耗时: {}ms, 模型: {}",
                                (System.currentTimeMillis() - connectionStartTime), modelName);
                    } else {
                        log.warn("OpenAI流式生成完成，但未收到任何内容，可能是连接问题，总耗时: {}ms, 模型: {}",
                                (System.currentTimeMillis() - connectionStartTime), modelName);
                    }
                })
                .doOnError(e -> log.error("OpenAI流式生成出错: {}", e.getMessage(), e))
                .doOnCancel(() -> {
                    if (firstResponseTime.get() > 0) {
                        log.info("OpenAI流式生成被取消，已生成内容 {}ms，总耗时: {}ms, 模型: {}",
                                (firstResponseTime.get() - connectionStartTime),
                                (System.currentTimeMillis() - connectionStartTime),
                                modelName);
                    } else {
                        log.warn("OpenAI流式生成被取消，未收到任何内容，可能是连接超时，总耗时: {}ms, 模型: {}",
                                (System.currentTimeMillis() - connectionStartTime), modelName);
                    }
                });
    }
}
