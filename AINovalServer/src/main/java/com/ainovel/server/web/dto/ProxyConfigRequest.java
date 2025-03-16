package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 代理配置请求DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProxyConfigRequest {
    
    /**
     * 代理主机
     */
    private String proxyHost;
    
    /**
     * 代理端口
     */
    private int proxyPort;
} 