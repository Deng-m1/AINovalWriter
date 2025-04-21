package com.ainovel.server.repository.impl;

import com.ainovel.server.domain.model.NextOutline;
import com.ainovel.server.repository.NextOutlineRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 剧情大纲仓库MongoDB实现
 */
@Repository
public class NextOutlineRepositoryImpl implements NextOutlineRepository {

    private final ReactiveMongoTemplate mongoTemplate;

    @Autowired
    public NextOutlineRepositoryImpl(ReactiveMongoTemplate mongoTemplate) {
        this.mongoTemplate = mongoTemplate;
    }

    @Override
    public Mono<NextOutline> save(NextOutline outline) {
        return mongoTemplate.save(outline);
    }

    @Override
    public Mono<NextOutline> findById(String id) {
        return mongoTemplate.findById(id, NextOutline.class);
    }

    @Override
    public Flux<NextOutline> findByNovelId(String novelId) {
        Query query = Query.query(Criteria.where("novelId").is(novelId));
        return mongoTemplate.find(query, NextOutline.class);
    }

    @Override
    public Flux<NextOutline> findByNovelIdAndSelected(String novelId, boolean selected) {
        Query query = Query.query(
                Criteria.where("novelId").is(novelId)
                        .and("selected").is(selected)
        );
        return mongoTemplate.find(query, NextOutline.class);
    }

    @Override
    public Flux<NextOutline> findAll() {
        return mongoTemplate.findAll(NextOutline.class);
    }

    @Override
    public Mono<Void> deleteById(String id) {
        return mongoTemplate.remove(Query.query(Criteria.where("id").is(id)), NextOutline.class).then();
    }

    @Override
    public Mono<Void> deleteAll() {
        return mongoTemplate.remove(new Query(), NextOutline.class).then();
    }
}
