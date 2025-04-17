package com.ainovel.server.common.util;

import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * 提示词工具类，用于处理提示词模板的格式化和富文本处理
 */
public class PromptUtil {

    private static final Logger log = LoggerFactory.getLogger(PromptUtil.class);

    // 富文本Quill格式处理相关的正则表达式
    private static final Pattern QUILL_HTML_PATTERN = Pattern.compile("<[^>]*>");
    private static final Pattern QUILL_JSON_PATTERN = Pattern.compile("\\{\"ops\":.+\\}");

    // 默认的占位符格式，支持{变量}和{{变量}}两种格式
    private static final Pattern PLACEHOLDER_PATTERN = Pattern.compile("\\{([^{}]+)\\}|\\{\\{([^{}]+)\\}\\}");

    /**
     * 处理富文本，将Quill格式转换为纯文本
     *
     * @param content 可能是富文本格式的内容
     * @return 转换后的纯文本
     */
    public static String extractPlainTextFromRichText(String content) {
        if (content == null || content.isEmpty()) {
            return "";
        }

        // 判断是否是Quill JSON格式
        if (QUILL_JSON_PATTERN.matcher(content).matches()) {
            try {
                // 这里可以进一步解析JSON格式，提取文本内容
                // 简单实现：移除所有JSON结构，只保留纯文本
                return content.replaceAll("\\{\"ops\":|\\}|\\[|\\]|\"insert\":|\"attributes\":.+?\\}|,", " ").trim();
            } catch (Exception e) {
                log.error("解析Quill JSON格式失败: {}", e.getMessage());
            }
        }

        // 如果是HTML格式，移除所有HTML标签
        if (content.contains("<") && content.contains(">")) {
            return QUILL_HTML_PATTERN.matcher(content)
                    .replaceAll("")
                    .replace("&nbsp;", " ")
                    .replace("&lt;", "<")
                    .replace("&gt;", ">")
                    .replace("&amp;", "&")
                    .replace("&quot;", "\"")
                    .trim();
        }

        // 默认返回原内容
        return content;
    }

    /**
     * 格式化提示词模板，根据变量映射替换占位符
     * 支持{变量}和{{变量}}两种占位符格式
     *
     * @param template 提示词模板
     * @param variables 变量映射
     * @return 格式化后的提示词
     */
    public static String formatPromptTemplate(String template, Map<String, String> variables) {
        if (template == null || template.isEmpty()) {
            return "";
        }

        // 提取纯文本，移除富文本格式
        String plainTemplate = extractPlainTextFromRichText(template);
        
        // 检测是否存在任何占位符
        if (!containsPlaceholder(plainTemplate)) {
            // 如果没有占位符但有变量，自动添加变量附加到模板末尾
            if (variables != null && !variables.isEmpty()) {
                StringBuilder builder = new StringBuilder(plainTemplate);
                builder.append("\n\n");
                
                for (Map.Entry<String, String> entry : variables.entrySet()) {
                    // 避免添加空值
                    if (entry.getValue() != null && !entry.getValue().isEmpty()) {
                        builder.append(entry.getKey()).append(": ").append(entry.getValue()).append("\n");
                    }
                }
                
                return builder.toString();
            }
            return plainTemplate;
        }
        
        // 替换所有占位符
        StringBuilder result = new StringBuilder();
        Matcher matcher = PLACEHOLDER_PATTERN.matcher(plainTemplate);
        
        int lastEnd = 0;
        while (matcher.find()) {
            // 添加匹配前的文本
            result.append(plainTemplate, lastEnd, matcher.start());
            
            // 获取占位符名称（支持两种格式）
            String placeholder = matcher.group(1) != null ? matcher.group(1) : matcher.group(2);
            
            // 替换占位符
            if (variables != null && variables.containsKey(placeholder)) {
                result.append(variables.get(placeholder));
            } else {
                // 保留未匹配的占位符
                result.append(matcher.group());
                log.warn("找不到占位符对应的变量: {}", placeholder);
            }
            
            lastEnd = matcher.end();
        }
        
        // 添加剩余文本
        if (lastEnd < plainTemplate.length()) {
            result.append(plainTemplate.substring(lastEnd));
        }
        
        return result.toString();
    }
    
    /**
     * 检测字符串中是否包含占位符
     *
     * @param text 要检查的文本
     * @return 是否包含占位符
     */
    public static boolean containsPlaceholder(String text) {
        if (text == null || text.isEmpty()) {
            return false;
        }
        return PLACEHOLDER_PATTERN.matcher(text).find();
    }
    
    /**
     * 获取模板中的所有占位符
     *
     * @param template 提示词模板
     * @return 占位符列表
     */
    public static Map<String, String> extractPlaceholders(String template) {
        Map<String, String> placeholders = new HashMap<>();
        
        if (template == null || template.isEmpty()) {
            return placeholders;
        }
        
        // 提取纯文本，移除富文本格式
        String plainTemplate = extractPlainTextFromRichText(template);
        
        // 查找所有占位符
        Matcher matcher = PLACEHOLDER_PATTERN.matcher(plainTemplate);
        while (matcher.find()) {
            String placeholder = matcher.group(1) != null ? matcher.group(1) : matcher.group(2);
            placeholders.put(placeholder, "");
        }
        
        return placeholders;
    }
} 