package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * AI模型配置数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class AIModelConfigDto {

    private String userId;
    private Object config;
}
