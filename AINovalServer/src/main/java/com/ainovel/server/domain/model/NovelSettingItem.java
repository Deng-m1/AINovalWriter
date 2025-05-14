package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 小说设定条目实体
 * 用于存储小说的设定信息，如世界观、人物、地点、物品、纪年史等
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "novel_setting_items")
@CompoundIndexes({
    @CompoundIndex(name = "novel_type_name_idx", def = "{'novelId': 1, 'type': 1, 'name': 1}"),
    @CompoundIndex(name = "novel_scene_idx", def = "{'novelId': 1, 'sceneIds': 1}"),
    @CompoundIndex(name = "novel_status_idx", def = "{'novelId': 1, 'status': 1}")
})
public class NovelSettingItem {
    
    @Id
    private String id;
    
    // 关联的小说ID
    private String novelId;
    
    // 关联的用户ID
    private String userId;
    
    // 设定条目名称
    private String name;
    
    // 设定条目类型 (如：人物、地点、物品、时间线等)
    private String type;
    
    // 设定条目描述
    private String description;
    
    // 设定条目属性 (键值对形式存储各种属性)
    private Map<String, String> attributes;
    
    // 设定条目图像URL (如有)
    private String imageUrl;
    
    // 与其他设定条目的关系
    private List<SettingRelationship> relationships;
    
    // 关联的场景ID列表
    private List<String> sceneIds;
    
    // 设定条目优先级 (1-10，用于控制在相关性相似时的排序)
    private Integer priority;
    
    // 生成方式 (manual, ai_generated, imported)
    private String generatedBy;
    
    // 设定条目标签
    private List<String> tags;
    
    // 设定条目状态 (active, inactive, draft, suggested)
    private String status;
    
    // 设定向量数据 (存储嵌入后的向量，用于相似性搜索)
    private List<Float> vector;
    
    // 创建时间
    private LocalDateTime createdAt;
    
    // 最后更新时间
    private LocalDateTime updatedAt;
    
    // 该设定条目是否为待审核的AI建议
    private boolean isAiSuggestion;
    
    // 额外元数据
    private Map<String, Object> metadata;
    
    /**
     * 设定关系实体
     * 描述设定条目之间的关系
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SettingRelationship {
        
        // 目标设定条目ID
        private String targetItemId;
        
        // 关系类型 (如：父子关系、友谊关系、敌对关系、地理包含等)
        private String type;
        
        // 关系描述
        private String description;
        
        // 关系强度 (1-10)
        private Integer strength;
        
        // 关系方向 (单向、双向)
        private String direction;
        
        // 关系创建时间
        private LocalDateTime createdAt;
        
        // 关系额外属性
        private Map<String, Object> attributes;
    }
} 