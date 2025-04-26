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
 * SiliconFlow提供商能力检测器
 */
@Slf4j
@Component
public class SiliconFlowCapabilityDetector implements ProviderCapabilityDetector {

    private static final String DEFAULT_API_ENDPOINT = "https://api.siliconflow.com";

    @Override
    public String getProviderName() {
        return "siliconflow";
    }

    @Override
    public Mono<ModelListingCapability> detectModelListingCapability() {
        // SiliconFlow支持使用API密钥获取模型列表
        return Mono.just(ModelListingCapability.LISTING_WITH_KEY);
    }

    @Override
    public Flux<ModelInfo> getDefaultModels() {
        // 返回默认的SiliconFlow模型列表
        List<ModelInfo> models = new ArrayList<>();

        // 添加SiliconFlow的主要模型
        models.add(ModelInfo.builder()
            .id("mixtral-8x7b-32768")
            .name("Mixtral 8x7B 32K")
            .description("SiliconFlow提供的Mixtral 8x7B模型，支持高达32K的上下文长度")
            .maxTokens(32768)
            .provider("siliconflow")
            .build()
            .withInputPrice(0.0006)    // $0.0006 per 1K input tokens
            .withOutputPrice(0.0008)); // $0.0008 per 1K output tokens

        models.add(ModelInfo.builder()
            .id("llama-2-70b-chat")
            .name("Llama 2 70B Chat")
            .description("SiliconFlow提供的Meta Llama 2 70B Chat模型，针对对话进行了优化")
            .maxTokens(4096)
            .provider("siliconflow")
            .build()
            .withInputPrice(0.0007)    // $0.0007 per 1K input tokens
            .withOutputPrice(0.0009)); // $0.0009 per 1K output tokens

        models.add(ModelInfo.builder()
            .id("mistral-7b-instruct-v0.2")
            .name("Mistral 7B Instruct v0.2")
            .description("SiliconFlow提供的Mistral 7B Instruct v0.2模型，平衡性能与效率")
            .maxTokens(8192)
            .provider("siliconflow")
            .build()
            .withInputPrice(0.0002)    // $0.0002 per 1K input tokens
            .withOutputPrice(0.0002)); // $0.0002 per 1K output tokens

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