package com.ainovel.server.web.controller;

import java.security.Principal;
import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.ainovel.server.domain.model.NovelSettingItem;
import com.ainovel.server.domain.model.NovelSettingItem.SettingRelationship;
import com.ainovel.server.domain.model.SettingGroup;
import com.ainovel.server.service.NovelSettingService;
import com.ainovel.server.web.dto.SettingSearchRequest;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说设定控制器
 * 处理小说设定相关的API请求
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/novels/{novelId}/settings")
public class NovelSettingController {

    private final NovelSettingService novelSettingService;

    @Autowired
    public NovelSettingController(NovelSettingService novelSettingService) {
        this.novelSettingService = novelSettingService;
    }

    // ==================== 设定条目管理 ====================

    /**
     * 创建小说设定条目
     */
    @PostMapping("/items")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<NovelSettingItem> createSettingItem(
            @PathVariable String novelId,
            @RequestBody NovelSettingItem settingItem,
            Principal principal) {

        // 设置关联的小说ID和用户ID
        settingItem.setNovelId(novelId);
        settingItem.setUserId(principal.getName());

        return novelSettingService.createSettingItem(settingItem)
                .doOnSuccess(item -> log.info("用户 {} 为小说 {} 创建了设定项: {}", 
                        principal.getName(), novelId, item.getName()));
    }

    /**
     * 获取小说设定条目列表
     */
    @GetMapping("/items")
    public Flux<NovelSettingItem> getNovelSettingItems(
            @PathVariable String novelId,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String name,
            @RequestParam(required = false) Integer priority,
            @RequestParam(required = false) String generatedBy,
            @RequestParam(required = false) String status,
            @RequestParam(required = false, defaultValue = "0") int page,
            @RequestParam(required = false, defaultValue = "20") int size,
            @RequestParam(required = false, defaultValue = "priority") String sortBy,
            @RequestParam(required = false, defaultValue = "desc") String sortDirection,
            Principal principal) {

        Sort.Direction direction = "asc".equalsIgnoreCase(sortDirection) ? 
                Sort.Direction.ASC : Sort.Direction.DESC;
        Pageable pageable = PageRequest.of(page, size, Sort.by(direction, sortBy));

        return novelSettingService.getNovelSettingItems(
                novelId, type, name, priority, generatedBy, status, pageable);
    }

    /**
     * 获取小说设定条目详情
     */
    @GetMapping("/items/{itemId}")
    public Mono<NovelSettingItem> getSettingItemDetail(
            @PathVariable String novelId,
            @PathVariable String itemId,
            Principal principal) {

        return novelSettingService.getSettingItemById(itemId)
                .filter(item -> item.getNovelId().equals(novelId))
                .switchIfEmpty(Mono.error(new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "设定条目不存在或不属于该小说")));
    }

    /**
     * 更新小说设定条目
     */
    @PutMapping("/items/{itemId}")
    public Mono<NovelSettingItem> updateSettingItem(
            @PathVariable String novelId,
            @PathVariable String itemId,
            @RequestBody NovelSettingItem settingItem,
            Principal principal) {

        if (!novelId.equals(settingItem.getNovelId())) {
            return Mono.error(new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "设定条目的novelId与路径参数不匹配"));
        }

        settingItem.setId(itemId);
        return novelSettingService.updateSettingItem(itemId, settingItem)
                .doOnSuccess(item -> log.info("用户 {} 更新了小说 {} 的设定项: {}", 
                        principal.getName(), novelId, item.getName()));
    }

    /**
     * 删除小说设定条目
     */
    @DeleteMapping("/items/{itemId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteSettingItem(
            @PathVariable String novelId,
            @PathVariable String itemId,
            Principal principal) {

        return novelSettingService.getSettingItemById(itemId)
                .filter(item -> item.getNovelId().equals(novelId))
                .switchIfEmpty(Mono.error(new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "设定条目不存在或不属于该小说")))
                .flatMap(item -> novelSettingService.deleteSettingItem(itemId))
                .doOnSuccess(v -> log.info("用户 {} 删除了小说 {} 的设定项 {}", 
                        principal.getName(), novelId, itemId));
    }

    /**
     * 添加设定条目之间的关系
     */
    @PostMapping("/items/{itemId}/relationships/{targetItemId}")
    public Mono<NovelSettingItem> addSettingRelationship(
            @PathVariable String novelId,
            @PathVariable String itemId,
            @PathVariable String targetItemId,
            @RequestParam String relationshipType,
            @RequestParam(required = false) String description,
            Principal principal) {

        // 创建关系对象
        SettingRelationship relationship = SettingRelationship.builder()
                .targetItemId(targetItemId)
                .type(relationshipType)
                .description(description)
                .build();

        return novelSettingService.addSettingRelationship(itemId, relationship)
                .doOnSuccess(item -> log.info("用户 {} 为小说 {} 的设定项 {} 添加了关系: {} -> {}", 
                        principal.getName(), novelId, item.getName(), relationshipType, targetItemId));
    }

    /**
     * 删除设定条目之间的关系
     */
    @DeleteMapping("/items/{itemId}/relationships/{targetItemId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> removeSettingRelationship(
            @PathVariable String novelId,
            @PathVariable String itemId,
            @PathVariable String targetItemId,
            @RequestParam(required = false) String relationshipType,
            Principal principal) {

        return novelSettingService.removeSettingRelationship(itemId, targetItemId, relationshipType)
                .doOnSuccess(v -> log.info("用户 {} 删除了小说 {} 的设定项关系: {} -> {}", 
                        principal.getName(), novelId, itemId, targetItemId));
    }

    // ==================== 设定组管理 ====================

    /**
     * 创建设定组
     */
    @PostMapping("/groups")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<SettingGroup> createSettingGroup(
            @PathVariable String novelId,
            @RequestBody SettingGroup settingGroup,
            Principal principal) {

        settingGroup.setNovelId(novelId);
        settingGroup.setUserId(principal.getName());

        return novelSettingService.createSettingGroup(settingGroup)
                .doOnSuccess(group -> log.info("用户 {} 为小说 {} 创建了设定组: {}", 
                        principal.getName(), novelId, group.getName()));
    }

    /**
     * 获取小说的设定组列表
     */
    @GetMapping("/groups")
    public Flux<SettingGroup> getNovelSettingGroups(
            @PathVariable String novelId,
            @RequestParam(required = false) String name,
            @RequestParam(required = false) Boolean isActiveContext,
            Principal principal) {

        return novelSettingService.getNovelSettingGroups(novelId, name, isActiveContext);
    }

    /**
     * 获取设定组详情
     */
    @GetMapping("/groups/{groupId}")
    public Mono<SettingGroup> getSettingGroupDetail(
            @PathVariable String novelId,
            @PathVariable String groupId,
            Principal principal) {

        return novelSettingService.getSettingGroupById(groupId)
                .filter(group -> group.getNovelId().equals(novelId))
                .switchIfEmpty(Mono.error(new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "设定组不存在或不属于该小说")));
    }

    /**
     * 更新设定组
     */
    @PutMapping("/groups/{groupId}")
    public Mono<SettingGroup> updateSettingGroup(
            @PathVariable String novelId,
            @PathVariable String groupId,
            @RequestBody SettingGroup settingGroup,
            Principal principal) {

        if (!novelId.equals(settingGroup.getNovelId())) {
            return Mono.error(new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "设定组的novelId与路径参数不匹配"));
        }

        settingGroup.setId(groupId);
        return novelSettingService.updateSettingGroup(groupId, settingGroup)
                .doOnSuccess(group -> log.info("用户 {} 更新了小说 {} 的设定组: {}", 
                        principal.getName(), novelId, group.getName()));
    }

    /**
     * 删除设定组
     */
    @DeleteMapping("/groups/{groupId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteSettingGroup(
            @PathVariable String novelId,
            @PathVariable String groupId,
            Principal principal) {

        return novelSettingService.getSettingGroupById(groupId)
                .filter(group -> group.getNovelId().equals(novelId))
                .switchIfEmpty(Mono.error(new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "设定组不存在或不属于该小说")))
                .flatMap(group -> novelSettingService.deleteSettingGroup(groupId))
                .doOnSuccess(v -> log.info("用户 {} 删除了小说 {} 的设定组 {}", 
                        principal.getName(), novelId, groupId));
    }

    /**
     * 添加设定条目到设定组
     */
    @PostMapping("/groups/{groupId}/items/{itemId}")
    public Mono<SettingGroup> addItemToGroup(
            @PathVariable String novelId,
            @PathVariable String groupId,
            @PathVariable String itemId,
            Principal principal) {

        return novelSettingService.addItemToGroup(groupId, itemId)
                .doOnSuccess(group -> log.info("用户 {} 将设定项 {} 添加到设定组 {}", 
                        principal.getName(), itemId, groupId));
    }

    /**
     * 从设定组中移除设定条目
     */
    @DeleteMapping("/groups/{groupId}/items/{itemId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> removeItemFromGroup(
            @PathVariable String novelId,
            @PathVariable String groupId,
            @PathVariable String itemId,
            Principal principal) {

        return novelSettingService.removeItemFromGroup(groupId, itemId)
                .doOnSuccess(v -> log.info("用户 {} 从设定组 {} 移除了设定项 {}", 
                        principal.getName(), groupId, itemId));
    }

    /**
     * 激活/停用设定组作为上下文
     */
    @PutMapping("/groups/{groupId}/active-context")
    public Mono<SettingGroup> setActiveContext(
            @PathVariable String novelId,
            @PathVariable String groupId,
            @RequestParam boolean isActive,
            Principal principal) {

        return novelSettingService.setGroupActiveContext(groupId, isActive)
                .doOnSuccess(group -> log.info("用户 {} 将设定组 {} 的激活状态设置为: {}", 
                        principal.getName(), groupId, isActive));
    }

    // ==================== 高级功能 ====================

    /**
     * 从文本中自动提取设定条目
     */
    @PostMapping("/extract")
    public Flux<NovelSettingItem> extractSettingsFromText(
            @PathVariable String novelId,
            @RequestBody String text,
            @RequestParam(required = false, defaultValue = "auto") String type,
            Principal principal) {

        return novelSettingService.extractSettingsFromText(novelId, text, type, principal.getName())
                .doOnComplete(() -> log.info("用户 {} 从文本中为小说 {} 提取了设定条目", 
                        principal.getName(), novelId));
    }

    /**
     * 根据关键词搜索设定条目
     */
    @PostMapping("/search")
    public Flux<NovelSettingItem> searchSettingItems(
            @PathVariable String novelId,
            @RequestBody SettingSearchRequest searchRequest,
            Principal principal) {

        return novelSettingService.searchSettingItems(
                novelId, 
                searchRequest.getQuery(),
                searchRequest.getTypes(), 
                searchRequest.getGroupIds(),
                searchRequest.getMinScore(),
                searchRequest.getMaxResults())
                .doOnComplete(() -> log.info("用户 {} 搜索小说 {} 的设定条目，关键词: {}", 
                        principal.getName(), novelId, searchRequest.getQuery()));
    }
} 