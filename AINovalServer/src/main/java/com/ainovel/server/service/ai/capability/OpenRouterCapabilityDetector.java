package com.ainovel.server.service.ai.capability;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

import com.ainovel.server.domain.model.ModelInfo;
import com.ainovel.server.domain.model.ModelListingCapability;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * OpenRouter提供商能力检测器
 */
@Slf4j
@Component
public class OpenRouterCapabilityDetector implements ProviderCapabilityDetector {

    private static final String DEFAULT_API_ENDPOINT = "https://openrouter.ai/api";

    @Override
    public String getProviderName() {
        return "openrouter";
    }

    @Override
    public Mono<ModelListingCapability> detectModelListingCapability() {
        // OpenRouter支持API密钥获取模型列表
        return Mono.just(ModelListingCapability.LISTING_WITHOUT_KEY);
    }

    @Override
    public Flux<ModelInfo> getDefaultModels() {
        // 返回默认的OpenRouter模型列表
        List<ModelInfo> models = new ArrayList<>();

        // 添加几个常用的OpenRouter模型
        models.add(ModelInfo.builder()
            .id("anthropic/claude-3-opus:beta")
            .name("Claude 3 Opus (via OpenRouter)")
            .description("通过OpenRouter访问的Anthropic Claude 3 Opus - 强大的推理和创意能力")
            .maxTokens(48000)
            .provider("openrouter")
            .build()
            .withUnifiedPrice(0.015)); // $0.015 per 1K tokens (合并价格)

        models.add(ModelInfo.builder()
            .id("anthropic/claude-3-sonnet:beta")
            .name("Claude 3 Sonnet (via OpenRouter)")
            .description("通过OpenRouter访问的Anthropic Claude 3 Sonnet - 平衡性能与速度")
            .maxTokens(48000)
            .provider("openrouter")
            .build()
            .withUnifiedPrice(0.006)); // $0.006 per 1K tokens (合并价格)

        models.add(ModelInfo.builder()
            .id("openai/gpt-4-turbo")
            .name("GPT-4 Turbo (via OpenRouter)")
            .description("通过OpenRouter访问的OpenAI GPT-4 Turbo - 最新的GPT-4模型变体")
            .maxTokens(128000)
            .provider("openrouter")
            .build()
            .withUnifiedPrice(0.01)); // $0.01 per 1K tokens (合并价格)

        models.add(ModelInfo.builder()
            .id("meta-llama/llama-3-70b-instruct")
            .name("Llama 3 70B (via OpenRouter)")
            .description("通过OpenRouter访问的Meta Llama 3 70B Instruct - 高性能开源模型")
            .maxTokens(8192)
            .provider("openrouter")
            .build()
            .withUnifiedPrice(0.0009)); // $0.0009 per 1K tokens (合并价格)

        return Flux.fromIterable(models);
    }

    @Override
    public Mono<Boolean> testApiKey(String apiKey, String apiEndpoint) {
        if (apiKey == null || apiKey.trim().isEmpty()) {
            return Mono.just(false);
        }

        String baseUrl = apiEndpoint != null && !apiEndpoint.trim().isEmpty() ?
                apiEndpoint : DEFAULT_API_ENDPOINT;

        WebClient webClient = WebClient.builder()
                .baseUrl(baseUrl)
                .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                .build();

        return webClient.get()
                .uri("/v1/models")
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .bodyToMono(String.class)
                .map(response -> true)
                .onErrorReturn(false);
    }

    @Override
    public String getDefaultApiEndpoint() {
        return DEFAULT_API_ENDPOINT;
    }
} 