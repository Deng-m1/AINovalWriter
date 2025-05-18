package com.ainovel.server.service.dto;

import java.util.List;
import java.util.Map;
import lombok.Builder;
import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AiGeneratedSettingData {
    private String name;
    private String type; // 将会是 SettingType.getValue() 的字符串形式
    private String description;
    private Map<String, String> attributes;
    private List<String> tags;
} 