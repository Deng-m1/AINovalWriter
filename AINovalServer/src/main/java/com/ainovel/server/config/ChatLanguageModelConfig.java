package com.ainovel.server.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import lombok.extern.slf4j.Slf4j;

/**
 * 聊天语言模型配置类
 */
@Slf4j
@Configuration
public class ChatLanguageModelConfig {

    @Value("${ai.openai.api-key}")
    private String openaiApiKey;

    @Value("${ai.openai.chat-model:deepseek/deepseek-v3-base:free}")
    private String openaiChatModel;

    @Value("${ai.openai.temperature:0.7}")
    private double temperature;

    @Value("${ai.openai.max-tokens:1024}")
    private int maxTokens;

    /**
     * 配置聊天语言模型
     *
     * @return 聊天语言模型
     */
    @Bean
    public ChatLanguageModel chatLanguageModel() {
        log.info("配置ChatLanguageModel，模型：{}", openaiChatModel);

        ChatLanguageModel chatLanguageModel= OpenAiChatModel.builder()
                .baseUrl("https://openrouter.ai/api/v1")
                .apiKey(openaiApiKey)
                .modelName(openaiChatModel)
                .temperature(temperature)
                .maxTokens(maxTokens)
                .logRequests(true)
                .logResponses(true)
                .build();
        //String message= chatLanguageModel.("1+1=");
        //log.info(message);
        return chatLanguageModel;
    }
}
