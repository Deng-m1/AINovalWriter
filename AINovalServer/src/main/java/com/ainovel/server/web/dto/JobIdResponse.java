package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 任务ID响应DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class JobIdResponse {

    /**
     * 任务ID
     */
    private String jobId;
}
