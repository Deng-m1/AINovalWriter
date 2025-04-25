package com.ainovel.server.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.mongodb.ReactiveMongoDatabaseFactory;
import org.springframework.data.mongodb.ReactiveMongoTransactionManager;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;
import org.springframework.data.mongodb.core.SimpleReactiveMongoDatabaseFactory;
import org.springframework.data.mongodb.core.convert.MappingMongoConverter;
import org.springframework.data.mongodb.core.convert.MongoCustomConversions;
import org.springframework.data.mongodb.core.mapping.event.LoggingEventListener;
import org.springframework.data.mongodb.repository.config.EnableReactiveMongoRepositories;
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mongodb.ConnectionString;
import com.mongodb.MongoClientSettings;
import com.mongodb.reactivestreams.client.MongoClient;
import com.mongodb.reactivestreams.client.MongoClients;
import org.springframework.core.convert.converter.Converter;
import org.springframework.data.convert.ReadingConverter;
import org.springframework.data.convert.WritingConverter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.Map;

/**
 * MongoDB配置类
 * 配置MongoDB连接、日志和统计功能
 */
@Configuration
@EnableReactiveMongoRepositories(basePackages = "com.ainovel.server.repository")
@EnableMongoRepositories(basePackages = "com.ainovel.server.repository")
public class MongoConfig {
    
    private static final Logger logger = LoggerFactory.getLogger(MongoConfig.class);
    
    @Value("${spring.data.mongodb.uri}")
    private String mongoUri;
    
    @Value("${spring.data.mongodb.database}")
    private String database;
    
    private final ObjectMapper objectMapper;
    
    public MongoConfig(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }
    
    /**
     * 创建MongoDB事件监听器，用于记录MongoDB操作日志
     * @return MongoDB事件监听器
     */
    @Bean
    public LoggingEventListener mongoEventListener() {
        return new LoggingEventListener();
    }
    
    /**
     * 自定义ReactiveMongoTemplate，添加查询统计和日志功能
     * @param mongoClient MongoDB客户端
     * @param converter MongoDB转换器
     * @return 自定义的ReactiveMongoTemplate
     */
    @Bean
    public ReactiveMongoTemplate reactiveMongoTemplate(MongoClient mongoClient, MappingMongoConverter converter) {
        ReactiveMongoTemplate template = new ReactiveMongoTemplate(mongoClient, database);
        
        // 启用日志记录
        logger.info("已配置ReactiveMongoTemplate，启用查询日志和统计");
        return template;
    }
    
    /**
     * 创建MongoDB客户端，添加性能监控
     * @return MongoDB客户端
     */
    @Bean
    public MongoClient reactiveMongoClient() {
        ConnectionString connectionString = new ConnectionString(mongoUri);
        
        MongoClientSettings settings = MongoClientSettings.builder()
                .applyConnectionString(connectionString)
                .applicationName("AINovalWriter")
                .build();
        
        logger.info("创建MongoDB客户端，连接到: {}", database);
        return MongoClients.create(settings);
    }
    
    /**
     * 创建MongoDB数据库工厂
     * @param mongoClient MongoDB客户端
     * @return MongoDB数据库工厂
     */
    @Bean
    public ReactiveMongoDatabaseFactory reactiveMongoDatabaseFactory(MongoClient mongoClient) {
        return new SimpleReactiveMongoDatabaseFactory(mongoClient, database);
    }
    
    /**
     * 创建MongoDB事务管理器
     * @param dbFactory MongoDB数据库工厂
     * @return MongoDB事务管理器
     */
    @Bean
    public ReactiveMongoTransactionManager transactionManager(ReactiveMongoDatabaseFactory dbFactory) {
        return new ReactiveMongoTransactionManager(dbFactory);
    }
    
    /**
     * 配置自定义MongoDB转换器
     * @return 自定义转换器配置
     */
    @Bean
    public MongoCustomConversions mongoCustomConversions() {
        List<Converter<?, ?>> converters = new ArrayList<>();
        converters.add(new DateToInstantConverter());
        converters.add(new InstantToDateConverter());
        converters.add(new MapToObjectConverter());
        converters.add(new ObjectToMapConverter());
        
        return new MongoCustomConversions(converters);
    }
    
    /**
     * Date到Instant的转换器
     */
    @ReadingConverter
    public static class DateToInstantConverter implements Converter<Date, Instant> {
        @Override
        public Instant convert(Date source) {
            return source == null ? null : source.toInstant();
        }
    }
    
    /**
     * Instant到Date的转换器
     */
    @WritingConverter
    public static class InstantToDateConverter implements Converter<Instant, Date> {
        @Override
        public Date convert(Instant source) {
            return source == null ? null : Date.from(source);
        }
    }
    
    /**
     * Map到Object的转换器（主要用于任务参数和进度、结果的反序列化）
     */
    @ReadingConverter
    public class MapToObjectConverter implements Converter<Map<String, Object>, Object> {
        @Override
        public Object convert(Map<String, Object> source) {
            return source; // 保持Map结构，由服务层根据上下文进行进一步反序列化
        }
    }
    
    /**
     * Object到Map的转换器（主要用于任务参数和进度、结果的序列化）
     */
    @WritingConverter
    public class ObjectToMapConverter implements Converter<Object, Map<String, Object>> {
        @SuppressWarnings("unchecked")
        @Override
        public Map<String, Object> convert(Object source) {
            if (source instanceof Map) {
                return (Map<String, Object>) source;
            }
            
            try {
                // 尝试使用Jackson将对象转换为Map
                return objectMapper.convertValue(source, Map.class);
            } catch (Exception e) {
                logger.warn("无法将对象转换为Map: {}", source, e);
                return null;
            }
        }
    }
} 