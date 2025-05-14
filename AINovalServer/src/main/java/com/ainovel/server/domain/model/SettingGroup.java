package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 小说设定组实体
 * 用于管理一组相关的设定条目，可以标记为特定上下文中激活的设定组
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "setting_groups")
@CompoundIndex(name = "novel_name_idx", def = "{'novelId': 1, 'name': 1}")
public class SettingGroup {
    
    @Id
    private String id;
    
    // 关联的小说ID
    private String novelId;
    
    // 关联的用户ID
    private String userId;
    
    // 设定组名称
    private String name;
    
    // 设定组描述
    private String description;
    
    // 组内设定条目ID列表
    private List<String> itemIds;
    
    // 是否为激活的上下文
    private boolean isActiveContext;
    
    // 标签
    private List<String> tags;
    
    // 创建时间
    private LocalDateTime createdAt;
    
    // 最后更新时间
    private LocalDateTime updatedAt;
} 