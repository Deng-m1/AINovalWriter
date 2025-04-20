package com.ainovel.server.service.ai.langchain4j;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.WebClient;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.ModelInfo;

import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * SiliconFlow的LangChain4j实现 使用OpenAI兼容模式
 */
@Slf4j
public class SiliconFlowLangChain4jModelProvider extends LangChain4jModelProvider {

    private static final String DEFAULT_API_ENDPOINT = "https://api.siliconflow.cn/v1";
    private static final Map<String, Double> TOKEN_PRICES;

    static {
        Map<String, Double> prices = new HashMap<>();
        prices.put("moonshot-v1-8k", 0.0015);
        prices.put("moonshot-v1-32k", 0.003);
        prices.put("moonshot-v1-128k", 0.006);
        prices.put("deepseek-ai/DeepSeek-V3", 0.0015);
        prices.put("Qwen/Qwen2.5-32B-Instruct", 0.0015);
        prices.put("Qwen/Qwen1.5-110B-Chat", 0.003);
        prices.put("google/gemma-2-9b-it", 0.0001);
        prices.put("meta-llama/Meta-Llama-3.1-70B-Instruct", 0.0009);
        TOKEN_PRICES = Collections.unmodifiableMap(prices);
    }

    /**
     * 构造函数
     *
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

            log.info("SiliconFlow模型初始化成功: {}", modelName);
        } catch (Exception e) {
            log.error("初始化SiliconFlow模型时出错", e);
            this.chatModel = null;
            this.streamingChatModel = null;
        }
    }

    /**
     * 测试SiliconFlow API
     *
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

    @Override
    public Flux<String> generateContentStream(AIRequest request) {
        log.info("开始SiliconFlow流式生成，模型: {}", modelName);

        // 标记是否已经收到了任何内容
        final AtomicBoolean hasReceivedContent = new AtomicBoolean(false);

        return super.generateContentStream(request)
                .doOnSubscribe(__ -> log.info("SiliconFlow流式生成已订阅"))
                .doOnNext(content -> {
                    if (!"heartbeat".equals(content) && !content.startsWith("错误：")) {
                        // 标记已收到有效内容
                        hasReceivedContent.set(true);
                        log.debug("SiliconFlow生成内容: {}", content);
                    }
                })
                .doOnComplete(() -> log.info("SiliconFlow流式生成完成"))
                .doOnError(e -> log.error("SiliconFlow流式生成出错", e))
                .doOnCancel(() -> {
                    if (hasReceivedContent.get()) {
                        // 如果已收到内容但客户端取消了，记录不同的日志但允许模型继续生成
                        log.info("SiliconFlow流式生成客户端取消了连接，但已收到内容，保持模型连接以完成生成");
                    } else {
                        // 如果没有收到任何内容且客户端取消了，记录取消日志
                        log.info("SiliconFlow流式生成被取消，未收到任何内容");
                    }
                });
    }

    /**
     * SiliconFlow需要API密钥才能获取模型列表
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

        log.info("获取SiliconFlow模型列表");

        // 获取API端点
        String baseUrl = apiEndpoint != null && !apiEndpoint.trim().isEmpty() ?
                apiEndpoint : DEFAULT_API_ENDPOINT;

        // 创建WebClient
        WebClient webClient = WebClient.builder()
                .baseUrl(baseUrl)
                .build();

        // 调用SiliconFlow API获取模型列表
        return webClient.get()
                .uri("/models")
                .header("Authorization", "Bearer " + apiKey)
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .bodyToMono(String.class)
                .flatMapMany(response -> {
                    try {
                        // 解析响应
                        log.debug("SiliconFlow模型列表响应: {}", response);

                        // 这里应该使用JSON解析库来解析响应
                        // 简化起见，返回预定义的模型列表
                        return Flux.fromIterable(getDefaultSiliconFlowModels());
                    } catch (Exception e) {
                        log.error("解析SiliconFlow模型列表时出错", e);
                        return Flux.fromIterable(getDefaultSiliconFlowModels());
                    }
                })
                .onErrorResume(e -> {
                    log.error("获取SiliconFlow模型列表时出错", e);
                    // 出错时返回预定义的模型列表
                    return Flux.fromIterable(getDefaultSiliconFlowModels());
                });
    }

    /**
     * 获取默认的SiliconFlow模型列表
     *
     * @return 模型信息列表
     */
    private List<ModelInfo> getDefaultSiliconFlowModels() {
        List<ModelInfo> models = new ArrayList<>();

        models.add(ModelInfo.basic("moonshot-v1-8k", "Moonshot V1 8K", "siliconflow")
                .withDescription("硬流的Moonshot V1 8K模型 - 上下文窗口8K")
                .withMaxTokens(8192)
                .withUnifiedPrice(0.0015));

        models.add(ModelInfo.basic("moonshot-v1-32k", "Moonshot V1 32K", "siliconflow")
                .withDescription("硬流的Moonshot V1 32K模型 - 上下文窗口32K")
                .withMaxTokens(32768)
                .withUnifiedPrice(0.003));

        models.add(ModelInfo.basic("moonshot-v1-128k", "Moonshot V1 128K", "siliconflow")
                .withDescription("硬流的Moonshot V1 128K模型 - 上下文窗口128K")
                .withMaxTokens(131072)
                .withUnifiedPrice(0.006));

        models.add(ModelInfo.basic("deepseek-ai/DeepSeek-V3", "DeepSeek V3", "siliconflow")
                .withDescription("DeepSeek的V3模型")
                .withMaxTokens(32768)
                .withUnifiedPrice(0.0015));

        models.add(ModelInfo.basic("Qwen/Qwen2.5-32B-Instruct", "Qwen 2.5 32B", "siliconflow")
                .withDescription("通义千问2.5 32B模型")
                .withMaxTokens(32768)
                .withUnifiedPrice(0.0015));

        models.add(ModelInfo.basic("Qwen/Qwen1.5-110B-Chat", "Qwen 1.5 110B", "siliconflow")
                .withDescription("通义千问1.5 110B模型")
                .withMaxTokens(32768)
                .withUnifiedPrice(0.003));

        models.add(ModelInfo.basic("google/gemma-2-9b-it", "Gemma 2 9B", "siliconflow")
                .withDescription("Google的Gemma 2 9B模型")
                .withMaxTokens(8192)
                .withUnifiedPrice(0.0001));

        models.add(ModelInfo.basic("meta-llama/Meta-Llama-3.1-70B-Instruct", "Llama 3.1 70B", "siliconflow")
                .withDescription("Meta的Llama 3.1 70B模型")
                .withMaxTokens(8192)
                .withUnifiedPrice(0.0009));

        return models;
    }
}
