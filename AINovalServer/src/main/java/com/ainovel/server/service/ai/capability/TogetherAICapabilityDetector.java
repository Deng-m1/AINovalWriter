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
 * TogetherAI提供商能力检测器
 */
@Slf4j
@Component
public class TogetherAICapabilityDetector implements ProviderCapabilityDetector {

    private static final String DEFAULT_API_ENDPOINT = "https://api.together.xyz";

    @Override
    public String getProviderName() {
        return "togetherai";
    }

    @Override
    public Mono<ModelListingCapability> detectModelListingCapability() {
        // TogetherAI支持使用API密钥获取模型列表
        return Mono.just(ModelListingCapability.LISTING_WITH_KEY);
    }

    @Override
    public Flux<ModelInfo> getDefaultModels() {
        // 返回默认的TogetherAI模型列表
        List<ModelInfo> models = new ArrayList<>();

        // 添加TogetherAI的主要模型
        models.add(ModelInfo.builder()
            .id("mistralai/Mixtral-8x7B-Instruct-v0.1")
            .name("Mixtral 8x7B Instruct")
            .description("Mixtral 8x7B是一个高性能的稀疏混合专家模型，在多种基准测试中表现优异")
            .maxTokens(32768)
            .provider("togetherai")
            .build()
            .withUnifiedPrice(0.0006)); // $0.0006 per 1K tokens

        models.add(ModelInfo.builder()
            .id("meta-llama/Llama-3-70b-chat")
            .name("Llama 3 70B Chat")
            .description("Meta发布的Llama 3 70B模型，为对话进行了优化")
            .maxTokens(8192)
            .provider("togetherai")
            .build()
            .withUnifiedPrice(0.0009)); // $0.0009 per 1K tokens

        models.add(ModelInfo.builder()
            .id("meta-llama/Llama-3-8b-chat")
            .name("Llama 3 8B Chat")
            .description("Meta发布的Llama 3 8B模型，体积小但保持了良好的性能")
            .maxTokens(8192)
            .provider("togetherai")
            .build()
            .withUnifiedPrice(0.0002)); // $0.0002 per 1K tokens

        models.add(ModelInfo.builder()
            .id("google/gemma-7b-it")
            .name("Gemma 7B IT")
            .description("Google发布的轻量级开源模型，在效率和性能之间取得平衡")
            .maxTokens(8192)
            .provider("togetherai")
            .build()
            .withUnifiedPrice(0.0001)); // $0.0001 per 1K tokens

        models.add(ModelInfo.builder()
            .id("Qwen/Qwen2.5-7B-Instruct")
            .name("Qwen 2.5 7B Instruct")
            .description("通义千问2.5 7B指令模型，阿里巴巴开发的高性能多语言模型")
            .maxTokens(32768)
            .provider("togetherai")
            .build()
            .withUnifiedPrice(0.0002)); // $0.0002 per 1K tokens

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