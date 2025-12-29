package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.UserBusinessPlace;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserBusinessPlaceRepository extends JpaRepository<UserBusinessPlace, UUID> {
    List<UserBusinessPlace> findByUserIdAndStatus(UUID userId, AccessStatus status);

    List<UserBusinessPlace> findByUserId(UUID userId);

    List<UserBusinessPlace> findByBusinessPlaceIdAndStatus(String businessPlaceId, AccessStatus status);

    Optional<UserBusinessPlace> findByUserIdAndBusinessPlaceId(UUID userId, String businessPlaceId);

    Optional<UserBusinessPlace> findByUserIdAndBusinessPlaceIdAndStatus(UUID userId, String businessPlaceId, AccessStatus status);

    long countByUserIdAndRoleAndStatus(UUID userId, Role role, AccessStatus status);

    long countByBusinessPlaceIdAndStatus(String businessPlaceId, AccessStatus status);

    boolean existsByUserIdAndBusinessPlaceIdAndStatus(UUID userId, String businessPlaceId, AccessStatus status);

    // ===== 사업장 삭제 관련 메서드 =====

    /**
     * 특정 사업장의 직원 수 조회 (Owner 제외)
     */
    @Query("SELECT COUNT(ubp) FROM UserBusinessPlace ubp WHERE ubp.businessPlaceId = :businessPlaceId AND ubp.role != 'OWNER' AND ubp.status = 'APPROVED'")
    long countStaffByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);

    /**
     * 특정 사업장의 모든 UserBusinessPlace 삭제
     */
    @Modifying
    @Query("DELETE FROM UserBusinessPlace ubp WHERE ubp.businessPlaceId = :businessPlaceId")
    int deleteAllByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);

    /**
     * 특정 사업장의 STAFF 사용자 ID 목록 조회
     */
    @Query("SELECT ubp.userId FROM UserBusinessPlace ubp " +
           "WHERE ubp.businessPlaceId = :businessPlaceId " +
           "AND ubp.role = 'STAFF' " +
           "AND ubp.status = 'APPROVED'")
    List<UUID> findStaffUserIdsByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);
}
