package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.Visit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * 방문(Visit) 리포지토리 인터페이스
 *
 * Visit 테이블은 businessPlaceId를 직접 가지고 있지 않으므로,
 * Member 테이블과 JOIN하여 사업장 권한을 검증합니다.
 */
@Repository
public interface VisitRepository extends JpaRepository<Visit, UUID> {

    // ===== 사업장 필터링이 포함된 메서드들 (Member 테이블과 조인) =====

    /**
     * 특정 회원의 모든 방문 기록 조회 (사업장 필터링 포함)
     *
     * Member 테이블과 조인하여 사업장 권한을 검증합니다.
     *
     * @param memberId 조회할 회원의 ID (UUID)
     * @param businessPlaceId 사업장 ID
     * @return 해당 회원의 모든 방문 기록 목록 (최신순)
     */
    @Query("SELECT v FROM Visit v JOIN Member m ON v.memberId = m.id " +
           "WHERE v.memberId = :memberId AND m.businessPlaceId = :businessPlaceId " +
           "ORDER BY v.visitedAt DESC")
    List<Visit> findByMemberIdAndBusinessPlaceIdOrderByVisitedAtDesc(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId
    );

    // REMOVED: findByMemberIdOrderByVisitedAtDesc() - 사업장 필터링 필수

    // ===== 사용자 참조 정리 (사업장 탈퇴 시 사용) =====

    /**
     * 특정 사업장에서 특정 사용자의 visitor_id를 NULL로 설정
     *
     * Visit 테이블은 businessPlaceId를 직접 가지고 있지 않으므로
     * Member 테이블과 JOIN하여 사업장을 필터링합니다.
     */
    @Modifying
    @Query("UPDATE Visit v SET v.visitorId = null WHERE v.memberId IN " +
           "(SELECT m.id FROM Member m WHERE m.businessPlaceId = :businessPlaceId) " +
           "AND v.visitorId = :userId")
    int clearVisitorIdByBusinessPlaceIdAndUserId(@Param("businessPlaceId") String businessPlaceId, @Param("userId") UUID userId);

    // ===== 오늘 방문 조회 =====

    /**
     * 특정 사업장의 오늘 방문 기록 조회 (회원 정보 포함)
     */
    @Query("SELECT v FROM Visit v JOIN FETCH v.member m " +
           "WHERE m.businessPlaceId = :businessPlaceId " +
           "AND CAST(v.visitedAt AS date) = CURRENT_DATE " +
           "ORDER BY v.visitedAt DESC")
    List<Visit> findTodayVisitsByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);

    // ===== 체크인 취소 (삭제) =====

    /**
     * 특정 방문 기록 조회 (사업장 필터링 포함)
     */
    @Query("SELECT v FROM Visit v JOIN v.member m " +
           "WHERE v.id = :visitId AND m.businessPlaceId = :businessPlaceId")
    java.util.Optional<Visit> findByIdAndBusinessPlaceId(
            @Param("visitId") UUID visitId,
            @Param("businessPlaceId") String businessPlaceId);

    // ===== 사업장 삭제 관련 메서드 =====

    /**
     * 특정 사업장의 전체 방문 기록 수 조회
     */
    @Query("SELECT COUNT(v) FROM Visit v WHERE v.memberId IN " +
           "(SELECT m.id FROM Member m WHERE m.businessPlaceId = :businessPlaceId)")
    long countByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);

    /**
     * 특정 회원 ID 목록에 속한 모든 방문 기록 삭제 (Hard Delete)
     */
    @Modifying
    @Query("DELETE FROM Visit v WHERE v.memberId IN :memberIds")
    int deleteAllByMemberIds(@Param("memberIds") List<UUID> memberIds);
}
