package com.ainovel.server.task.model;

/**
 * 后台任务状态枚举
 */
public enum TaskStatus {
    /**
     * 已入队，等待执行
     */
    QUEUED,
    
    /**
     * 正在执行中
     */
    RUNNING,
    
    /**
     * 已完成（成功）
     */
    COMPLETED,
    
    /**
     * 已失败
     */
    FAILED,
    
    /**
     * 已取消
     */
    CANCELLED,
    
    /**
     * 重试中
     */
    RETRYING,
    
    /**
     * 无法处理（达到最大重试次数或不可重试的错误）
     */
    DEAD_LETTER,
    
    /**
     * 完成但存在错误（适用于带子任务的批量任务，部分子任务成功而部分失败）
     */
    COMPLETED_WITH_ERRORS
} 