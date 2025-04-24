package com.ainovel.server.service.ai.factory;

import com.ainovel.server.config.ProxyConfig;
import com.ainovel.server.service.ai.AIModelProvider;
import com.ainovel.server.service.ai.AnthropicModelProvider;
import com.ainovel.server.service.ai.XaiModelProvider;
import com.ainovel.server.service.ai.langchain4j.AnthropicLangChain4jModelProvider;
import com.ainovel.server.service.ai.langchain4j.GeminiLangChain4jModelProvider;
import com.ainovel.server.service.ai.langchain4j.LangChain4jModelProvider;
import com.ainovel.server.service.ai.langchain4j.OpenAILangChain4jModelProvider;
import com.ainovel.server.service.ai.langchain4j.OpenRouterLangChain4jModelProvider;
import com.ainovel.server.service.ai.langchain4j.SiliconFlowLangChain4jModelProvider;
import com.ainovel.server.service.ai.langchain4j.TogetherAILangChain4jModelProvider;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * AI模型提供商工厂类
 * 使用工厂方法模式创建不同类型的AI模型提供商实例
 */
@Slf4j
@Component
public class AIModelProviderFactory {

    private final ProxyConfig proxyConfig;

    @Autowired
    public AIModelProviderFactory(ProxyConfig proxyConfig) {
        this.proxyConfig = proxyConfig;
    }

    /**
     * 创建AI模型提供商实例
     *
     * @param providerName 提供商名称
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     * @return AI模型提供商实例
     */
    public AIModelProvider createProvider(String providerName, String modelName, String apiKey, String apiEndpoint) {
        log.info("创建AI模型提供商: {}, 模型: {}", providerName, modelName);
        
        return switch (providerName.toLowerCase()) {
            case "openai" -> new OpenAILangChain4jModelProvider(modelName, apiKey, apiEndpoint, proxyConfig);
            case "anthropic" -> new AnthropicLangChain4jModelProvider(modelName, apiKey, apiEndpoint);
            case "gemini" -> new GeminiLangChain4jModelProvider(modelName, apiKey, apiEndpoint, proxyConfig);
            case "openrouter" -> new OpenRouterLangChain4jModelProvider(modelName, apiKey, apiEndpoint, proxyConfig);
            case "siliconflow" -> new SiliconFlowLangChain4jModelProvider(modelName, apiKey, apiEndpoint);
            case "togetherai" -> new TogetherAILangChain4jModelProvider(modelName, apiKey, apiEndpoint, proxyConfig);
            case "x-ai", "grok" -> new XaiModelProvider(modelName, apiKey, apiEndpoint, proxyConfig);
            case "anthropic-native" -> new AnthropicModelProvider(modelName, apiKey, apiEndpoint);
            default -> throw new IllegalArgumentException("不支持的AI提供商: " + providerName);
        };
    }

    /**
     * 通过提供商名称判断是否使用LangChain4j实现
     *
     * @param providerName 提供商名称
     * @return 是否使用LangChain4j实现
     */
    public boolean isLangChain4jProvider(String providerName) {
        String lowerCaseProvider = providerName.toLowerCase();
        
        return switch (lowerCaseProvider) {
            case "openai", "anthropic", "gemini", "openrouter", "siliconflow", "togetherai" -> true;
            default -> false;
        };
    }

    /**
     * 获取提供商类型
     *
     * @param provider AI模型提供商实例
     * @return 提供商类型
     */
    public String getProviderType(AIModelProvider provider) {
        if (provider instanceof LangChain4jModelProvider) {
            return "langchain4j";
        } else if (provider instanceof XaiModelProvider) {
            return "x-ai";
        } else if (provider instanceof AnthropicModelProvider) {
            return "anthropic-native";
        } else {
            return "unknown";
        }
    }
} 