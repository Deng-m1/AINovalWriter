package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 小说导入状态DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ImportStatus {

    /**
     * 状态码：PROCESSING, SAVING, INDEXING, COMPLETED, FAILED, ERROR
     */
    private String status;

    /**
     * 状态详细信息
     */
    private String message;

    /**
     * 进度百分比（可选）
     */
    private Double progress;

    public ImportStatus(String status, String message) {
        this.status = status;
        this.message = message;
        this.progress = null;
    }
}
