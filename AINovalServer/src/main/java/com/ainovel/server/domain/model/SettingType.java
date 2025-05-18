package com.ainovel.server.domain.model;

import com.fasterxml.jackson.annotation.JsonValue;

/**
 * 小说设定类型枚举
 * 定义了可以由AI生成或用户创建的设定类型。
 * 与前端 AINoval/lib/models/setting_type.dart (或类似路径下的常量/枚举) 保持一致。
 */
public enum SettingType {
    CHARACTER("CHARACTER", "角色"),
    LOCATION("LOCATION", "地点"),
    ITEM("ITEM", "物品"),
    LORE("LORE", "背景知识"), // 世界观/传说/规则等
    FACTION("FACTION", "组织/势力"),
    EVENT("EVENT", "事件"),
    CONCEPT("CONCEPT", "概念/规则"), // 细化的规则或抽象概念
    CREATURE("CREATURE", "生物/种族"),
    MAGIC_SYSTEM("MAGIC_SYSTEM", "魔法体系"),
    TECHNOLOGY("TECHNOLOGY", "科技设定"),
    OTHER("OTHER", "其他");

    private final String value;
    private final String displayName;

    SettingType(String value, String displayName) {
        this.value = value;
        this.displayName = displayName;
    }

    @JsonValue // This annotation is important for Jackson serialization/deserialization
    public String getValue() {
        return value;
    }

    public String getDisplayName() {
        return displayName;
    }

    public static SettingType fromValue(String value) {
        for (SettingType type : values()) {
            if (type.value.equalsIgnoreCase(value)) {
                return type;
            }
        }
        // Fallback to OTHER or throw an exception if strict matching is required
        // throw new IllegalArgumentException("Unknown setting type: " + value); 
        return OTHER; 
    }

    @Override
    public String toString() {
        return this.value;
    }
} 