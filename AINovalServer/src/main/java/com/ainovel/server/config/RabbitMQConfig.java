package com.ainovel.server.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.AcknowledgeMode;
import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.DirectExchange;
import org.springframework.amqp.core.Exchange;
import org.springframework.amqp.core.ExchangeBuilder;
import org.springframework.amqp.core.FanoutExchange;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.rabbit.annotation.EnableRabbit;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.connection.CachingConnectionFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitAdmin;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.concurrent.Executors;

/**
 * RabbitMQ配置类
 */
@Configuration
@EnableRabbit
public class RabbitMQConfig {
    private static final Logger logger = LoggerFactory.getLogger(RabbitMQConfig.class);
    
    // 交换机名称
    public static final String TASKS_EXCHANGE = "tasks.exchange";
    public static final String TASKS_RETRY_EXCHANGE = "tasks.retry.exchange";
    public static final String TASKS_REQUEUE_EXCHANGE = "tasks.requeue.exchange";
    public static final String TASKS_DLX_EXCHANGE = "tasks.dlx.exchange";
    public static final String TASKS_EVENTS_EXCHANGE = "tasks.events.exchange";
    
    // 队列名称
    public static final String TASKS_QUEUE = "tasks.queue";
    public static final String TASKS_DLQ_QUEUE = "tasks.dlq.queue";
    public static final String TASKS_EVENTS_QUEUE = "tasks.events.queue";
    
    // 等待队列（用于延迟重试）
    public static final String TASKS_WAIT_15S_QUEUE = "tasks.wait_15s.queue";
    public static final String TASKS_WAIT_1M_QUEUE = "tasks.wait_1m.queue";
    public static final String TASKS_WAIT_5M_QUEUE = "tasks.wait_5m.queue";
    public static final String TASKS_WAIT_30M_QUEUE = "tasks.wait_30m.queue";
    
    // 路由键前缀
    public static final String TASK_TYPE_PREFIX = "task.";
    
    @Value("${spring.rabbitmq.host:localhost}")
    private String host;
    
    @Value("${spring.rabbitmq.port:5672}")
    private int port;
    
    @Value("${spring.rabbitmq.username:guest}")
    private String username;
    
    @Value("${spring.rabbitmq.password:guest}")
    private String password;
    
    @Value("${spring.rabbitmq.virtual-host:/}")
    private String virtualHost;
    
    @Value("${spring.rabbitmq.listener.simple.prefetch:1}")
    private int prefetchCount;
    
    @Value("${spring.rabbitmq.listener.simple.concurrency:5}")
    private int concurrentConsumers;
    
    @Value("${spring.rabbitmq.listener.simple.max-concurrency:10}")
    private int maxConcurrentConsumers;
    
    @Autowired
    @Qualifier("taskObjectMapper")
    private ObjectMapper objectMapper;
    
    /**
     * 配置连接工厂
     */
    @Bean
    public ConnectionFactory connectionFactory() {
        CachingConnectionFactory connectionFactory = new CachingConnectionFactory();
        connectionFactory.setHost(host);
        connectionFactory.setPort(port);
        connectionFactory.setUsername(username);
        connectionFactory.setPassword(password);
        connectionFactory.setVirtualHost(virtualHost);
        
        // 启用发布确认
        connectionFactory.setPublisherConfirmType(CachingConnectionFactory.ConfirmType.CORRELATED);
        connectionFactory.setPublisherReturns(true);
        
        return connectionFactory;
    }
    
    /**
     * 配置RabbitAdmin，用于管理交换机、队列等资源
     */
    @Bean
    public RabbitAdmin rabbitAdmin(ConnectionFactory connectionFactory) {
        RabbitAdmin rabbitAdmin = new RabbitAdmin(connectionFactory);
        rabbitAdmin.setAutoStartup(true);
        return rabbitAdmin;
    }
    
    /**
     * 配置RabbitTemplate
     */
    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        
        // 设置消息转换器
        rabbitTemplate.setMessageConverter(jackson2JsonMessageConverter());
        
        // 启用强制消息
        rabbitTemplate.setMandatory(true);
        
        // 设置消息确认回调
        rabbitTemplate.setConfirmCallback((correlationData, ack, cause) -> {
            if (!ack) {
                logger.error("消息发送失败: {} - {}", correlationData, cause);
            }
        });
        
        // 设置消息返回回调
        rabbitTemplate.setReturnsCallback(returned -> {
            logger.error("消息路由失败: {}, 交换机: {}, 路由键: {}, 原因: {}",
                    returned.getMessage(), returned.getExchange(),
                    returned.getRoutingKey(), returned.getReplyText());
        });
        
        return rabbitTemplate;
    }
    
    /**
     * 配置消息转换器
     */
    @Bean
    public Jackson2JsonMessageConverter jackson2JsonMessageConverter() {
        return new Jackson2JsonMessageConverter(objectMapper);
    }
    
    /**
     * 配置监听容器工厂
     */
    @Bean
    public SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(
            ConnectionFactory connectionFactory) {
        SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setMessageConverter(jackson2JsonMessageConverter());
        
        // 配置手动确认模式
        factory.setAcknowledgeMode(AcknowledgeMode.MANUAL);
        
        // 配置并发消费者数
        factory.setConcurrentConsumers(concurrentConsumers);
        factory.setMaxConcurrentConsumers(maxConcurrentConsumers);
        
        // 配置预取数量
        factory.setPrefetchCount(prefetchCount);
        
        // 使用虚拟线程
        factory.setTaskExecutor(Executors.newVirtualThreadPerTaskExecutor());
        
        return factory;
    }
    
    // 交换机定义

    /**
     * 任务主交换机（主题交换机）
     * 注意：改回TopicExchange以支持通配符，简化任务路由配置
     */
    @Bean
    public DirectExchange tasksExchange() {
        return new DirectExchange(TASKS_EXCHANGE, true, false);
    }
    
    /**
     * 任务重试交换机（扇形）
     */
    @Bean
    public FanoutExchange tasksRetryExchange() {
        return new FanoutExchange(TASKS_RETRY_EXCHANGE, true, false);
    }
    
    /**
     * 任务重新入队交换机（直连）
     */
    @Bean
    public DirectExchange tasksRequeueExchange() {
        return new DirectExchange(TASKS_REQUEUE_EXCHANGE, true, false);
    }
    
    /**
     * 任务死信交换机（扇形）
     */
    @Bean
    public FanoutExchange tasksDlxExchange() {
        return new FanoutExchange(TASKS_DLX_EXCHANGE, true, false);
    }
    
    /**
     * 任务事件交换机（主题）
     */
    @Bean
    public TopicExchange tasksEventsExchange() {
        return new TopicExchange(TASKS_EVENTS_EXCHANGE, true, false);
    }
    
    // 队列定义
    
    /**
     * 任务主队列
     */
    @Bean
    public Queue tasksQueue() {
        return QueueBuilder.durable(TASKS_QUEUE)
                .withArgument("x-dead-letter-exchange", TASKS_RETRY_EXCHANGE)
                .build();
    }
    
    /**
     * 任务死信队列
     */
    @Bean
    public Queue tasksDlqQueue() {
        return QueueBuilder.durable(TASKS_DLQ_QUEUE)
                .build();
    }
    
    /**
     * 任务事件队列
     */
    @Bean
    public Queue tasksEventsQueue() {
        return QueueBuilder.durable(TASKS_EVENTS_QUEUE)
                .build();
    }
    
    /**
     * 任务15秒延迟队列
     */
    @Bean
    public Queue tasksWait15sQueue() {
        return QueueBuilder.durable(TASKS_WAIT_15S_QUEUE)
                .withArgument("x-dead-letter-exchange", TASKS_REQUEUE_EXCHANGE)
                .withArgument("x-message-ttl", 15000) // 15秒
                .build();
    }
    
    /**
     * 任务1分钟延迟队列
     */
    @Bean
    public Queue tasksWait1mQueue() {
        return QueueBuilder.durable(TASKS_WAIT_1M_QUEUE)
                .withArgument("x-dead-letter-exchange", TASKS_REQUEUE_EXCHANGE)
                .withArgument("x-message-ttl", 60000) // 1分钟
                .build();
    }
    
    /**
     * 任务5分钟延迟队列
     */
    @Bean
    public Queue tasksWait5mQueue() {
        return QueueBuilder.durable(TASKS_WAIT_5M_QUEUE)
                .withArgument("x-dead-letter-exchange", TASKS_REQUEUE_EXCHANGE)
                .withArgument("x-message-ttl", 300000) // 5分钟
                .build();
    }
    
    /**
     * 任务30分钟延迟队列
     */
    @Bean
    public Queue tasksWait30mQueue() {
        return QueueBuilder.durable(TASKS_WAIT_30M_QUEUE)
                .withArgument("x-dead-letter-exchange", TASKS_REQUEUE_EXCHANGE)
                .withArgument("x-message-ttl", 1800000) // 30分钟
                .build();
    }
    
    // 绑定定义
    
    /**
     * 任务重试交换机 -> 等待队列绑定
     */
    @Bean
    public Binding tasksRetryToWait15sBinding() {
        return BindingBuilder.bind(tasksWait15sQueue()).to(tasksRetryExchange());
    }
    
    /**
     * 任务重试交换机 -> 等待队列绑定
     */
    @Bean
    public Binding tasksRetryToWait1mBinding() {
        return BindingBuilder.bind(tasksWait1mQueue()).to(tasksRetryExchange());
    }
    
    /**
     * 任务重试交换机 -> 等待队列绑定
     */
    @Bean
    public Binding tasksRetryToWait5mBinding() {
        return BindingBuilder.bind(tasksWait5mQueue()).to(tasksRetryExchange());
    }
    
    /**
     * 任务重试交换机 -> 等待队列绑定
     */
    @Bean
    public Binding tasksRetryToWait30mBinding() {
        return BindingBuilder.bind(tasksWait30mQueue()).to(tasksRetryExchange());
    }
    
    /**
     * 任务重新入队交换机 -> 任务主队列绑定
     */
    @Bean
    public Binding tasksRequeueToTasksBinding() {
        return BindingBuilder.bind(tasksQueue())
                .to(tasksRequeueExchange())
                .with("#"); // 匹配所有路由键
    }
    
    /**
     * 任务死信交换机 -> 死信队列绑定
     */
    @Bean
    public Binding tasksDlxToDlqBinding() {
        return BindingBuilder.bind(tasksDlqQueue()).to(tasksDlxExchange());
    }
    
    /**
     * 任务事件交换机 -> 事件队列绑定
     */
    @Bean
    public Binding tasksEventsToQueueBinding() {
        return BindingBuilder.bind(tasksEventsQueue())
                .to(tasksEventsExchange())
                .with("task.event.#"); // 使用通配符匹配所有task.event开头的路由键
    }
    
    // /**
    //  * 通用任务绑定 - 捕获所有任务类型
    //  * 使用通配符将所有task.前缀的消息路由到任务队列
    //  * 这是推荐的绑定方式，可以自动处理新的任务类型。
    //  */
    // @Bean
    // public Binding allTasksBinding() {
    //     return BindingBuilder.bind(tasksQueue())
    //             .to(tasksExchange()) // 确保绑定到TopicExchange
    //             .with(TASK_TYPE_PREFIX + "#"); // 匹配所有task.前缀的路由键
    // }
    
    /**
     * 创建任务生成摘要类型的绑定
     * (冗余，已被 allTasksBinding 覆盖)
     */
    @Bean
    public Binding generateSummaryBinding() {
        return BindingBuilder.bind(tasksQueue())
                .to(tasksExchange())
                .with(TASK_TYPE_PREFIX + "GENERATE_SUMMARY");
    }
    
    /**
     * 创建任务生成场景类型的绑定
     * (冗余，已被 allTasksBinding 覆盖)
     */
    @Bean
    public Binding generateSceneBinding() {
        return BindingBuilder.bind(tasksQueue())
                .to(tasksExchange())
                .with(TASK_TYPE_PREFIX + "GENERATE_SCENE");
    }
    
    /**
     * 创建批量生成摘要任务类型的绑定
     * (冗余，已被 allTasksBinding 覆盖)
     */
    @Bean
    public Binding batchGenerateSummaryBinding() {
        return BindingBuilder.bind(tasksQueue())
                .to(tasksExchange())
                .with(TASK_TYPE_PREFIX + "BATCH_GENERATE_SUMMARY");
    }
    
    /**
     * 创建批量生成场景任务类型的绑定
     * (冗余，已被 allTasksBinding 覆盖)
     */
    @Bean
    public Binding batchGenerateSceneBinding() {
        return BindingBuilder.bind(tasksQueue())
                .to(tasksExchange())
                .with(TASK_TYPE_PREFIX + "BATCH_GENERATE_SCENE");
    }
    
    /**
     * 创建续写内容任务类型的绑定
     * (冗余，已被 allTasksBinding 覆盖)
     */
    @Bean
    public Binding continueWritingContentBinding() {
        return BindingBuilder.bind(tasksQueue())
                .to(tasksExchange())
                .with(TASK_TYPE_PREFIX + "CONTINUE_WRITING_CONTENT");
    }
    
    /**
     * 创建生成下一章摘要任务类型的绑定
     * (冗余，已被 allTasksBinding 覆盖)
     */
    @Bean
    public Binding generateNextSummariesOnlyBinding() {
        return BindingBuilder.bind(tasksQueue())
                .to(tasksExchange())
                .with(TASK_TYPE_PREFIX + "GENERATE_NEXT_SUMMARIES_ONLY");
    }

    @Bean
    public Binding generateSingleChapterOnlyBinding() {
        return BindingBuilder.bind(tasksQueue())
                .to(tasksExchange())
                .with(TASK_TYPE_PREFIX + "GENERATE_SINGLE_CHAPTER");
    }

    
    /**
     * 创建生成单个摘要任务类型的绑定 (子任务)
     * (冗余，已被 allTasksBinding 覆盖)
     */
    @Bean
    public Binding generateSingleSummaryBinding() {
        return BindingBuilder.bind(tasksQueue())
                .to(tasksExchange())
                .with(TASK_TYPE_PREFIX + "GENERATE_SINGLE_SUMMARY"); // 添加这个子任务的绑定(虽然冗余)
    }
} 