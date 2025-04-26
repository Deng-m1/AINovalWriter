package com.ainovel.server.service.ai.capability;

import java.util.ArrayList;
import java.util.List;

import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

import com.ainovel.server.domain.model.ModelInfo;
import com.ainovel.server.domain.model.ModelListingCapability;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * Anthropic提供商能力检测器
 */
@Slf4j
@Component
public class AnthropicCapabilityDetector implements ProviderCapabilityDetector {

    private static final String DEFAULT_API_ENDPOINT = "https://api.anthropic.com";

    @Override
    public String getProviderName() {
        return "anthropic";
    }

    @Override
    public Mono<ModelListingCapability> detectModelListingCapability() {
        // Anthropic需要API密钥才能获取模型列表
        return Mono.just(ModelListingCapability.LISTING_WITH_KEY);
    }

    @Override
    public Flux<ModelInfo> getDefaultModels() {
        // 返回默认的Anthropic模型列表
        List<ModelInfo> models = new ArrayList<>();

        models.add(ModelInfo.builder()
            .id("claude-3-opus-20240229")
            .name("Claude 3 Opus")
            .description("最强大的Claude模型，适用于高度复杂的任务")
            .maxTokens(200000)
            .provider("anthropic")
            .build()
            .withUnifiedPrice(15.0)); // $15.0 per 1000 tokens

        models.add(ModelInfo.builder()
            .id("claude-3-sonnet-20240229")
            .name("Claude 3 Sonnet")
            .description("Claude 3 家族中的中等性能模型，在能力和速度之间有良好平衡")
            .maxTokens(200000)
            .provider("anthropic")
            .build()
            .withUnifiedPrice(3.0)); // $3.0 per 1000 tokens

        models.add(ModelInfo.builder()
            .id("claude-3-haiku-20240307")
            .name("Claude 3 Haiku")
            .description("最快速且经济实惠的Claude 3模型，适合简单任务")
            .maxTokens(200000)
            .provider("anthropic")
            .build()
            .withUnifiedPrice(0.25)); // $0.25 per 1000 tokens

        models.add(ModelInfo.builder()
            .id("claude-2.1")
            .name("Claude 2.1")
            .description("Claude 2的增强版本，具有改进的指令跟随和安全性")
            .maxTokens(100000)
            .provider("anthropic")
            .build()
            .withUnifiedPrice(8.0)); // $8.0 per 1000 tokens

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
                .build();

        return webClient.get()
                .uri("/v1/models")
                .header("x-api-key", apiKey)
                .header("anthropic-version", "2023-06-01")
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