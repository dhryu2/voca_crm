package com.vocacrm.api.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import com.vocacrm.api.model.Member;

@Repository
public interface StatisticsRepository extends JpaRepository<Member, UUID> {

    @Query(value = "SELECT get_today_visit_count(:businessPlaceId)", nativeQuery = true)
    Integer getTodayVisitCount(@Param("businessPlaceId") String businessPlaceId);

    @Query(value = "SELECT get_pending_memos_count(:businessPlaceId)", nativeQuery = true)
    Integer getPendingMemosCount(@Param("businessPlaceId") String businessPlaceId);

    @Query(value = "SELECT COUNT(DISTINCT m.id) FROM members m WHERE m.business_place_id = :businessPlaceId", nativeQuery = true)
    Integer getTotalMembersCount(@Param("businessPlaceId") String businessPlaceId);
}
