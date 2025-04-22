package com.ainovel.server.web.dto;

import java.util.List;
import java.util.stream.Collectors;

import com.ainovel.server.domain.model.OptimizationResult;
import com.ainovel.server.domain.model.OptimizationSection;
import com.ainovel.server.domain.model.OptimizationStatistics;
import com.fasterxml.jackson.annotation.JsonInclude;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 优化结果DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class OptimizationResultDto {
    private String optimizedContent;
    private List<OptimizationSectionDto> sections;
    private OptimizationStatisticsDto statistics;
    
    /**
     * 从实体转换为DTO
     */
    public static OptimizationResultDto fromEntity(OptimizationResult entity) {
        List<OptimizationSectionDto> sectionDtos = entity.getSections().stream()
                .map(OptimizationSectionDto::fromEntity)
                .collect(Collectors.toList());
        
        return OptimizationResultDto.builder()
                .optimizedContent(entity.getOptimizedContent())
                .sections(sectionDtos)
                .statistics(OptimizationStatisticsDto.fromEntity(entity.getStatistics()))
                .build();
    }
    
    /**
     * 优化区块DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class OptimizationSectionDto {
        private String title;
        private String content;
        private String original;
        private String type;
        
        /**
         * 从实体转换为DTO
         */
        public static OptimizationSectionDto fromEntity(OptimizationSection entity) {
            return OptimizationSectionDto.builder()
                    .title(entity.getTitle())
                    .content(entity.getContent())
                    .original(entity.getOriginal())
                    .type(entity.getType())
                    .build();
        }
    }
    
    /**
     * 优化统计数据DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class OptimizationStatisticsDto {
        private int originalTokens;
        private int optimizedTokens;
        private int originalLength;
        private int optimizedLength;
        private double efficiency;
        
        /**
         * 从实体转换为DTO
         */
        public static OptimizationStatisticsDto fromEntity(OptimizationStatistics entity) {
            return OptimizationStatisticsDto.builder()
                    .originalTokens(entity.getOriginalTokens())
                    .optimizedTokens(entity.getOptimizedTokens())
                    .originalLength(entity.getOriginalLength())
                    .optimizedLength(entity.getOptimizedLength())
                    .efficiency(entity.getEfficiency())
                    .build();
        }
    }
} 