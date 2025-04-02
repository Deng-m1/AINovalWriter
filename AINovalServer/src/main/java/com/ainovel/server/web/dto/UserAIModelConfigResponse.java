package com.ainovel.server.web.dto;

import com.ainovel.server.domain.model.UserAIModelConfig;
import java.time.LocalDateTime;

/**
 * 用于返回给前端的用户配置信息 DTO (隐藏了 apiKey)
 */
public record UserAIModelConfigResponse(
        String id,
        String userId,
        String provider,
        String modelName,
        String alias,
        String apiEndpoint,
        boolean isValidated,
        String validationError,
        boolean isDefault,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {

    public static UserAIModelConfigResponse fromEntity(UserAIModelConfig entity) {
        if (entity == null) {
            return null;
        }
        return new UserAIModelConfigResponse(
                entity.getId(),
                entity.getUserId(),
                entity.getProvider(),
                entity.getModelName(),
                entity.getAlias(),
                entity.getApiEndpoint(),
                entity.getIsValidated(),
                entity.getValidationError(),
                entity.isDefault(),
                entity.getCreatedAt(),
                entity.getUpdatedAt()
        );
    }
}
