package com.ainovel.server.service.ai.langchain4j;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.ExchangeStrategies;
import org.springframework.web.reactive.function.client.WebClient;

import com.ainovel.server.config.ProxyConfig;
import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.ModelInfo;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * OpenRouter的LangChain4j实现
 * 使用OpenAI兼容模式，因为OpenRouter API与OpenAI兼容
 */
@Slf4j
public class OpenRouterLangChain4jModelProvider extends LangChain4jModelProvider {

    private static final String DEFAULT_API_ENDPOINT = "https://openrouter.ai/api/v1";
    
    // 模型列表缓存 - 静态缓存，所有实例共享
    private static final Map<String, List<ModelInfo>> MODEL_CACHE = new ConcurrentHashMap<>();
    
    // 缓存过期时间 - 1小时
    private static final long CACHE_EXPIRY_MS = 3600 * 1000;
    
    // 最后一次缓存更新时间
    private static final AtomicLong lastCacheUpdateTime = new AtomicLong(0);
    
    // 最大返回的模型数量
    private static final int MAX_MODELS_TO_RETURN = 20;

    // OpenRouter模型价格配置
    // 注意：这些价格需要根据OpenRouter的实际价格进行调整
    private static final Map<String, Double> TOKEN_PRICES;

    static {
        Map<String, Double> prices = new HashMap<>();
        prices.put("openai/gpt-3.5-turbo", 0.0015);
        prices.put("openai/gpt-4", 0.03);
        prices.put("openai/gpt-4-turbo", 0.01);
        prices.put("openai/gpt-4o", 0.01);
        prices.put("anthropic/claude-3-opus", 0.015);
        prices.put("anthropic/claude-3-sonnet", 0.003);
        prices.put("anthropic/claude-3-haiku", 0.00025);
        prices.put("google/gemini-pro", 0.0001);
        prices.put("google/gemini-1.5-pro", 0.0007);
        prices.put("meta-llama/llama-3-70b-instruct", 0.0009);
        prices.put("meta-llama/llama-3-8b-instruct", 0.0002);
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
    public OpenRouterLangChain4jModelProvider(String modelName, String apiKey, String apiEndpoint,
                                          ProxyConfig proxyConfig) {
        super("openrouter", modelName, apiKey, apiEndpoint, proxyConfig);
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

            log.info("OpenRouter模型初始化成功: {}", modelName);
        } catch (Exception e) {
            log.error("初始化OpenRouter模型时出错", e);
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
        log.info("开始OpenRouter流式生成，模型: {}", modelName);

        // 记录连接开始时间
        final long connectionStartTime = System.currentTimeMillis();
        final AtomicLong firstResponseTime = new AtomicLong(0);

        return super.generateContentStream(request)
                .doOnSubscribe(__ -> {
                    log.info("OpenRouter流式生成已订阅，等待首次响应...");
                })
                .doOnNext(content -> {
                    // 记录首次响应时间
                    if (firstResponseTime.get() == 0 && !"heartbeat".equals(content) && !content.startsWith("错误：")) {
                        firstResponseTime.set(System.currentTimeMillis());
                        log.info("OpenRouter首次响应耗时: {}ms, 模型: {}",
                                (firstResponseTime.get() - connectionStartTime), modelName);
                    }

                    if (!"heartbeat".equals(content) && !content.startsWith("错误：")) {
                        log.debug("OpenRouter生成内容: {}", content);
                    }
                })
                .doOnComplete(() -> {
                    if (firstResponseTime.get() > 0) {
                        log.info("OpenRouter流式生成完成，总耗时: {}ms, 模型: {}",
                                (System.currentTimeMillis() - connectionStartTime), modelName);
                    } else {
                        log.warn("OpenRouter流式生成完成，但未收到有效响应，总耗时: {}ms, 模型: {}",
                                (System.currentTimeMillis() - connectionStartTime), modelName);
                    }
                })
                .doOnError(e -> {
                    log.error("OpenRouter流式生成出错: {}, 模型: {}", e.getMessage(), modelName, e);
                });
    }

    /**
     * OpenRouter不需要API密钥就能获取模型列表
     * 覆盖基类的listModels方法
     *
     * @return 模型信息列表
     */
    @Override
    public Flux<ModelInfo> listModels() {
        log.info("获取OpenRouter模型列表");
        
        // 检查缓存是否有效
        if (!isCacheExpired() && !MODEL_CACHE.isEmpty()) {
            log.info("从缓存返回OpenRouter模型列表，共{}个模型", MODEL_CACHE.size());
            return Flux.fromIterable(MODEL_CACHE.getOrDefault("models", getDefaultOpenRouterModels()));
        }

        // 创建WebClient，增加缓冲区大小
        ExchangeStrategies strategies = ExchangeStrategies.builder()
                .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(5 * 1024 * 1024)) // 5MB
                .build();
        
        WebClient webClient = WebClient.builder()
                .baseUrl("https://openrouter.ai/api")
                .exchangeStrategies(strategies)
                .build();

        // 调用OpenRouter API获取模型列表
        return webClient.get()
                .uri("/v1/models")
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .bodyToMono(String.class)
                .flatMapMany(response -> {
                    try {
                        // 解析响应
                        log.debug("OpenRouter模型列表响应: {}", response);
                        ObjectMapper mapper = new ObjectMapper();
                        JsonNode root = mapper.readTree(response);
                        JsonNode data = root.path("data");
                        
                        List<ModelInfo> models = new ArrayList<>();
                        
                        if (data.isArray()) {
                            for (JsonNode modelNode : data) {
                                String id = modelNode.path("id").asText();
                                String context = modelNode.path("context_length").asText("0");
                                int contextLength = Integer.parseInt(context.replaceAll("[^0-9]", ""));
                                
                                double inputPrice = 0.0;
                                double outputPrice = 0.0;
                                
                                if (modelNode.has("pricing")) {
                                    JsonNode pricing = modelNode.path("pricing");
                                    inputPrice = pricing.path("prompt").asDouble(0.0);
                                    outputPrice = pricing.path("completion").asDouble(0.0);
                                }
                                
                                // 使用平均价格作为统一价格
                                double unifiedPrice = (inputPrice + outputPrice) / 2;
                                
                                if (unifiedPrice <= 0) {
                                    // 使用预定义价格，如果有的话
                                    unifiedPrice = TOKEN_PRICES.getOrDefault(id, 0.001);
                                }
                                
                                ModelInfo modelInfo = ModelInfo.basic(id, id, "openrouter")
                                        .withDescription("OpenRouter提供的" + id + "模型")
                                        .withMaxTokens(contextLength > 0 ? contextLength : 8192)
                                        .withUnifiedPrice(unifiedPrice);
                                        
                                models.add(modelInfo);
                            }
                        }
                        
                        // 按价格排序并限制数量
                        models.sort(Comparator.<ModelInfo, Double>comparing(model -> 
                            model.getPricing().getOrDefault("unified", 0.0)).reversed());
                        
                        List<ModelInfo> finalModels = models.size() > MAX_MODELS_TO_RETURN ? 
                                models.subList(0, MAX_MODELS_TO_RETURN) : models;
                        
                        // 更新缓存
                        updateCache(finalModels);
                        
                        return Flux.fromIterable(finalModels);
                    } catch (Exception e) {
                        log.error("解析OpenRouter模型列表时出错", e);
                        List<ModelInfo> defaultModels = getDefaultOpenRouterModels();
                        updateCache(defaultModels);
                        return Flux.fromIterable(defaultModels);
                    }
                })
                .onErrorResume(e -> {
                    log.error("获取OpenRouter模型列表时出错", e);
                    // 出错时返回预定义的模型列表
                    List<ModelInfo> defaultModels = getDefaultOpenRouterModels();
                    updateCache(defaultModels);
                    return Flux.fromIterable(defaultModels);
                });
    }
    
    /**
     * 检查缓存是否过期
     * @return 是否过期
     */
    private boolean isCacheExpired() {
        long now = System.currentTimeMillis();
        long lastUpdate = lastCacheUpdateTime.get();
        return (now - lastUpdate) > CACHE_EXPIRY_MS;
    }
    
    /**
     * 更新缓存
     * @param models 模型列表
     */
    private synchronized void updateCache(List<ModelInfo> models) {
        MODEL_CACHE.put("models", models);
        lastCacheUpdateTime.set(System.currentTimeMillis());
        log.info("更新OpenRouter模型缓存，共{}个模型", models.size());
    }

    /**
     * 获取默认的OpenRouter模型列表
     *
     * @return 模型信息列表
     */
    private List<ModelInfo> getDefaultOpenRouterModels() {
        List<ModelInfo> models = new ArrayList<>();

        // OpenAI模型
        models.add(ModelInfo.basic("openai/gpt-3.5-turbo", "GPT-3.5 Turbo", "openrouter")
                .withDescription("OpenAI的GPT-3.5 Turbo模型")
                .withMaxTokens(16385)
                .withUnifiedPrice(0.0015));

        models.add(ModelInfo.basic("openai/gpt-4", "GPT-4", "openrouter")
                .withDescription("OpenAI的GPT-4模型")
                .withMaxTokens(8192)
                .withUnifiedPrice(0.03));

        models.add(ModelInfo.basic("openai/gpt-4-turbo", "GPT-4 Turbo", "openrouter")
                .withDescription("OpenAI的GPT-4 Turbo模型")
                .withMaxTokens(128000)
                .withUnifiedPrice(0.01));

        models.add(ModelInfo.basic("openai/gpt-4o", "GPT-4o", "openrouter")
                .withDescription("OpenAI的GPT-4o模型")
                .withMaxTokens(128000)
                .withUnifiedPrice(0.01));

        // Anthropic模型
        models.add(ModelInfo.basic("anthropic/claude-3-opus", "Claude 3 Opus", "openrouter")
                .withDescription("Anthropic的Claude 3 Opus模型")
                .withMaxTokens(200000)
                .withUnifiedPrice(0.015));

        models.add(ModelInfo.basic("anthropic/claude-3-sonnet", "Claude 3 Sonnet", "openrouter")
                .withDescription("Anthropic的Claude 3 Sonnet模型")
                .withMaxTokens(200000)
                .withUnifiedPrice(0.003));

        models.add(ModelInfo.basic("anthropic/claude-3-haiku", "Claude 3 Haiku", "openrouter")
                .withDescription("Anthropic的Claude 3 Haiku模型")
                .withMaxTokens(200000)
                .withUnifiedPrice(0.00025));

        // Google模型
        models.add(ModelInfo.basic("google/gemini-pro", "Gemini Pro", "openrouter")
                .withDescription("Google的Gemini Pro模型")
                .withMaxTokens(32768)
                .withUnifiedPrice(0.0001));

        models.add(ModelInfo.basic("google/gemini-1.5-pro", "Gemini 1.5 Pro", "openrouter")
                .withDescription("Google的Gemini 1.5 Pro模型")
                .withMaxTokens(1000000)
                .withUnifiedPrice(0.0007));

        // Meta模型
        models.add(ModelInfo.basic("meta-llama/llama-3-70b-instruct", "Llama 3 70B Instruct", "openrouter")
                .withDescription("Meta的Llama 3 70B Instruct模型")
                .withMaxTokens(8192)
                .withUnifiedPrice(0.0009));

        models.add(ModelInfo.basic("meta-llama/llama-3-8b-instruct", "Llama 3 8B Instruct", "openrouter")
                .withDescription("Meta的Llama 3 8B Instruct模型")
                .withMaxTokens(8192)
                .withUnifiedPrice(0.0002));

        return models;
    }
}
