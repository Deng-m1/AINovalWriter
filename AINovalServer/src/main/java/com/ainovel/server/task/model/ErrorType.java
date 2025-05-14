package com.ainovel.server.task.model;

/**
 * 任务执行错误类型枚举
 */
public enum ErrorType {
    /**
     * 系统内部错误
     */
    INTERNAL_ERROR,
    
    /**
     * 业务逻辑错误
     */
    BUSINESS_ERROR,
    
    /**
     * 用户输入错误
     */
    INPUT_ERROR,
    
    /**
     * 资源不存在
     */
    NOT_FOUND,
    
    /**
     * 权限错误
     */
    PERMISSION_ERROR,
    
    /**
     * 任务超时
     */
    TIMEOUT,
    
    /**
     * 任务被取消
     */
    CANCELLED,
    
    /**
     * 远程服务调用错误
     */
    REMOTE_SERVICE_ERROR,
    
    /**
     * AI模型错误
     */
    AI_MODEL_ERROR,
    
    /**
     * 未知错误
     */
    UNKNOWN
} 