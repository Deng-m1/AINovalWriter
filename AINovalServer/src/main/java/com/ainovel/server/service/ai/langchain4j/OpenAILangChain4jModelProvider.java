package com.ainovel.server.service.ai.langchain4j;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

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
 * OpenAI的LangChain4j实现
 */
@Slf4j
public class OpenAILangChain4jModelProvider extends LangChain4jModelProvider {

    private static final String DEFAULT_API_ENDPOINT = "https://api.openai.com/v1";
    private static final Map<String, Double> TOKEN_PRICES;

    static {
        Map<String, Double> prices = new HashMap<>();
        prices.put("gpt-3.5-turbo", 0.0015);
        prices.put("gpt-3.5-turbo-16k", 0.003);
        prices.put("gpt-4", 0.03);
        prices.put("gpt-4-32k", 0.06);
        prices.put("gpt-4-turbo", 0.01);
        prices.put("gpt-4o", 0.01);
        TOKEN_PRICES = Collections.unmodifiableMap(prices);
    }

    /**
     * 构造函数
     *
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     */
    public OpenAILangChain4jModelProvider(String modelName, String apiKey, String apiEndpoint,
                                          ProxyConfig proxyConfig) {
        super("openai", modelName, apiKey, apiEndpoint,proxyConfig);
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
                .doOnSubscribe(__ -> {
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
                .doOnError(e -> {
                    log.error("OpenAI流式生成出错: {}, 模型: {}", e.getMessage(), modelName, e);
                })
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

    /**
     * OpenAI需要API密钥才能获取模型列表
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

        log.info("获取OpenAI模型列表");

        // 获取API端点
        String baseUrl = apiEndpoint != null && !apiEndpoint.trim().isEmpty() ?
                apiEndpoint : DEFAULT_API_ENDPOINT;

        // 创建WebClient
        WebClient webClient = WebClient.builder()
                .baseUrl(baseUrl)
                .build();

        // 调用OpenAI API获取模型列表
        return webClient.get()
                .uri("/models")
                .header("Authorization", "Bearer " + apiKey)
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .bodyToMono(String.class)
                .flatMapMany(response -> {
                    try {
                        // 解析响应
                        log.debug("OpenAI模型列表响应: {}", response);

                        // 这里应该使用JSON解析库来解析响应
                        // 简化起见，返回预定义的模型列表
                        return Flux.fromIterable(getDefaultOpenAIModels());
                    } catch (Exception e) {
                        log.error("解析OpenAI模型列表时出错", e);
                        return Flux.fromIterable(getDefaultOpenAIModels());
                    }
                })
                .onErrorResume(e -> {
                    log.error("获取OpenAI模型列表时出错", e);
                    // 出错时返回预定义的模型列表
                    return Flux.fromIterable(getDefaultOpenAIModels());
                });
    }

    /**
     * 获取默认的OpenAI模型列表
     *
     * @return 模型信息列表
     */
    private List<ModelInfo> getDefaultOpenAIModels() {
        List<ModelInfo> models = new ArrayList<>();

        models.add(ModelInfo.basic("gpt-3.5-turbo", "GPT-3.5 Turbo", "openai")
                .withDescription("OpenAI的GPT-3.5 Turbo模型")
                .withMaxTokens(16385)
                .withInputPrice(0.0015)
                .withOutputPrice(0.002));

        models.add(ModelInfo.basic("gpt-3.5-turbo-16k", "GPT-3.5 Turbo 16K", "openai")
                .withDescription("OpenAI的GPT-3.5 Turbo 16K模型")
                .withMaxTokens(16385)
                .withInputPrice(0.003)
                .withOutputPrice(0.004));

        models.add(ModelInfo.basic("gpt-4", "GPT-4", "openai")
                .withDescription("OpenAI的GPT-4模型")
                .withMaxTokens(8192)
                .withInputPrice(0.03)
                .withOutputPrice(0.06));

        models.add(ModelInfo.basic("gpt-4-32k", "GPT-4 32K", "openai")
                .withDescription("OpenAI的GPT-4 32K模型")
                .withMaxTokens(32768)
                .withInputPrice(0.06)
                .withOutputPrice(0.12));

        models.add(ModelInfo.basic("gpt-4-turbo", "GPT-4 Turbo", "openai")
                .withDescription("OpenAI的GPT-4 Turbo模型")
                .withMaxTokens(128000)
                .withInputPrice(0.01)
                .withOutputPrice(0.03));

        models.add(ModelInfo.basic("gpt-4o", "GPT-4o", "openai")
                .withDescription("OpenAI的GPT-4o模型")
                .withMaxTokens(128000)
                .withInputPrice(0.01)
                .withOutputPrice(0.03));

        return models;
    }
}
