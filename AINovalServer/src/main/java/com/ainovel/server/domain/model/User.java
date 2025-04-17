package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 用户领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "users")
public class User {
    
    @Id
    private String id;
    
    @Indexed(unique = true)
    private String username;
    
    private String password;
    
    @Indexed(unique = true)
    private String email;
    
    private String displayName;
    
    private String avatar;
    
    /**
     * 用户角色
     */
    @Builder.Default
    private List<String> roles = new ArrayList<>();

    
    /**
     * 用户偏好设置
     */
    @Builder.Default
    private Map<String, Object> preferences = new HashMap<>();
    
    private LocalDateTime createdAt;
    
    private LocalDateTime updatedAt;
    

} 