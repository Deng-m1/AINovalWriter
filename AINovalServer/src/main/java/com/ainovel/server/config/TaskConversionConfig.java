package com.ainovel.server.config;

import com.ainovel.server.task.dto.scenegeneration.GenerateSceneParameters;
import com.ainovel.server.task.dto.scenegeneration.GenerateSceneResult;
import com.ainovel.server.task.dto.summarygeneration.GenerateSummaryParameters;
import com.ainovel.server.task.dto.summarygeneration.GenerateSummaryResult;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.type.TypeFactory;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.TypeDescriptor;
import org.springframework.core.convert.converter.GenericConverter;
import org.springframework.data.mongodb.core.convert.MongoCustomConversions;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 任务转换配置类
 * 提供后台任务系统参数、进度、结果对象的响应式序列化/反序列化支持
 */
@Slf4j
@Configuration
public class TaskConversionConfig {

    private final ObjectMapper objectMapper;
    
    // 任务类型到参数类型的映射
    private final Map<String, Class<?>> parameterTypeMap = new ConcurrentHashMap<>();
    
    // 任务类型到结果类型的映射
    private final Map<String, Class<?>> resultTypeMap = new ConcurrentHashMap<>();
    
    @Autowired
    public TaskConversionConfig(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
        
        // 初始化类型映射
        initializeTypeMapping();
    }
    
    /**
     * 初始化任务类型到参数类型和结果类型的映射
     */
    private void initializeTypeMapping() {
        // 摘要生成任务
        parameterTypeMap.put("GenerateSummaryTask", GenerateSummaryParameters.class);
        resultTypeMap.put("GenerateSummaryTask", GenerateSummaryResult.class);
        
        // 场景生成任务
        parameterTypeMap.put("GenerateSceneTask", GenerateSceneParameters.class);
        resultTypeMap.put("GenerateSceneTask", GenerateSceneResult.class);
        
        // 可以继续添加其他任务类型的映射...
    }
    
    /**
     * 根据任务类型和原始数据对象，反序列化为指定类型的参数对象
     * @param taskType 任务类型
     * @param source 原始数据（通常是Map）
     * @return 反序列化后的参数对象的Mono
     */
    public Mono<Object> convertParametersToType(String taskType, Object source) {
        if (source == null) {
            return Mono.empty();
        }
        
        Class<?> targetType = parameterTypeMap.get(taskType);
        if (targetType == null) {
            log.warn("未找到任务类型 {} 的参数类型映射", taskType);
            return Mono.justOrEmpty(source);
        }
        
        return Mono.fromCallable(() -> {
            try {
                if (source instanceof Map) {
                    return objectMapper.convertValue(source, targetType);
                } else if (targetType.isInstance(source)) {
                    return source;
                } else {
                    return objectMapper.readValue(objectMapper.writeValueAsString(source), targetType);
                }
            } catch (Exception e) {
                log.error("反序列化任务参数失败, taskType={}", taskType, e);
                return source; // 如果转换失败，返回原始对象
            }
        }).subscribeOn(Schedulers.boundedElastic());
    }
    
    /**
     * 根据任务类型和原始数据对象，反序列化为指定类型的结果对象
     * @param taskType 任务类型
     * @param source 原始数据（通常是Map）
     * @return 反序列化后的结果对象的Mono
     */
    public Mono<Object> convertResultToType(String taskType, Object source) {
        if (source == null) {
            return Mono.empty();
        }
        
        Class<?> targetType = resultTypeMap.get(taskType);
        if (targetType == null) {
            log.warn("未找到任务类型 {} 的结果类型映射", taskType);
            return Mono.justOrEmpty(source);
        }
        
        return Mono.fromCallable(() -> {
            try {
                if (source instanceof Map) {
                    return objectMapper.convertValue(source, targetType);
                } else if (targetType.isInstance(source)) {
                    return source;
                } else {
                    return objectMapper.readValue(objectMapper.writeValueAsString(source), targetType);
                }
            } catch (Exception e) {
                log.error("反序列化任务结果失败, taskType={}", taskType, e);
                return source; // 如果转换失败，返回原始对象
            }
        }).subscribeOn(Schedulers.boundedElastic());
    }
    
    /**
     * 将任意对象序列化为MongoDB可存储的格式，通常是Map
     * @param source 源对象
     * @return 序列化后的对象的Mono
     */
    public Mono<Object> convertToStorageFormat(Object source) {
        if (source == null) {
            return Mono.empty();
        }
        
        return Mono.fromCallable(() -> {
            try {
                if (source instanceof Map) {
                    return source;
                } else {
                    return objectMapper.convertValue(source, Map.class);
                }
            } catch (Exception e) {
                log.error("序列化对象为存储格式失败", e);
                // 如果无法转换为Map，尝试使用toString()
                Map<String, String> result = new HashMap<>();
                result.put("value", source.toString());
                result.put("_conversion_error", "true");
                return result;
            }
        }).subscribeOn(Schedulers.boundedElastic());
    }
    
    /**
     * 为指定的任务类型注册参数类型
     * @param taskType 任务类型
     * @param parameterClass 参数类型的Class
     */
    public void registerParameterType(String taskType, Class<?> parameterClass) {
        parameterTypeMap.put(taskType, parameterClass);
        log.info("已注册任务类型 {} 的参数类型: {}", taskType, parameterClass.getName());
    }
    
    /**
     * 为指定的任务类型注册结果类型
     * @param taskType 任务类型
     * @param resultClass 结果类型的Class
     */
    public void registerResultType(String taskType, Class<?> resultClass) {
        resultTypeMap.put(taskType, resultClass);
        log.info("已注册任务类型 {} 的结果类型: {}", taskType, resultClass.getName());
    }
} 