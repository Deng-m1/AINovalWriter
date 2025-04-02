package com.ainovel.server.service.ai.langchain4j;

import com.ainovel.server.config.ProxyConfig;
import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.service.ai.AIModelProvider;
import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.StreamingResponseHandler;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.chat.StreamingChatLanguageModel;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.model.chat.response.StreamingChatResponseHandler;
import dev.langchain4j.model.output.Response;
import dev.langchain4j.model.output.TokenUsage;
import lombok.Getter;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.publisher.Sinks;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;

/**
 * LangChain4j模型提供商基类
 * 使用LangChain4j框架实现AI模型集成
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

    protected LangChain4jModelProvider(String providerName, String modelName, String apiKey, String apiEndpoint,ProxyConfig proxyConfig) {
        this.providerName = providerName;
        this.modelName = modelName;
        this.apiKey = apiKey;
        this.apiEndpoint = apiEndpoint;
        this.proxyEnabled = true;
        this.proxyConfig=proxyConfig;

        // 初始化模型
        initModels();
    }
    
    /**
     * 初始化LangChain4j模型
     * 子类必须实现此方法来创建具体的模型实例
     */
    protected abstract void initModels();
    
    /**
     * 设置HTTP代理
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
     * 配置系统代理
     * 使用系统属性设置HTTP和HTTPS代理
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
            return Mono.just(createErrorResponse("API密钥未配置", request));
        }
        
        if (chatModel == null) {
            return Mono.just(createErrorResponse("模型未初始化", request));
        }
        
        try {
            // 转换请求为LangChain4j格式
            List<ChatMessage> messages = convertToLangChain4jMessages(request);
            
            // 调用LangChain4j模型
            ChatResponse response = chatModel.chat(messages);
            AiMessage aiMessage = response.aiMessage();

            // 转换响应
            return Mono.just(convertToAIResponse(response, request));
        } catch (Exception e) {
            log.error("生成内容时出错", e);
            return Mono.just(createErrorResponse("生成内容时出错: " + e.getMessage(), request));
        }
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
            
            // 创建Sink用于流式输出
            Sinks.Many<String> sink = Sinks.many().unicast().onBackpressureBuffer();
            
            // 创建响应处理器
            StreamingChatResponseHandler handler = new StreamingChatResponseHandler() {
                @Override
                public void onPartialResponse(String partialResponse) {
                    sink.tryEmitNext(partialResponse);
                }
                
                @Override
                public void onCompleteResponse(ChatResponse response) {
                    sink.tryEmitComplete();
                }
                
                @Override
                public void onError(Throwable error) {
                    log.error("流式生成内容时出错", error);
                    sink.tryEmitNext("错误：" + error.getMessage());
                    sink.tryEmitComplete();
                }
            };
            
            // 调用流式模型
            streamingChatModel.chat(messages, handler);
            
            // 返回Flux
            return sink.asFlux();
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
        double costInUSD = (inputTokens / 1000.0) * inputPricePerThousandTokens + 
                           (outputTokens / 1000.0) * outputPricePerThousandTokens;
        
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
     * @return 是否为空
     */
    protected boolean isApiKeyEmpty() {
        return apiKey == null || apiKey.trim().isEmpty();
    }
    
    /**
     * 获取API端点
     * @param defaultEndpoint 默认端点
     * @return 实际使用的端点
     */
    protected String getApiEndpoint(String defaultEndpoint) {
        return apiEndpoint != null && !apiEndpoint.trim().isEmpty() ? apiEndpoint : defaultEndpoint;
    }
    
    /**
     * 估算输入令牌数
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