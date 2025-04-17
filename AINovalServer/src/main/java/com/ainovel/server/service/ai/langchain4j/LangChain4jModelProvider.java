package com.ainovel.server.service.ai.langchain4j;

import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import com.ainovel.server.config.ProxyConfig;
import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.service.ai.AIModelProvider;

import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.chat.StreamingChatLanguageModel;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.model.chat.response.StreamingChatResponseHandler;
import lombok.Getter;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.publisher.Sinks;
import reactor.util.retry.Retry;

/**
 * LangChain4j模型提供商基类 使用LangChain4j框架实现AI模型集成
 */
@Slf4j
public abstract class LangChain4jModelProvider implements AIModelProvider {

    @Getter
    protected final String providerName;

    @Getter
    protected final String modelName;

    protected final String apiKey;

    protected final String apiEndpoint;

    // 代理配置
    @Getter
    protected String proxyHost;

    @Getter
    protected int proxyPort;

    @Getter
    protected boolean proxyEnabled;

    private ProxyConfig proxyConfig;

    // LangChain4j模型实例
    protected ChatLanguageModel chatModel;
    protected StreamingChatLanguageModel streamingChatModel;

    /**
     * 构造函数
     *
     * @param providerName 提供商名称
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     */
    protected LangChain4jModelProvider(String providerName, String modelName, String apiKey, String apiEndpoint) {
        this.providerName = providerName;
        this.modelName = modelName;
        this.apiKey = apiKey;
        this.apiEndpoint = apiEndpoint;
        this.proxyEnabled = true;

        // 初始化模型
        initModels();
    }

    protected LangChain4jModelProvider(String providerName, String modelName, String apiKey, String apiEndpoint, ProxyConfig proxyConfig) {
        this.providerName = providerName;
        this.modelName = modelName;
        this.apiKey = apiKey;
        this.apiEndpoint = apiEndpoint;
        this.proxyEnabled = true;
        this.proxyConfig = proxyConfig;

        // 初始化模型
        initModels();
    }

    /**
     * 初始化LangChain4j模型 子类必须实现此方法来创建具体的模型实例
     */
    protected abstract void initModels();

    /**
     * 设置HTTP代理
     *
     * @param host 代理主机
     * @param port 代理端口
     */
    @Override
    public void setProxy(String host, int port) {
        this.proxyHost = host;
        this.proxyPort = port;
        this.proxyEnabled = true;

        // 重新初始化模型以应用代理设置
        initModels();
    }

    /**
     * 禁用HTTP代理
     */
    @Override
    public void disableProxy() {
        this.proxyEnabled = false;
        this.proxyHost = null;
        this.proxyPort = 0;

        // 重新初始化模型以应用代理设置
        initModels();
    }

    /**
     * 配置系统代理 使用系统属性设置HTTP和HTTPS代理
     */
    protected void configureSystemProxy() throws NoSuchAlgorithmException, KeyManagementException {
        if (proxyConfig != null && proxyConfig.isProxyEnabled()) {
            String host = proxyConfig.getProxyHost();
            int port = proxyConfig.getProxyPort();
            log.info("Gemini Provider: 检测到 ProxyConfig 已启用，配置系统HTTP/S代理: Host={}, Port={}", host, port);
            System.setProperty("http.proxyHost", host);
            System.setProperty("http.proxyPort", String.valueOf(port));
            System.setProperty("https.proxyHost", host);
            System.setProperty("https.proxyPort", String.valueOf(port));
            log.info("Gemini Provider: 已设置Java系统代理属性。");
            // 创建信任管理器

            TrustManager[] trustAllCerts = new TrustManager[]{
                new X509TrustManager() {
                    @Override
                    public void checkClientTrusted(X509Certificate[] x509Certificates, String s) throws CertificateException {
                    }

                    public X509Certificate[] getAcceptedIssuers() {
                        return null;
                    }

                    public void checkServerTrusted(X509Certificate[] certs, String authType) {
                    }

                }

            };

            // 初始化SSLContext
            SSLContext sc = SSLContext.getInstance("SSL");

            sc.init(null, trustAllCerts, new java.security.SecureRandom());

            HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory());
        } else {
            log.info("Gemini Provider: ProxyConfig 未启用或未配置，清除系统HTTP/S代理设置。");
            // 清除系统代理设置
            System.clearProperty("http.proxyHost");
            System.clearProperty("http.proxyPort");
            System.clearProperty("https.proxyHost");
            System.clearProperty("https.proxyPort");
            log.info("Gemini Provider: 已清除Java系统代理属性。");
        }
    }

    @Override
    public Mono<AIResponse> generateContent(AIRequest request) {
        if (isApiKeyEmpty()) {
            return Mono.error(new RuntimeException("API密钥未配置"));
        }

        if (chatModel == null) {
            return Mono.error(new RuntimeException("模型未初始化"));
        }

        // 使用defer延迟执行
        return Mono.defer(() -> {
            // 创建一个临时对象作为锁
            final Object syncLock = new Object();
            final AIResponse[] responseHolder = new AIResponse[1];
            final Throwable[] errorHolder = new Throwable[1];
            
            log.info("开始生成内容, 模型: {}, userId: {}", modelName, request.getUserId());
            
            // 记录开始时间
            final long startTime = System.currentTimeMillis();
            
            try {
                // 使用同步块保证完整执行
                synchronized (syncLock) {
                    // 转换请求为LangChain4j格式
                    List<ChatMessage> messages = convertToLangChain4jMessages(request);

                    // 调用LangChain4j模型 - 这是阻塞调用
                    ChatResponse response = chatModel.chat(messages);
                    
                    // 转换响应并保存到holder
                    responseHolder[0] = convertToAIResponse(response, request);
                }
                
                // 记录完成时间
                log.info("内容生成完成, 耗时: {}ms, 模型: {}, userId: {}", 
                        System.currentTimeMillis() - startTime, modelName, request.getUserId());
                
                // 返回结果
                return Mono.justOrEmpty(responseHolder[0])
                        .switchIfEmpty(Mono.error(new RuntimeException("生成的响应为空")));
                
            } catch (Exception e) {
                log.error("生成内容时出错, 模型: {}, userId: {}, 错误: {}", 
                        modelName, request.getUserId(), e.getMessage(), e);
                // 保存错误
                errorHolder[0] = e;
                return Mono.error(new RuntimeException("生成内容时出错: " + e.getMessage(), e));
            }
        })
        .doOnCancel(() -> {
            // 请求被取消时的处理
            log.warn("AI内容生成请求被取消, 模型: {}, userId: {}, 但模型可能仍在后台继续生成", 
                    modelName, request.getUserId());
        })
        .timeout(Duration.ofSeconds(120)) // 添加2分钟超时
        .retryWhen(Retry.backoff(2, Duration.ofSeconds(1))
                .filter(throwable -> !(throwable instanceof RuntimeException && 
                        throwable.getMessage() != null && 
                        throwable.getMessage().contains("API密钥未配置"))))
        .onErrorResume(e -> {
            // 处理所有剩余错误，返回包含错误信息的响应
            AIResponse errorResponse = new AIResponse();
            errorResponse.setContent("生成内容时出错: " + e.getMessage());
            // 通过反射设置status属性，因为AIResponse可能没有直接的setStatus方法
            try {
                errorResponse.getClass().getMethod("setStatus", String.class)
                    .invoke(errorResponse, "error");
            } catch (Exception ex) {
                log.warn("无法设置AIResponse的status属性", ex);
            }
            return Mono.just(errorResponse);
        });
    }

    @Override
    public Flux<String> generateContentStream(AIRequest request) {
        if (isApiKeyEmpty()) {
            return Flux.just("错误：API密钥未配置");
        }

        if (streamingChatModel == null) {
            return Flux.just("错误：流式模型未初始化");
        }

        try {
            // 转换请求为LangChain4j格式
            List<ChatMessage> messages = convertToLangChain4jMessages(request);

            // 创建Sink用于流式输出，支持暂停
            Sinks.Many<String> sink = Sinks.many().unicast().onBackpressureBuffer();

            // 记录请求开始时间，用于问题诊断
            final long requestStartTime = System.currentTimeMillis();
            final AtomicLong firstChunkTime = new AtomicLong(0);
            // 标记是否已经收到了任何内容
            final AtomicBoolean hasReceivedContent = new AtomicBoolean(false);

            // 创建响应处理器
            StreamingChatResponseHandler handler = new StreamingChatResponseHandler() {
                @Override
                public void onPartialResponse(String partialResponse) {
                    // 记录首个响应到达时间
                    if (firstChunkTime.get() == 0) {
                        firstChunkTime.set(System.currentTimeMillis());
                        hasReceivedContent.set(true);
                        log.info("收到首个LLM响应, 耗时: {}ms, 模型: {}",
                                firstChunkTime.get() - requestStartTime, modelName);
                    }

                    if (sink.currentSubscriberCount() > 0) {
                        sink.tryEmitNext(partialResponse);
                    }
                }

                @Override
                public void onCompleteResponse(ChatResponse response) {
                    log.info("LLM响应完成，总耗时: {}ms, 模型: {}",
                            System.currentTimeMillis() - requestStartTime, modelName);
                    if (sink.currentSubscriberCount() > 0) {
                        sink.tryEmitComplete();
                    }
                }

                @Override
                public void onError(Throwable error) {
                    log.error("LLM流式生成内容时出错，总耗时: {}ms, 模型: {}",
                            System.currentTimeMillis() - requestStartTime, modelName, error);
                    if (sink.currentSubscriberCount() > 0) {
                        sink.tryEmitNext("错误：" + error.getMessage());
                        sink.tryEmitComplete();
                    }
                }
            };

            // 调用流式模型并添加日志
            log.info("开始调用LLM流式模型 {}, 消息数量: {}", modelName, messages.size());
            streamingChatModel.chat(messages, handler);
            log.info("LLM流式模型调用已发出，等待响应...");

            // 创建一个完成信号 - 用于控制心跳流的结束
            final Sinks.One<Boolean> completionSignal = Sinks.one();

            // 主内容流
            Flux<String> mainStream = sink.asFlux()
                    // 添加延迟重试，避免网络抖动导致请求失败
                    .retryWhen(Retry.backoff(1, Duration.ofSeconds(2))
                            .filter(error -> {
                                // 只对网络错误或超时错误进行重试
                                boolean isNetworkError = error instanceof java.net.SocketException
                                        || error instanceof java.io.IOException
                                        || error instanceof java.util.concurrent.TimeoutException;
                                if (isNetworkError) {
                                    log.warn("LLM流式生成遇到网络错误，将进行重试: {}", error.getMessage());
                                }
                                return isNetworkError;
                            })
                    )
                    .timeout(Duration.ofSeconds(300)) // 增加超时时间到300秒，避免大模型生成时间过长导致中断
                    .doOnComplete(() -> {
                        // 发出完成信号，通知心跳流停止
                        completionSignal.tryEmitValue(true);
                        log.debug("主流完成，已发送停止心跳信号");
                    })
                    .doOnCancel(() -> {
                        // 取消时如果已经收到内容，不要关闭sink
                        if (!hasReceivedContent.get()) {
                            // 只有在没有收到任何内容时才完成sink
                            log.debug("主流取消，但未收到任何响应，发送停止心跳信号");
                            completionSignal.tryEmitValue(true);
                        } else {
                            log.debug("主流取消，但已收到内容，保持sink开放以接收后续内容");
                        }
                    })
                    .doOnError(error -> {
                        // 错误时也发出完成信号
                        completionSignal.tryEmitValue(true);
                        log.debug("主流出错，已发送停止心跳信号: {}", error.getMessage());
                    });

            // 心跳流，当completionSignal发出时停止
            Flux<String> heartbeatStream = Flux.interval(Duration.ofSeconds(15))
                    .map(tick -> {
                        log.debug("发送LLM心跳信号 #{}", tick);
                        return "heartbeat";
                    })
                    .filter(signal -> sink.currentSubscriberCount() > 0)
                    // 使用takeUntil操作符，当completionSignal发出值时停止心跳
                    .takeUntilOther(completionSignal.asMono());

            // 合并主流和心跳流
            return Flux.merge(mainStream, heartbeatStream)
                    .onErrorResume(e -> {
                        log.error("流式生成内容时出错: {}，总耗时: {}ms", e.getMessage(),
                                System.currentTimeMillis() - requestStartTime, e);
                        return Flux.just("错误：" + e.getMessage());
                    })
                    .doOnCancel(() -> {
                        // 如果已经收到内容，记录不同的日志
                        if (hasReceivedContent.get()) {
                            log.info("流式生成被取消，但已收到内容，保持模型连接以完成生成。首次响应耗时: {}ms, 总耗时: {}ms",
                                    firstChunkTime.get() - requestStartTime,
                                    System.currentTimeMillis() - requestStartTime);
                        } else {
                            log.info("流式生成被取消，未收到任何内容，总耗时: {}ms",
                                    System.currentTimeMillis() - requestStartTime);

                            // 只有在没有收到内容时才完成sink
                            try {
                                if (sink.currentSubscriberCount() > 0) {
                                    sink.tryEmitComplete();
                                }
                                // 确保心跳流也停止
                                completionSignal.tryEmitValue(true);
                            } catch (Exception ex) {
                                log.warn("取消流生成时完成sink出错，可以忽略", ex);
                            }
                        }
                    });
        } catch (Exception e) {
            log.error("准备流式生成内容时出错", e);
            return Flux.just("错误：" + e.getMessage());
        }
    }

    @Override
    public Mono<Double> estimateCost(AIRequest request) {
        // 默认实现，子类可以根据具体模型覆盖此方法
        // 简单估算，基于输入令牌数和输出令牌数
        int inputTokens = estimateInputTokens(request);
        int outputTokens = request.getMaxTokens() != null ? request.getMaxTokens() : 1000;

        // 默认价格（每1000个令牌的美元价格）
        double inputPricePerThousandTokens = 0.001;
        double outputPricePerThousandTokens = 0.002;

        // 计算成本（美元）
        double costInUSD = (inputTokens / 1000.0) * inputPricePerThousandTokens
                + (outputTokens / 1000.0) * outputPricePerThousandTokens;

        // 转换为人民币（假设汇率为7.2）
        double costInCNY = costInUSD * 7.2;

        return Mono.just(costInCNY);
    }

    @Override
    public Mono<Boolean> validateApiKey() {
        if (isApiKeyEmpty()) {
            return Mono.just(false);
        }

        if (chatModel == null) {
            return Mono.just(false);
        }

        // 尝试发送一个简单请求来验证API密钥
        try {
            List<ChatMessage> messages = new ArrayList<>();
            messages.add(new UserMessage("测试"));
            chatModel.chat(messages);
            return Mono.just(true);
        } catch (Exception e) {
            log.error("验证API密钥时出错", e);
            return Mono.just(false);
        }
    }

    /**
     * 将AIRequest转换为LangChain4j消息列表
     *
     * @param request AI请求
     * @return LangChain4j消息列表
     */
    protected List<ChatMessage> convertToLangChain4jMessages(AIRequest request) {
        List<ChatMessage> messages = new ArrayList<>();

        // 添加系统提示（如果有）
        if (request.getPrompt() != null && !request.getPrompt().isEmpty()) {
            messages.add(new SystemMessage(request.getPrompt()));
        }

        // 添加对话历史
        for (AIRequest.Message message : request.getMessages()) {
            switch (message.getRole().toLowerCase()) {
                case "user":
                    messages.add(new UserMessage(message.getContent()));
                    break;
                case "assistant":
                    messages.add(new AiMessage(message.getContent()));
                    break;
                case "system":
                    messages.add(new SystemMessage(message.getContent()));
                    break;
                default:
                    log.warn("未知的消息角色: {}", message.getRole());
                    messages.add(new UserMessage(message.getContent()));
            }
        }

        return messages;
    }

    /**
     * 将LangChain4j响应转换为AIResponse
     *
     * @param chatResponse LangChain4j聊天响应
     * @param request 原始请求
     * @return AI响应
     */
    protected AIResponse convertToAIResponse(ChatResponse chatResponse, AIRequest request) {
        AIResponse aiResponse = createBaseResponse("", request);

        // 设置内容
        AiMessage aiMessage = chatResponse.aiMessage();
        aiResponse.setContent(aiMessage.text());

        // 设置令牌使用情况（注意：ChatResponse可能没有直接提供令牌使用情况）
        AIResponse.TokenUsage usage = new AIResponse.TokenUsage();
        // 这里可能需要从其他地方获取令牌使用情况
        aiResponse.setTokenUsage(usage);

        // 设置完成原因
        aiResponse.setFinishReason("stop"); // LangChain4j可能没有直接提供完成原因

        return aiResponse;
    }

    /**
     * 创建基础AI响应
     *
     * @param content 内容
     * @param request 请求
     * @return AI响应
     */
    protected AIResponse createBaseResponse(String content, AIRequest request) {
        AIResponse response = new AIResponse();
        response.setId(UUID.randomUUID().toString());
        response.setModel(getModelName());
        response.setContent(content);
        response.setCreatedAt(LocalDateTime.now());
        response.setTokenUsage(new AIResponse.TokenUsage());
        return response;
    }

    /**
     * 创建错误响应
     *
     * @param errorMessage 错误消息
     * @param request 请求
     * @return 错误响应
     */
    protected AIResponse createErrorResponse(String errorMessage, AIRequest request) {
        AIResponse response = createBaseResponse(errorMessage, request);
        response.setFinishReason("error");
        return response;
    }

    /**
     * 检查API密钥是否为空
     *
     * @return 是否为空
     */
    protected boolean isApiKeyEmpty() {
        return apiKey == null || apiKey.trim().isEmpty();
    }

    /**
     * 获取API端点
     *
     * @param defaultEndpoint 默认端点
     * @return 实际使用的端点
     */
    protected String getApiEndpoint(String defaultEndpoint) {
        return apiEndpoint != null && !apiEndpoint.trim().isEmpty() ? apiEndpoint : defaultEndpoint;
    }

    /**
     * 估算输入令牌数
     *
     * @param request AI请求
     * @return 估算的令牌数
     */
    protected int estimateInputTokens(AIRequest request) {
        int tokenCount = 0;

        // 估算提示中的令牌数
        if (request.getPrompt() != null) {
            tokenCount += estimateTokenCount(request.getPrompt());
        }

        // 估算消息中的令牌数
        for (AIRequest.Message message : request.getMessages()) {
            tokenCount += estimateTokenCount(message.getContent());
        }

        return tokenCount;
    }

    /**
     * 估算文本的令牌数
     *
     * @param text 文本
     * @return 令牌数
     */
    protected int estimateTokenCount(String text) {
        if (text == null || text.isEmpty()) {
            return 0;
        }
        // 简单估算：平均每个单词1.3个令牌
        return (int) (text.split("\\s+").length * 1.3);
    }
}
