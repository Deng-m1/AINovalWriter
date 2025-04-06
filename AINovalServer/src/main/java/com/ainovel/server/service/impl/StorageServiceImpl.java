package com.ainovel.server.service.impl;

import java.util.Map;
import java.util.UUID;

import org.apache.commons.lang3.StringUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Service;

import com.ainovel.server.config.StorageConfig.StorageProperties;
import com.ainovel.server.service.StorageService;
import com.ainovel.server.service.provider.StorageProvider;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * 存储服务实现类
 */
@Slf4j
@Service
@Primary
public class StorageServiceImpl implements StorageService {
    
    private final StorageProvider storageProvider;
    private final StorageProperties storageProperties;
    
    @Autowired
    public StorageServiceImpl(
            @Qualifier("aliOSSStorageProvider") StorageProvider storageProvider,
            StorageProperties storageProperties) {
        this.storageProvider = storageProvider;
        this.storageProperties = storageProperties;
    }
    
    @Override
    public Mono<Map<String, String>> getCoverUploadCredential(String novelId, String fileName, String contentType) {
        String key = generateCoverKey(novelId, fileName);
        log.info("获取封面上传凭证: novelId={}, fileName={}, key={}", novelId, fileName, key);
        
        return storageProvider.generateUploadCredential(key, contentType, 3600); // 有效期1小时
    }
    
    @Override
    public Mono<String> getCoverUrl(String coverKey, long expiration) {
        if (StringUtils.isBlank(coverKey)) {
            return Mono.just("");
        }
        
        log.info("获取封面URL: key={}, expiration={}", coverKey, expiration);
        return storageProvider.getFileUrl(coverKey, expiration);
    }
    
    @Override
    public String generateCoverKey(String novelId, String fileName) {
        String safeFileName = sanitizeFileName(fileName);
        
        // 在文件名中添加随机UUID避免文件名冲突
        String uniqueId = UUID.randomUUID().toString().substring(0, 8);
        String extension = "";
        int dotIndex = safeFileName.lastIndexOf('.');
        if (dotIndex > 0) {
            extension = safeFileName.substring(dotIndex);
            safeFileName = safeFileName.substring(0, dotIndex);
        }
        
        // 构建最终的文件路径，使用配置的covers路径
        String coversPath = storageProperties.getCoversPath();
        return String.format("%s/%s/%s-%s%s", coversPath, novelId, safeFileName, uniqueId, extension);
    }
    
    @Override
    public Mono<Boolean> deleteCover(String coverKey) {
        if (StringUtils.isBlank(coverKey)) {
            return Mono.just(false);
        }
        
        log.info("删除封面文件: key={}", coverKey);
        return storageProvider.deleteFile(coverKey);
    }
    
    @Override
    public Mono<Boolean> doesCoverExist(String coverKey) {
        if (StringUtils.isBlank(coverKey)) {
            return Mono.just(false);
        }
        
        log.info("检查封面是否存在: key={}", coverKey);
        return storageProvider.doesFileExist(coverKey);
    }
    
    /**
     * 清理文件名，移除不安全字符
     */
    private String sanitizeFileName(String fileName) {
        if (StringUtils.isBlank(fileName)) {
            return "unnamed";
        }
        
        // 去除路径分隔符和其他不安全字符
        return fileName.replaceAll("[\\\\/:*?\"<>|]", "_");
    }
}
