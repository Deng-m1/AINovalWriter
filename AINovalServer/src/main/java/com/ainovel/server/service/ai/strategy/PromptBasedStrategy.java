package com.ainovel.server.service.ai.strategy;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.NovelSettingItem;
import com.ainovel.server.service.PromptService;
import com.ainovel.server.service.ai.AIModelProvider;
import com.ainovel.server.service.dto.AiGeneratedSettingData;
import com.fasterxml.jackson.databind.ObjectMapper;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * 基于提示词的策略实现类
 * 适用于各种模型，通过提示词引导模型输出符合要求的JSON格式
 */
@Slf4j
@RequiredArgsConstructor
public class PromptBasedStrategy implements SettingGenerationStrategy {

    private final PromptService promptService;
    private final ObjectMapper objectMapper;

    @Override
    public Mono<List<NovelSettingItem>> generateSettings(
            String novelId, 
            String userId, 
            String chapterContext, 
            List<String> validRequestedTypes, 
            int maxSettingsPerType,
            String additionalInstructions,
            AIModelProvider aiModelProvider) {
        
        log.debug("使用基于提示词的策略生成设定");
        
        try {
            // 获取设定类型字符串表示
            String settingTypesForPrompt = String.join(", ", validRequestedTypes);
            
            // 获取通用提示词
            return promptService.getGeneralSettingPrompt(chapterContext, settingTypesForPrompt, maxSettingsPerType, additionalInstructions)
                .flatMap(prompt -> {
                    // 创建请求
                    AIRequest request = new AIRequest();
                    request.setUserId(userId);
                    request.setNovelId(novelId);
                    
                    // 创建系统消息
                    AIRequest.Message systemMessage = new AIRequest.Message();
                    systemMessage.setRole("system");
                    systemMessage.setContent("你是一个专业的小说设定分析专家。需要以JSON格式输出。");
                    request.getMessages().add(systemMessage);
                    
                    // 创建用户消息
                    AIRequest.Message userMessage = new AIRequest.Message();
                    userMessage.setRole("user");
                    userMessage.setContent(prompt);
                    request.getMessages().add(userMessage);
                    
                    // 使用模型生成内容
                    return aiModelProvider.generateContent(request)
                        .flatMap(response -> {
                            try {
                                String jsonContent = extractJsonFromResponse(response.getContent());
                                List<AiGeneratedSettingData> generatedDataList = objectMapper.readValue(
                                    jsonContent, 
                                    objectMapper.getTypeFactory().constructCollectionType(List.class, AiGeneratedSettingData.class)
                                );
                                
                                // 转换为NovelSettingItem
                                List<NovelSettingItem> novelSettingItems = generatedDataList.stream()
                                    .map(data -> SettingGenerationStrategyFactory.convertToNovelSettingItem(data, novelId, userId, validRequestedTypes))
                                    .filter(java.util.Objects::nonNull)
                                    .collect(Collectors.toList());
                                
                                log.info("基于提示词成功生成 {} 个设定项, novelId: {}", novelSettingItems.size(), novelId);
                                return Mono.just(novelSettingItems);
                            } catch (Exception e) {
                                log.error("解析AI响应为JSON时出错, novelId {}: {}", novelId, e.getMessage(), e);
                                return Mono.error(new RuntimeException("无法解析AI响应为有效JSON: " + e.getMessage(), e));
                            }
                        });
                });
                
        } catch (Exception e) {
            log.error("使用提示词生成设定时出错, novelId {}: {}", novelId, e.getMessage(), e);
            return Mono.error(new RuntimeException("提示词设定生成失败: " + e.getMessage(), e));
        }
    }
    
    /**
     * 从AI响应中提取JSON
     * 
     * @param response AI响应内容
     * @return 提取的JSON字符串
     */
    private String extractJsonFromResponse(String response) {
        // 简单JSON提取 - 查找第一个[开始和最后一个]结束
        int startIdx = response.indexOf('[');
        int endIdx = response.lastIndexOf(']') + 1;
        
        if (startIdx >= 0 && endIdx > startIdx) {
            return response.substring(startIdx, endIdx);
        }
        
        // 如果未找到JSON数组，尝试查找JSON对象
        startIdx = response.indexOf('{');
        endIdx = response.lastIndexOf('}') + 1;
        
        if (startIdx >= 0 && endIdx > startIdx) {
            // 将单个对象包装为数组
            return "[" + response.substring(startIdx, endIdx) + "]";
        }
        
        // 如果没有找到有效JSON，抛出异常
        throw new IllegalArgumentException("无法从响应中提取JSON: " + response);
    }
} 