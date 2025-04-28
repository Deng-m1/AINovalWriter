package com.ainovel.server.common.util;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;

/**
 * 提示词工具类，用于处理提示词模板的格式化和富文本处理
 */
public class PromptUtil {

    private static final Logger log = LoggerFactory.getLogger(PromptUtil.class);

    // 富文本Quill格式处理相关的正则表达式
    private static final Pattern QUILL_HTML_PATTERN = Pattern.compile("<[^>]*>");
    private static final Pattern QUILL_JSON_PATTERN = Pattern.compile("^\\s*\\[\\s*\\{\\s*\"insert\"", Pattern.DOTALL);

    // 默认的占位符格式，支持{变量}和{{变量}}两种格式
    private static final Pattern PLACEHOLDER_PATTERN = Pattern.compile("\\{([^{}]+)\\}|\\{\\{([^{}]+)\\}\\}");

    // Jackson ObjectMapper 实例
    private static final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 处理富文本，将Quill格式或HTML格式转换为纯文本
     *
     * @param content 可能是富文本格式的内容
     * @return 转换后的纯文本
     */
    public static String extractPlainTextFromRichText(String content) {
        if (content == null || content.isEmpty()) {
            return "";
        }

        // 1. 尝试解析为 Quill Delta JSON 数组
        // 增加更宽松的检查，只要是看起来像JSON数组的都尝试解析
        String trimmedContent = content.trim();
        if (trimmedContent.startsWith("[") && trimmedContent.endsWith("]")) { 
            try {
                // 使用 TypeReference 来正确解析泛型列表
                List<Map<String, Object>> deltaOps = objectMapper.readValue(content,
                    new TypeReference<List<Map<String, Object>>>() {});

                StringBuilder textBuilder = new StringBuilder();
                for (Map<String, Object> op : deltaOps) {
                    // 只处理包含 "insert" 键且值为 String 的操作
                    if (op.containsKey("insert") && op.get("insert") instanceof String) {
                        textBuilder.append((String) op.get("insert"));
                    }
                    // 可以根据需要扩展以处理其他类型的 insert (例如 embeds)
                }
                
                // Quill Delta 格式通常在每个操作后加 \n，合并后可能末尾有多余空白符
                String extractedText = textBuilder.toString();
                // 返回前移除末尾的所有空白字符（包括换行符）
                return extractedText.replaceAll("\\s+$", ""); 

            } catch (JsonProcessingException e) {
                // 解析失败，记录日志（使用 trace 级别，因为这可能是正常情况，例如内容是HTML）
                log.trace("将内容解析为Quill Delta JSON失败: {}. 继续尝试其他格式...", e.getMessage());
            } catch (Exception e) {
                // 捕获其他潜在的解析错误
                log.warn("解析内容时发生意外错误: {}. 继续尝试其他格式...", e.getMessage());
            }
        }

        // 2. 如果不是有效的 Quill Delta JSON 或解析失败，检查是否为 HTML
        // （保留原来的HTML处理逻辑）
        if (content.contains("<") && content.contains(">")) {
            log.trace("内容未成功解析为JSON，尝试作为HTML处理。");
            return QUILL_HTML_PATTERN.matcher(content)
                    .replaceAll("")
                    .replace("&nbsp;", " ")
                    .replace("&lt;", "<")
                    .replace("&gt;", ">")
                    .replace("&amp;", "&")
                    .replace("&quot;", "\"")
                    .replace("&#39;", "'") // 处理 ' 符号
                    .trim();
        }

        // 3. 如果既不是可解析的JSON也不是HTML，则假定为纯文本并返回
        log.trace("内容既不是可解析的JSON也不是HTML，将其视为纯文本返回。");
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

    /**
     * 将纯文本转换为 Quill Delta JSON 格式字符串
     *
     * @param plainText 纯文本输入
     * @return Quill Delta JSON 格式的字符串，例如 "[{\"insert\":\"line1\\n\"},{\"insert\":\"line2\\n\"}]"
     */
    public static String convertPlainTextToQuillDelta(String plainText) {
        if (plainText == null || plainText.isEmpty()) {
            // 返回一个表示空内容的有效 JSON 数组 (Quill Delta 格式)
            return "[{\"insert\":\"\n\"}]";
        }

        List<Map<String, String>> deltaOps = new ArrayList<>();
        // 使用正则表达式按行分割，保留末尾空行
        String[] lines = plainText.split("\\r?\\n", -1);

        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            Map<String, String> op = new HashMap<>();
            // Quill Delta 要求每个 insert 操作都以换行符结束
            // 即使是最后一行，也添加换行符，表示段落结束
            op.put("insert", line + "\n"); 
            deltaOps.add(op);
        }

        // 如果原始文本仅包含换行符，上面的循环会产生多个 {"insert":"\n"}，这是正确的。
        // 如果原始文本为空，则在开头处理了。
        // 如果deltaOps为空（理论上不应该发生，除非split有问题），确保返回有效JSON
        if (deltaOps.isEmpty()) {
            log.warn("Quill Delta 操作列表为空，即使输入非空，输入：'{}'", plainText); // 添加日志
            deltaOps.add(Map.of("insert", "\n")); // Fallback
        }

        try {
            // 使用 ObjectMapper 将操作列表序列化为 JSON 字符串
            return objectMapper.writeValueAsString(deltaOps);
        } catch (JsonProcessingException e) {
            log.error("将纯文本转换为JSON富文本格式失败", e);
            // 返回一个表示错误的有效 JSON 数组
            return "[{\"insert\":\"转换内容时出错。\\n\"}]";
        }
    }
} 