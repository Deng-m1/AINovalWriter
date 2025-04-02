package com.ainovel.server.service.rag;

import dev.langchain4j.service.SystemMessage;
import dev.langchain4j.service.UserMessage;
import dev.langchain4j.service.V;

/**
 * 小说RAG助手接口 使用检索增强生成来支持小说创作
 */
public interface NovelRagAssistant {

    /**
     * 使用检索到的相关上下文回答用户问题
     *
     * @param userQuery 用户查询
     * @param relevantContext 相关上下文
     * @return 回答
     */
    @SystemMessage("你是一位AI小说创作助手，基于以下信息回答用户的问题或完成小说内容：\n\n{{information}}")
    String chatWithRagContext(@UserMessage String userQuery, @V("information") String relevantContext);

    /**
     * 使用检索到的相关上下文和指定的角色生成对话或台词
     *
     * @param userQuery 用户查询
     * @param relevantContext 相关上下文
     * @param characterInfo 角色信息
     * @return 生成的对话
     */
    @SystemMessage("你是一位AI对话生成助手，需要以{{character}}的身份说话。基于以下信息生成对话或台词：\n\n{{information}}")
    String generateDialogueWithRagContext(
            @UserMessage String userQuery,
            @V("information") String relevantContext,
            @V("character") String characterInfo);

    /**
     * 使用检索到的相关上下文完善或修改文本
     *
     * @param userQuery 用户查询
     * @param originalText 原始文本
     * @param relevantContext 相关上下文
     * @return 修改后的文本
     */
    @SystemMessage("你是一位AI写作助手，需要修改或完善文本。请基于以下信息：\n\n原始文本：{{originalText}}\n\n相关上下文信息：\n{{information}}")
    String reviseTextWithRagContext(
            @UserMessage String userQuery,
            @V("originalText") String originalText,
            @V("information") String relevantContext);

    /**
     * 使用检索到的相关上下文生成下一场景大纲
     *
     * @param userQuery 用户查询
     * @param relevantContext 相关上下文
     * @return 场景大纲
     */
    @SystemMessage("你是一位AI情节设计助手，需要提供下一个场景的大纲。基于以下信息生成合理的场景大纲：\n\n{{information}}")
    String generateNextSceneWithRagContext(
            @UserMessage String userQuery,
            @V("information") String relevantContext);
}
