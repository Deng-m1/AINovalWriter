package com.ainovel.server.config;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonDeserializer;
import com.fasterxml.jackson.databind.JsonSerializer;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * 后台任务系统专用的Jackson配置类
 * 提供专为BackgroundTask的parameters、progress、result对象设计的序列化/反序列化支持
 */
@Configuration
public class TaskJacksonConfig {

    /**
     * 创建后台任务系统专用的ObjectMapper
     * @param objectMapper 从全局JacksonConfig中获取的基础配置
     * @return 后台任务系统专用的ObjectMapper
     */
    @Bean(name = "taskObjectMapper")
    public ObjectMapper taskObjectMapper(@Autowired ObjectMapper objectMapper) {
        // 基于全局ObjectMapper创建专用实例
        ObjectMapper taskMapper = objectMapper.copy();
        
        // 注册自定义模块
        SimpleModule taskModule = new SimpleModule("TaskModule");
        
        // 为特定类型添加序列化器
        configureSerializers(taskModule);
        
        // 为特定类型添加反序列化器
        configureDeserializers(taskModule);
        
        // 注册模块
        taskMapper.registerModule(taskModule);
        
        // 允许未知属性
        taskMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        
        // 确保保留空集合
        taskMapper.configure(SerializationFeature.WRITE_EMPTY_JSON_ARRAYS, true);
        
        // 确保Map中的null值也被序列化，以便在更新进度时能够显式地设置null
        taskMapper.setSerializationInclusion(JsonInclude.Include.ALWAYS);
        
        return taskMapper;
    }
    
    /**
     * 配置序列化器
     * @param module 要配置的SimpleModule
     */
    private void configureSerializers(SimpleModule module) {
        // 例如，为Instant类型添加自定义的序列化器
        // module.addSerializer(Instant.class, new CustomInstantSerializer());
    }
    
    /**
     * 配置反序列化器
     * @param module 要配置的SimpleModule
     */
    private void configureDeserializers(SimpleModule module) {
        // 例如，为Instant类型添加自定义的反序列化器
        // module.addDeserializer(Instant.class, new CustomInstantDeserializer());
    }
    
    /**
     * 可用于在Map类型和特定对象类型间进行转换的帮助方法
     * @param map 源Map
     * @param targetClass 目标类型
     * @param objectMapper ObjectMapper实例
     * @return 转换后的对象
     */
    public static <T> T convertMapToObject(Map<String, Object> map, Class<T> targetClass, ObjectMapper objectMapper) {
        if (map == null) {
            return null;
        }
        try {
            return objectMapper.convertValue(map, targetClass);
        } catch (Exception e) {
            throw new RuntimeException("无法将Map转换为" + targetClass.getName(), e);
        }
    }
    
    /**
     * 将对象转换为Map的帮助方法
     * @param object 源对象
     * @param objectMapper ObjectMapper实例
     * @return 转换后的Map
     */
    @SuppressWarnings("unchecked")
    public static Map<String, Object> convertObjectToMap(Object object, ObjectMapper objectMapper) {
        if (object == null) {
            return new HashMap<>();
        }
        if (object instanceof Map) {
            return (Map<String, Object>) object;
        }
        try {
            return objectMapper.convertValue(object, Map.class);
        } catch (Exception e) {
            throw new RuntimeException("无法将对象转换为Map", e);
        }
    }
} 