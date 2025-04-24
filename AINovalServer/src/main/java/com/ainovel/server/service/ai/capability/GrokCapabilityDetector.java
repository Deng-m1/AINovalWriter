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
 * X.AI提供商能力检测器
 */
@Slf4j
@Component
public class GrokCapabilityDetector implements ProviderCapabilityDetector {

    private static final String DEFAULT_API_ENDPOINT = "https://api.x.ai/v1";

    @Override
    public String getProviderName() {
        return "x-ai";
    }

    @Override
    public Mono<ModelListingCapability> detectModelListingCapability() {
        // X.AI需要API密钥获取模型列表
        return Mono.just(ModelListingCapability.LISTING_WITH_KEY);
    }

    @Override
    public Flux<ModelInfo> getDefaultModels() {
        // 返回默认的X.AI模型列表
        List<ModelInfo> models = new ArrayList<>();

        models.add(ModelInfo.builder()
            .id("x-ai/grok-3-beta")
            .name("Grok-3-beta")
            .description("X.AI的Grok-3-beta模型，支持强大的自然语言理解和生成能力")
            .maxTokens(128000)
            .provider("x-ai")
            .build()
            .withInputPrice(0.003)    // $0.003 per 1K input tokens
            .withOutputPrice(0.006)); // $0.006 per 1K output tokens

        models.add(ModelInfo.builder()
            .id("x-ai/grok-3-fast-beta")
            .name("Grok-3-fast-beta")
            .description("X.AI的Grok-3-fast-beta模型，更快的响应速度，适合对话场景")
            .maxTokens(128000)
            .provider("x-ai")
            .build()
            .withInputPrice(0.0015)    // $0.0015 per 1K input tokens
            .withOutputPrice(0.003)); // $0.003 per 1K output tokens

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
                .uri("/models")
                .header("Authorization", "Bearer " + apiKey)
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