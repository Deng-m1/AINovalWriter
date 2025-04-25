package com.ainovel.server.task.service.impl;

import com.ainovel.server.repository.BackgroundTaskRepository;
import com.ainovel.server.task.model.BackgroundTask;
import com.ainovel.server.task.model.TaskStatus;
import com.ainovel.server.task.event.internal.TaskApplicationEvent;
import com.ainovel.server.task.event.internal.TaskSubmittedEvent;
import com.ainovel.server.task.producer.TaskMessageProducer;
import com.ainovel.server.task.service.TaskStateService;
import com.ainovel.server.task.service.TaskSubmissionService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

/**
 * 任务提交服务实现类
 */
@Service
public class TaskSubmissionServiceImpl implements TaskSubmissionService {

    private static final Logger log = LoggerFactory.getLogger(TaskSubmissionServiceImpl.class);

    private final BackgroundTaskRepository taskRepository;
    private final TaskStateService taskStateService;
    private final TaskMessageProducer taskMessageProducer;
    private final ApplicationEventPublisher eventPublisher;
    private final ObjectMapper objectMapper;

    @Autowired
    public TaskSubmissionServiceImpl(
            BackgroundTaskRepository taskRepository,
            TaskStateService taskStateService,
            TaskMessageProducer taskMessageProducer,
            ApplicationEventPublisher eventPublisher,
            ObjectMapper objectMapper) {
        this.taskRepository = taskRepository;
        this.taskStateService = taskStateService;
        this.taskMessageProducer = taskMessageProducer;
        this.eventPublisher = eventPublisher;
        this.objectMapper = objectMapper;
    }

    @Override
    @Transactional
    public String submitTask(String userId, String taskType, Object parameters, String parentTaskId) {
        Objects.requireNonNull(userId, "用户ID不能为空");
        Objects.requireNonNull(taskType, "任务类型不能为空");
        Objects.requireNonNull(parameters, "任务参数不能为空");

        // 创建任务实体
        BackgroundTask task = new BackgroundTask();
        String taskId = UUID.randomUUID().toString();
        task.setId(taskId);
        task.setUserId(userId);
        task.setTaskType(taskType);
        task.setStatus(TaskStatus.QUEUED);
        task.setParameters(parameters);
        task.setParentTaskId(parentTaskId);
        
        Map<String, Instant> timestamps = new HashMap<>();
        timestamps.put("created", Instant.now());
        task.setTimestamps(timestamps);
        task.setRetryCount(0);
        
        // 保存任务到数据库
        BackgroundTask savedTask = taskRepository.save(task);
        if (savedTask == null) {
            throw new RuntimeException("保存任务失败");
        }

        log.info("任务已提交: taskId={}, taskType={}, userId={}", taskId, taskType, userId);

        // 发送任务消息到RabbitMQ
        try {
            taskMessageProducer.sendTask(taskId, userId, taskType, parameters);
        } catch (Exception e) {
            log.error("发送任务消息失败: taskId={}, error={}", taskId, e.getMessage(), e);
            // 如果消息发送失败，将任务状态设置为失败
            Map<String, Object> errorInfo = new HashMap<>();
            errorInfo.put("message", "消息发送失败: " + e.getMessage());
            errorInfo.put("exception", e.getClass().getName());
            errorInfo.put("timestamp", Instant.now().toString());
            
            task.setErrorInfo(errorInfo);
            task.setStatus(TaskStatus.FAILED);
            taskRepository.save(task);
            
            throw new RuntimeException("发送任务消息失败", e);
        }

        // 发布任务提交事件
        TaskApplicationEvent event = new TaskSubmittedEvent(
            this, taskId, taskType, userId, parameters, parentTaskId
        );
        eventPublisher.publishEvent(event);

        // 发送任务事件消息
        try {
            Map<String, Object> eventData = new HashMap<>();
            eventData.put("taskId", taskId);
            eventData.put("userId", userId);
            eventData.put("taskType", taskType);
            eventData.put("parameters", parameters);
            eventData.put("parentTaskId", parentTaskId);
            eventData.put("status", TaskStatus.QUEUED.name());
            eventData.put("timestamp", Instant.now().toString());
            
            taskMessageProducer.sendTaskEvent("TASK_SUBMITTED", eventData);
        } catch (Exception e) {
            log.error("发送任务事件消息失败: taskId={}, event={}, error={}", 
                      taskId, "TASK_SUBMITTED", e.getMessage(), e);
        }

        return taskId;
    }
    
    @Override
    @Transactional
    public String submitTask(String userId, String taskType, Object parameters) {
        return submitTask(userId, taskType, parameters, null);
    }
    
    @Override
    @Transactional
    public String submitTaskWithGeneratedId(String userId, String taskType, Object parameters, String parentTaskId) {
        return submitTask(userId, taskType, parameters, parentTaskId);
    }
    
    @Override
    @Transactional
    public String submitTaskWithGeneratedId(String userId, String taskType, Object parameters) {
        return submitTask(userId, taskType, parameters, null);
    }

    @Override
    public Object getTaskStatus(String taskId) {
        Objects.requireNonNull(taskId, "任务ID不能为空");
        
        BackgroundTask task = taskRepository.findById(taskId).orElse(null);
        if (task == null) {
            return null;
        }
        
        return taskToJsonResponse(task);
    }

    @Override
    public Object getTaskStatus(String taskId, String userId) {
        Objects.requireNonNull(taskId, "任务ID不能为空");
        Objects.requireNonNull(userId, "用户ID不能为空");
        
        BackgroundTask task = taskRepository.findById(taskId).orElse(null);
        if (task == null || !userId.equals(task.getUserId())) {
            return null;
        }
        
        return taskToJsonResponse(task);
    }

    @Override
    @Transactional
    public boolean cancelTask(String taskId) {
        Objects.requireNonNull(taskId, "任务ID不能为空");
        
        BackgroundTask task = taskRepository.findById(taskId).orElse(null);
        if (task == null) {
            return false;
        }
        
        // 只能取消处于排队或执行中状态的任务
        if (task.getStatus() != TaskStatus.QUEUED && task.getStatus() != TaskStatus.RUNNING 
            && task.getStatus() != TaskStatus.RETRYING) {
            return false;
        }
        
        task.setStatus(TaskStatus.CANCELLED);
        Map<String, Instant> timestamps = task.getTimestamps();
        if (timestamps == null) {
            timestamps = new HashMap<>();
            task.setTimestamps(timestamps);
        }
        timestamps.put("cancelled", Instant.now());
        
        taskRepository.save(task);
        
        // 发送取消事件消息
        try {
            Map<String, Object> eventData = new HashMap<>();
            eventData.put("taskId", taskId);
            eventData.put("userId", task.getUserId());
            eventData.put("taskType", task.getTaskType());
            eventData.put("status", TaskStatus.CANCELLED.name());
            eventData.put("timestamp", Instant.now().toString());
            
            taskMessageProducer.sendTaskEvent("TASK_CANCELLED", eventData);
        } catch (Exception e) {
            log.error("发送任务取消事件消息失败: taskId={}, error={}", 
                      taskId, e.getMessage(), e);
        }
        
        return true;
    }

    @Override
    @Transactional
    public boolean cancelTask(String taskId, String userId) {
        Objects.requireNonNull(taskId, "任务ID不能为空");
        Objects.requireNonNull(userId, "用户ID不能为空");
        
        // 验证用户是否有权限取消任务
        BackgroundTask task = taskRepository.findById(taskId).orElse(null);
        if (task == null || !userId.equals(task.getUserId())) {
            return false;
        }
        
        // 只能取消处于排队或执行中状态的任务
        if (task.getStatus() != TaskStatus.QUEUED && task.getStatus() != TaskStatus.RUNNING 
            && task.getStatus() != TaskStatus.RETRYING) {
            return false;
        }
        
        task.setStatus(TaskStatus.CANCELLED);
        Map<String, Instant> timestamps = task.getTimestamps();
        if (timestamps == null) {
            timestamps = new HashMap<>();
            task.setTimestamps(timestamps);
        }
        timestamps.put("cancelled", Instant.now());
        
        taskRepository.save(task);
        
        // 发送取消事件消息
        try {
            Map<String, Object> eventData = new HashMap<>();
            eventData.put("taskId", taskId);
            eventData.put("userId", userId);
            eventData.put("taskType", task.getTaskType());
            eventData.put("status", TaskStatus.CANCELLED.name());
            eventData.put("timestamp", Instant.now().toString());
            
            taskMessageProducer.sendTaskEvent("TASK_CANCELLED", eventData);
        } catch (Exception e) {
            log.error("发送任务取消事件消息失败: taskId={}, userId={}, error={}", 
                      taskId, userId, e.getMessage(), e);
        }
        
        return true;
    }
    
    /**
     * 将任务对象转换为JSON响应
     */
    private JsonNode taskToJsonResponse(BackgroundTask task) {
        ObjectNode response = objectMapper.createObjectNode();
        response.put("taskId", task.getId());
        response.put("userId", task.getUserId());
        response.put("taskType", task.getTaskType());
        response.put("status", task.getStatus().name());
        
        Map<String, Instant> timestamps = task.getTimestamps();
        if (timestamps != null) {
            ObjectNode timestampsNode = objectMapper.createObjectNode();
            timestamps.forEach((key, value) -> {
                if (value != null) {
                    timestampsNode.put(key, value.toString());
                }
            });
            response.set("timestamps", timestampsNode);
            
            // 为了兼容性添加特定的时间戳字段
            if (timestamps.containsKey("created")) {
                response.put("createdAt", timestamps.get("created").toString());
            }
            if (timestamps.containsKey("running")) {
                response.put("startedAt", timestamps.get("running").toString());
            }
            if (timestamps.containsKey("completed")) {
                response.put("completedAt", timestamps.get("completed").toString());
            }
        }
        
        if (task.getErrorInfo() != null) {
            response.set("errorInfo", objectMapper.valueToTree(task.getErrorInfo()));
            
            // 为了兼容性提取错误消息
            Object errorMessage = task.getErrorInfo().get("message");
            if (errorMessage != null) {
                response.put("errorMessage", errorMessage.toString());
            }
        }
        
        if (task.getResult() != null) {
            response.set("result", objectMapper.valueToTree(task.getResult()));
        }
        
        if (task.getParameters() != null) {
            response.set("parameters", objectMapper.valueToTree(task.getParameters()));
        }
        
        if (task.getProgress() != null) {
            response.set("progress", objectMapper.valueToTree(task.getProgress()));
        }
        
        if (task.getParentTaskId() != null) {
            response.put("parentTaskId", task.getParentTaskId());
        }
        
        response.put("retryCount", task.getRetryCount());
        
        if (task.getExecutionNodeId() != null) {
            response.put("executionNodeId", task.getExecutionNodeId());
        }
        
        return response;
    }
} 