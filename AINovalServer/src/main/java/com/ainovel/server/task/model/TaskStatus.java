package com.ainovel.server.task.model;

/**
 * 后台任务状态枚举
 */
public enum TaskStatus {
    /**
     * 已加入队列，等待执行
     */
    QUEUED,
    
    /**
     * 正在执行中
     */
    RUNNING,
    
    /**
     * 执行完成（成功）
     */
    COMPLETED,
    
    /**
     * 执行失败
     */
    FAILED,
    
    /**
     * 已取消
     */
    CANCELLED,
    
    /**
     * 正在重试
     */
    RETRYING,
    
    /**
     * 死信（达到最大重试次数或不可重试的失败）
     */
    DEAD_LETTER,
    
    /**
     * 完成但有错误（适用于批量任务，部分子任务成功，部分失败）
     */
    COMPLETED_WITH_ERRORS;
    
    /**
     * 判断当前状态是否是终止状态
     * @return 如果是终止状态返回true，否则返回false
     */
    public boolean isTerminal() {
        return this == COMPLETED || this == FAILED || this == CANCELLED || 
               this == DEAD_LETTER || this == COMPLETED_WITH_ERRORS;
    }
    
    /**
     * 判断当前状态是否是活跃状态
     * @return 如果是活跃状态返回true，否则返回false
     */
    public boolean isActive() {
        return this == QUEUED || this == RUNNING || this == RETRYING;
    }
} 