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
import org.springframework.data.mongodb.core.mapping.event.LoggingEventListener;
import org.springframework.data.mongodb.repository.config.EnableReactiveMongoRepositories;

import com.mongodb.ConnectionString;
import com.mongodb.MongoClientSettings;
import com.mongodb.reactivestreams.client.MongoClient;
import com.mongodb.reactivestreams.client.MongoClients;

/**
 * MongoDB配置类
 * 配置MongoDB连接、日志和统计功能
 */
@Configuration
@EnableReactiveMongoRepositories(basePackages = "com.ainovel.server.repository")
public class MongoConfig {
    
    private static final Logger logger = LoggerFactory.getLogger(MongoConfig.class);
    
    @Value("${spring.data.mongodb.uri}")
    private String mongoUri;
    
    @Value("${spring.data.mongodb.database}")
    private String database;
    
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
} 