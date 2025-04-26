package com.ainovel.server.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.dto.ApiKeyTestRequest;
import com.ainovel.server.domain.model.ModelListingCapability;
import com.ainovel.server.service.ai.capability.ProviderCapabilityService;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * 提供商能力控制器
 * 提供获取AI提供商能力和测试API密钥的REST接口
 */
@RestController
@RequestMapping("/api/providers")
@Slf4j
public class ProviderCapabilityController {

    private final ProviderCapabilityService capabilityService;

    @Autowired
    public ProviderCapabilityController(ProviderCapabilityService capabilityService) {
        this.capabilityService = capabilityService;
    }

    /**
     * 获取提供商的模型列表能力
     *
     * @param provider 提供商名称
     * @return 模型列表能力
     */
    @GetMapping("/{provider}/capability")
    public Mono<ResponseEntity<ModelListingCapability>> getProviderCapability(@PathVariable String provider) {
        log.info("获取提供商能力: {}", provider);
        
        return capabilityService.getProviderCapability(provider)
            .map(capability -> ResponseEntity.ok(capability))
            .defaultIfEmpty(ResponseEntity.notFound().build());
    }

    /**
     * 测试API密钥是否有效
     *
     * @param provider 提供商名称
     * @param request 包含API密钥和端点的请求
     * @return 测试结果
     */
    @PostMapping("/{provider}/test-api-key")
    public Mono<ResponseEntity<Boolean>> testApiKey(
            @PathVariable String provider,
            @RequestBody ApiKeyTestRequest request) {
        
        log.info("测试API密钥: provider={}", provider);
        
        return capabilityService.testApiKey(provider, request.getApiKey(), request.getApiEndpoint())
            .map(result -> ResponseEntity.ok(result))
            .defaultIfEmpty(ResponseEntity.notFound().build());
    }

    /**
     * 获取提供商的默认API端点
     *
     * @param provider 提供商名称
     * @return 默认API端点
     */
    @GetMapping("/{provider}/default-endpoint")
    public ResponseEntity<String> getDefaultApiEndpoint(@PathVariable String provider) {
        String endpoint = capabilityService.getDefaultApiEndpoint(provider);
        
        if (endpoint != null) {
            return ResponseEntity.ok(endpoint);
        } else {
            return ResponseEntity.notFound().build();
        }
    }
} 