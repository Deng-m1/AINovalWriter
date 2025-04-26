package com.ainovel.server.service.ai.capability;

import java.util.ArrayList;
import java.util.List;

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
 * Gemini提供商能力检测器
 */
@Slf4j
@Component
public class GeminiCapabilityDetector implements ProviderCapabilityDetector {

    private static final String DEFAULT_API_ENDPOINT = "https://generativelanguage.googleapis.com";

    @Override
    public String getProviderName() {
        return "gemini";
    }

    @Override
    public Mono<ModelListingCapability> detectModelListingCapability() {
        // Gemini不支持直接列出所有模型，需要使用默认模型列表
        return Mono.just(ModelListingCapability.NO_LISTING);
    }

    @Override
    public Flux<ModelInfo> getDefaultModels() {
        // 返回默认的Gemini模型列表
        List<ModelInfo> models = new ArrayList<>();

        // 添加Gemini的主要模型
        models.add(ModelInfo.builder()
            .id("gemini-1.5-pro")
            .name("Gemini 1.5 Pro")
            .description("Google的最新多模态模型，具有强大的推理能力，上下文窗口高达1百万token")
            .maxTokens(1000000)
            .provider("gemini")
            .build()
            .withInputPrice(0.00035)   // $0.00035 per 1K input tokens (估算值)
            .withOutputPrice(0.00035)); // $0.00035 per 1K output tokens (估算值)

        models.add(ModelInfo.builder()
            .id("gemini-1.5-flash")
            .name("Gemini 1.5 Flash")
            .description("Gemini的快速版本，在保持强大能力的同时提供更低延迟和成本")
            .maxTokens(1000000)
            .provider("gemini")
            .build()
            .withInputPrice(0.00008)   // $0.00008 per 1K input tokens (估算值)
            .withOutputPrice(0.00008)); // $0.00008 per 1K output tokens (估算值)

        models.add(ModelInfo.builder()
            .id("gemini-1.0-pro")
            .name("Gemini 1.0 Pro")
            .description("Gemini的旧版Pro模型，提供优秀的多模态理解和生成能力")
            .maxTokens(32768)
            .provider("gemini")
            .build()
            .withInputPrice(0.00025)   // $0.00025 per 1K input tokens (估算值)
            .withOutputPrice(0.00025)); // $0.00025 per 1K output tokens (估算值)

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
                .uri("/v1/models?key=" + apiKey)
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