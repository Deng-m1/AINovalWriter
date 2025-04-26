package com.ainovel.server.task.service;

import java.util.List;
import java.util.Map;

/**
 * 死信处理服务接口
 */
public interface DeadLetterService {
    
    /**
     * 获取死信队列信息
     * @return 队列信息，包含消息数量等
     */
    Map<String, Object> getDeadLetterQueueInfo();
    
    /**
     * 列出死信队列中的消息
     * @param limit 最大返回消息数量
     * @return 消息列表
     */
    List<Map<String, Object>> listDeadLetters(int limit);
    
    /**
     * 重试特定的死信消息
     * @param taskId 任务ID
     * @return 是否成功重新发送
     */
    boolean retryDeadLetter(String taskId);
    
    /**
     * 清空死信队列
     * @return 是否成功清空
     */
    boolean purgeDeadLetterQueue();
}