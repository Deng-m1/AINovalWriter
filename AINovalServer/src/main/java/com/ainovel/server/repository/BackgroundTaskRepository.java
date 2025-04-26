package com.ainovel.server.repository;

import com.ainovel.server.task.model.BackgroundTask;
import com.ainovel.server.task.model.TaskStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 后台任务存储库接口
 */
@Repository
public interface BackgroundTaskRepository extends MongoRepository<BackgroundTask, String> {
    
    /**
     * 根据用户ID查找任务
     * @param userId 用户ID
     * @return 任务列表
     */
    List<BackgroundTask> findByUserId(String userId);
    
    /**
     * 根据用户ID分页查找任务
     * @param userId 用户ID
     * @param pageable 分页参数
     * @return 任务分页结果
     */
    Page<BackgroundTask> findByUserId(String userId, Pageable pageable);
    
    /**
     * 根据用户ID和任务类型查找任务
     * @param userId 用户ID
     * @param taskType 任务类型
     * @return 任务列表
     */
    List<BackgroundTask> findByUserIdAndTaskType(String userId, String taskType);
    
    /**
     * 根据父任务ID查找子任务
     * @param parentTaskId 父任务ID
     * @return 子任务列表
     */
    List<BackgroundTask> findByParentTaskId(String parentTaskId);
    
    /**
     * 根据父任务ID和状态查找子任务
     * @param parentTaskId 父任务ID
     * @param status 任务状态
     * @return 子任务列表
     */
    List<BackgroundTask> findByParentTaskIdAndStatus(String parentTaskId, TaskStatus status);
    
    /**
     * 计算父任务下指定状态的子任务数量
     * @param parentTaskId 父任务ID
     * @param status 任务状态
     * @return 子任务数量
     */
    long countByParentTaskIdAndStatus(String parentTaskId, TaskStatus status);
    
    /**
     * 根据任务类型和状态查找任务
     * @param taskType 任务类型
     * @param status 任务状态
     * @return 任务列表
     */
    List<BackgroundTask> findByTaskTypeAndStatus(String taskType, TaskStatus status);
    
    /**
     * 根据用户ID、任务类型和状态查找任务
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param status 任务状态
     * @return 任务列表
     */
    List<BackgroundTask> findByUserIdAndTaskTypeAndStatus(String userId, String taskType, TaskStatus status);
    
    /**
     * 查找指定状态的任务
     * @param status 任务状态
     * @return 任务列表
     */
    List<BackgroundTask> findByStatus(TaskStatus status);
} 