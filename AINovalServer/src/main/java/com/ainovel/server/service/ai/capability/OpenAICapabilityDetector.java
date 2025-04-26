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
 * OpenAI提供商能力检测器
 */
@Slf4j
@Component
public class OpenAICapabilityDetector implements ProviderCapabilityDetector {

    private static final String DEFAULT_API_ENDPOINT = "https://api.openai.com/v1";

    @Override
    public String getProviderName() {
        return "openai";
    }

    @Override
    public Mono<ModelListingCapability> detectModelListingCapability() {
        // OpenAI需要API密钥才能获取模型列表
        return Mono.just(ModelListingCapability.LISTING_WITH_KEY);
    }

    @Override
    public Flux<ModelInfo> getDefaultModels() {
        List<ModelInfo> models = new ArrayList<>();

        models.add(ModelInfo.basic("gpt-3.5-turbo", "GPT-3.5 Turbo", "openai")
                .withDescription("OpenAI的GPT-3.5 Turbo模型")
                .withMaxTokens(16385)
                .withInputPrice(0.0015)
                .withOutputPrice(0.002));

        models.add(ModelInfo.basic("gpt-3.5-turbo-16k", "GPT-3.5 Turbo 16K", "openai")
                .withDescription("OpenAI的GPT-3.5 Turbo 16K模型")
                .withMaxTokens(16385)
                .withInputPrice(0.003)
                .withOutputPrice(0.004));

        models.add(ModelInfo.basic("gpt-4", "GPT-4", "openai")
                .withDescription("OpenAI的GPT-4模型")
                .withMaxTokens(8192)
                .withInputPrice(0.03)
                .withOutputPrice(0.06));

        models.add(ModelInfo.basic("gpt-4-32k", "GPT-4 32K", "openai")
                .withDescription("OpenAI的GPT-4 32K模型")
                .withMaxTokens(32768)
                .withInputPrice(0.06)
                .withOutputPrice(0.12));

        models.add(ModelInfo.basic("gpt-4-turbo", "GPT-4 Turbo", "openai")
                .withDescription("OpenAI的GPT-4 Turbo模型")
                .withMaxTokens(128000)
                .withInputPrice(0.01)
                .withOutputPrice(0.03));

        models.add(ModelInfo.basic("gpt-4o", "GPT-4o", "openai")
                .withDescription("OpenAI的GPT-4o模型")
                .withMaxTokens(128000)
                .withInputPrice(0.01)
                .withOutputPrice(0.03));

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