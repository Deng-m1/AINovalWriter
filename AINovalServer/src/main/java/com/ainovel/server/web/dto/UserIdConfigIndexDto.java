package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 用户ID和配置索引数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserIdConfigIndexDto {

    private String userId;
    private int configIndex;
    private Object config;
}
