package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.BusinessPlaceAccessRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 사업장 접근 요청 리포지토리
 *
 * 사업장 접근 요청 이력을 관리하는 데이터 접근 계층
 */
@Repository
public interface BusinessPlaceAccessRequestRepository extends JpaRepository<BusinessPlaceAccessRequest, UUID> {

    /**
     * 특정 사용자의 모든 요청 조회 (최신순)
     */
    List<BusinessPlaceAccessRequest> findByUserIdOrderByRequestedAtDesc(UUID userId);

    /**
     * 특정 사용자의 특정 상태 요청 조회
     */
    List<BusinessPlaceAccessRequest> findByUserIdAndStatusOrderByRequestedAtDesc(UUID userId, AccessStatus status);

    /**
     * 특정 사용자가 특정 사업장에 보낸 요청 조회
     */
    Optional<BusinessPlaceAccessRequest> findByUserIdAndBusinessPlaceIdAndStatus(
            UUID userId, String businessPlaceId, AccessStatus status);

    /**
     * 특정 사업장에 대한 모든 요청 조회 (최신순)
     */
    List<BusinessPlaceAccessRequest> findByBusinessPlaceIdOrderByRequestedAtDesc(String businessPlaceId);

    /**
     * 특정 사업장의 특정 상태 요청 조회
     */
    List<BusinessPlaceAccessRequest> findByBusinessPlaceIdAndStatusOrderByRequestedAtDesc(
            String businessPlaceId, AccessStatus status);

    /**
     * 특정 사업장들에 대한 PENDING 요청 조회 (owner가 받은 요청 조회용)
     */
    @Query("SELECT r FROM BusinessPlaceAccessRequest r WHERE r.businessPlaceId IN :businessPlaceIds AND r.status = :status ORDER BY r.requestedAt DESC")
    List<BusinessPlaceAccessRequest> findByBusinessPlaceIdsAndStatus(
            @Param("businessPlaceIds") List<String> businessPlaceIds,
            @Param("status") AccessStatus status);

    /**
     * 특정 사용자가 처리한 요청 조회
     */
    List<BusinessPlaceAccessRequest> findByProcessedByOrderByProcessedAtDesc(UUID processedBy);

    /**
     * 사용자의 미확인 처리 결과 조회
     */
    List<BusinessPlaceAccessRequest> findByUserIdAndIsReadByRequesterFalseAndStatusInOrderByProcessedAtDesc(
            UUID userId, List<AccessStatus> statuses);

    /**
     * 중복 요청 체크용 (이미 PENDING 상태인 요청이 있는지 확인)
     */
    boolean existsByUserIdAndBusinessPlaceIdAndStatus(UUID userId, String businessPlaceId, AccessStatus status);

    /**
     * 사용자가 보낸 모든 요청 삭제 (회원 탈퇴 시 사용)
     */
    void deleteByUserId(UUID userId);

    // ===== 사업장 삭제 관련 메서드 =====

    /**
     * 특정 사업장에 대한 접근 요청 수 조회
     */
    long countByBusinessPlaceId(String businessPlaceId);

    /**
     * 특정 사업장에 대한 모든 접근 요청 삭제
     */
    @Modifying
    @Query("DELETE FROM BusinessPlaceAccessRequest r WHERE r.businessPlaceId = :businessPlaceId")
    int deleteAllByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);
}
