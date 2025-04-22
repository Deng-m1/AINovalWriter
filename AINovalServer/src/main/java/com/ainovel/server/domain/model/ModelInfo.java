package com.ainovel.server.domain.model;

import java.util.HashMap;
import java.util.Map;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * AI模型信息封装类
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ModelInfo {
    
    /**
     * 模型ID
     */
    private String id;
    
    /**
     * 模型名称
     */
    private String name;
    
    /**
     * 模型描述
     */
    private String description;
    
    /**
     * 模型所属提供商
     */
    private String provider;
    
    /**
     * 模型最大上下文长度（token数）
     */
    private Integer maxTokens;
    
    /**
     * 模型是否支持流式输出
     */
    private Boolean supportsStreaming;
    
    /**
     * 模型价格信息（每1000个token的美元价格）
     */
    @Builder.Default
    private Map<String, Double> pricing = new HashMap<>();
    
    /**
     * 模型额外属性
     */
    @Builder.Default
    private Map<String, Object> properties = new HashMap<>();
    
    /**
     * 创建一个基本的模型信息对象
     * 
     * @param id 模型ID
     * @param name 模型名称
     * @param provider 提供商名称
     * @return 模型信息对象
     */
    public static ModelInfo basic(String id, String name, String provider) {
        return ModelInfo.builder()
                .id(id)
                .name(name)
                .provider(provider)
                .supportsStreaming(true)
                .build();
    }
    
    /**
     * 添加输入价格
     * 
     * @param pricePerThousandTokens 每1000个输入token的美元价格
     * @return 当前对象（链式调用）
     */
    public ModelInfo withInputPrice(double pricePerThousandTokens) {
        this.pricing.put("input", pricePerThousandTokens);
        return this;
    }
    
    /**
     * 添加输出价格
     * 
     * @param pricePerThousandTokens 每1000个输出token的美元价格
     * @return 当前对象（链式调用）
     */
    public ModelInfo withOutputPrice(double pricePerThousandTokens) {
        this.pricing.put("output", pricePerThousandTokens);
        return this;
    }
    
    /**
     * 添加统一价格（输入和输出使用相同价格）
     * 
     * @param pricePerThousandTokens 每1000个token的美元价格
     * @return 当前对象（链式调用）
     */
    public ModelInfo withUnifiedPrice(double pricePerThousandTokens) {
        this.pricing.put("unified", pricePerThousandTokens);
        return this;
    }
    
    /**
     * 添加最大token数
     * 
     * @param maxTokens 最大token数
     * @return 当前对象（链式调用）
     */
    public ModelInfo withMaxTokens(int maxTokens) {
        this.maxTokens = maxTokens;
        return this;
    }
    
    /**
     * 添加描述
     * 
     * @param description 描述
     * @return 当前对象（链式调用）
     */
    public ModelInfo withDescription(String description) {
        this.description = description;
        return this;
    }
    
    /**
     * 添加额外属性
     * 
     * @param key 属性键
     * @param value 属性值
     * @return 当前对象（链式调用）
     */
    public ModelInfo withProperty(String key, Object value) {
        this.properties.put(key, value);
        return this;
    }
}
