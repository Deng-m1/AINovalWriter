package com.ainovel.server.service.ai.langchain4j;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.WebClient;

import com.ainovel.server.config.ProxyConfig;
import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.ModelInfo;

import dev.langchain4j.model.googleai.GoogleAiGeminiChatModel;
import dev.langchain4j.model.googleai.GoogleAiGeminiStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
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
    private static final Map<String, Double> TOKEN_PRICES;

    static {
        Map<String, Double> prices = new HashMap<>();
        prices.put("gemini-pro", 0.0001);
        prices.put("gemini-pro-vision", 0.0001);
        prices.put("gemini-1.5-pro", 0.0007);
        prices.put("gemini-1.5-flash", 0.0001);
        prices.put("gemini-2.0-flash", 0.0001);
        TOKEN_PRICES = Collections.unmodifiableMap(prices);
    }

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

    @Override
    public Flux<String> generateContentStream(AIRequest request) {
        log.info("开始Gemini流式生成，模型: {}", modelName);

        // 标记是否已经收到了任何内容
        final AtomicBoolean hasReceivedContent = new AtomicBoolean(false);

        return super.generateContentStream(request)
                .doOnSubscribe(__ -> log.info("Gemini流式生成已订阅"))
                .doOnNext(content -> {
                    if (!"heartbeat".equals(content) && !content.startsWith("错误：")) {
                        // 标记已收到有效内容
                        hasReceivedContent.set(true);
                        log.debug("Gemini生成内容: {}", content);
                    }
                })
                .doOnComplete(() -> log.info("Gemini流式生成完成"))
                .doOnError(e -> log.error("Gemini流式生成出错", e))
                .doOnCancel(() -> {
                    if (hasReceivedContent.get()) {
                        // 如果已收到内容但客户端取消了，记录不同的日志但允许模型继续生成
                        log.info("Gemini流式生成客户端取消了连接，但已收到内容，保持模型连接以完成生成");
                    } else {
                        // 如果没有收到任何内容且客户端取消了，记录取消日志
                        log.info("Gemini流式生成被取消，未收到任何内容");
                    }
                });
    }

    /**
     * Gemini需要API密钥才能获取模型列表
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

        log.info("获取Gemini模型列表");

        // 获取API端点
        String baseUrl = apiEndpoint != null && !apiEndpoint.trim().isEmpty() ?
                apiEndpoint : DEFAULT_API_ENDPOINT;

        // 创建WebClient
        WebClient webClient = WebClient.builder()
                .baseUrl(baseUrl)
                .build();

        // 调用Gemini API获取模型列表
        // Gemini API的路径可能不同，需要根据实际情况调整
        return webClient.get()
                .uri("/v1/models?key=" + apiKey)
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .bodyToMono(String.class)
                .flatMapMany(response -> {
                    try {
                        // 解析响应
                        log.debug("Gemini模型列表响应: {}", response);

                        // 这里应该使用JSON解析库来解析响应
                        // 简化起见，返回预定义的模型列表
                        return Flux.fromIterable(getDefaultGeminiModels());
                    } catch (Exception e) {
                        log.error("解析Gemini模型列表时出错", e);
                        return Flux.fromIterable(getDefaultGeminiModels());
                    }
                })
                .onErrorResume(e -> {
                    log.error("获取Gemini模型列表时出错", e);
                    // 出错时返回预定义的模型列表
                    return Flux.fromIterable(getDefaultGeminiModels());
                });
    }

    /**
     * 获取默认的Gemini模型列表
     *
     * @return 模型信息列表
     */
    private List<ModelInfo> getDefaultGeminiModels() {
        List<ModelInfo> models = new ArrayList<>();

        models.add(ModelInfo.basic("gemini-pro", "Gemini Pro", "gemini")
                .withDescription("Google的Gemini Pro模型 - 强大的文本生成和推理能力")
                .withMaxTokens(32768)
                .withUnifiedPrice(0.0001));

        models.add(ModelInfo.basic("gemini-pro-vision", "Gemini Pro Vision", "gemini")
                .withDescription("Google的Gemini Pro Vision模型 - 支持图像输入")
                .withMaxTokens(32768)
                .withUnifiedPrice(0.0001));

        models.add(ModelInfo.basic("gemini-1.5-pro", "Gemini 1.5 Pro", "gemini")
                .withDescription("Google的Gemini 1.5 Pro模型 - 新一代多模态模型")
                .withMaxTokens(1000000)
                .withUnifiedPrice(0.0007));

        models.add(ModelInfo.basic("gemini-1.5-flash", "Gemini 1.5 Flash", "gemini")
                .withDescription("Google的Gemini 1.5 Flash模型 - 更快速的版本")
                .withMaxTokens(1000000)
                .withUnifiedPrice(0.0001));

        models.add(ModelInfo.basic("gemini-2.0-flash", "Gemini 2.0 Flash", "gemini")
                .withDescription("Google的Gemini 2.0 Flash模型 - 最新版本")
                .withMaxTokens(1000000)
                .withUnifiedPrice(0.0001));

        return models;
    }
}
