package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.Memo;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 메모(Memo) 리포지토리 인터페이스
 *
 * Spring Data JPA를 활용한 메모 데이터 접근 계층입니다.
 * JpaRepository를 상속받아 기본 CRUD 메서드를 자동으로 제공받으며,
 * 회원별 메모 조회 기능을 제공합니다.
 *
 * 기본 제공 메서드:
 * - save(Memo): 메모 저장/수정
 * - findById(String): ID로 메모 조회
 * - findAll(): 전체 메모 조회
 * - delete(Memo): 메모 삭제
 * - count(): 전체 메모 수
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@Repository  // Spring의 빈으로 등록 (DAO 계층 표시)
public interface MemoRepository extends JpaRepository<Memo, UUID> {

    // ===== 사업장 필터링이 포함된 메서드들 (Member 테이블과 조인) =====

    /**
     * 특정 회원의 모든 메모를 수정일시 내림차순으로 조회 (사업장 필터링 포함)
     *
     * Member 테이블과 조인하여 사업장 권한을 검증합니다.
     * 수정일(updated_at) 기준으로 정렬하며, 가장 최근 수정된 메모가 상단에 표시됩니다.
     *
     * @param memberId 조회할 회원의 ID (UUID)
     * @param businessPlaceId 사업장 ID
     * @return 해당 회원의 모든 메모 목록 (최근 수정순)
     */
    @Query(value = "SELECT m.* FROM memos m JOIN members mem ON m.member_id = mem.id WHERE m.member_id = :memberId AND mem.business_place_id = :businessPlaceId ORDER BY COALESCE(m.updated_at, m.created_at) DESC", nativeQuery = true)
    List<Memo> findByMemberIdAndBusinessPlaceIdOrderByCreatedAtDesc(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId
    );

    /**
     * 특정 회원의 가장 최근 수정된 메모 하나만 조회 (사업장 필터링 포함)
     *
     * Member 테이블과 조인하여 사업장 권한을 검증합니다.
     * 수정일(updated_at) 기준으로 정렬하며, 수정일이 없으면 생성일(created_at)로 판단합니다.
     *
     * @param memberId 조회할 회원의 ID (UUID)
     * @param businessPlaceId 사업장 ID
     * @return 가장 최근 수정된 메모를 담은 Optional 객체 (메모가 없으면 empty)
     */
    @Query(value = "SELECT m.* FROM memos m JOIN members mem ON m.member_id = mem.id WHERE m.member_id = :memberId AND mem.business_place_id = :businessPlaceId ORDER BY COALESCE(m.updated_at, m.created_at) DESC LIMIT 1", nativeQuery = true)
    Optional<Memo> findFirstByMemberIdAndBusinessPlaceIdOrderByCreatedAtDesc(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId
    );

    /**
     * 특정 회원의 메모 수 조회 (사업장 필터링 포함)
     *
     * Member 테이블과 조인하여 사업장 권한을 검증합니다.
     *
     * @param memberId 조회할 회원의 ID (UUID)
     * @param businessPlaceId 사업장 ID
     * @return 해당 회원의 메모 개수
     */
    @Query("SELECT COUNT(m) FROM Memo m JOIN m.member mem WHERE m.memberId = :memberId AND mem.businessPlaceId = :businessPlaceId")
    long countByMemberIdAndBusinessPlaceId(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId
    );

    // ===== 사업장 필터링 없는 기본 메서드들 (내부용, Service에서 권한 체크 후 사용) =====

    /**
     * 특정 회원의 모든 메모를 수정일시 내림차순으로 조회
     * 수정일(updated_at) 기준으로 정렬하며, 수정일이 없으면 생성일(created_at)로 판단합니다.
     * ⚠️ 주의: 이 메서드는 Service 레이어에서 사업장 권한 체크 후에만 사용해야 합니다.
     */
    @Query(value = "SELECT * FROM memos WHERE member_id = :memberId ORDER BY COALESCE(updated_at, created_at) DESC", nativeQuery = true)
    List<Memo> findByMemberIdOrderByCreatedAtDesc(@Param("memberId") UUID memberId);

    /**
     * 특정 회원의 가장 최근 수정된 메모 하나만 조회
     * 수정일(updated_at) 기준으로 정렬하며, 수정일이 없으면 생성일(created_at)로 판단합니다.
     * ⚠️ 주의: 이 메서드는 Service 레이어에서 사업장 권한 체크 후에만 사용해야 합니다.
     */
    @Query(value = "SELECT * FROM memos WHERE member_id = :memberId ORDER BY COALESCE(updated_at, created_at) DESC LIMIT 1", nativeQuery = true)
    Optional<Memo> findFirstByMemberIdOrderByCreatedAtDesc(@Param("memberId") UUID memberId);

    /**
     * 특정 회원의 메모 수 조회
     * ⚠️ 주의: 이 메서드는 Service 레이어에서 사업장 권한 체크 후에만 사용해야 합니다.
     */
    long countByMemberId(UUID memberId);

    /**
     * 특정 회원의 모든 메모를 수정일시 오름차순으로 조회
     * 수정일(updated_at) 기준으로 정렬하며, 수정일이 없으면 생성일(created_at)로 판단합니다.
     * ⚠️ 주의: 이 메서드는 Service 레이어에서 사업장 권한 체크 후에만 사용해야 합니다.
     */
    @Query(value = "SELECT * FROM memos WHERE member_id = :memberId ORDER BY COALESCE(updated_at, created_at) ASC", nativeQuery = true)
    List<Memo> findByMemberIdOrderByCreatedAtAsc(@Param("memberId") UUID memberId);

    // ===== Soft Delete 관련 메서드 (사업장 필터링 포함) =====

    /**
     * 삭제되지 않은 메모 목록 조회 (회원별, 최근 수정순, 사업장 필터링 포함)
     * 수정일(updated_at) 기준으로 정렬하며, 수정일이 없으면 생성일(created_at)로 판단합니다.
     */
    @Query(value = "SELECT m.* FROM memos m JOIN members mem ON m.member_id = mem.id WHERE m.member_id = :memberId AND mem.business_place_id = :businessPlaceId AND m.is_deleted = false ORDER BY COALESCE(m.updated_at, m.created_at) DESC", nativeQuery = true)
    List<Memo> findByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId
    );

    /**
     * 삭제되지 않은 가장 최근 수정된 메모 조회 (회원별, 사업장 필터링 포함)
     * 수정일(updated_at) 기준으로 정렬하며, 수정일이 없으면 생성일(created_at)로 판단합니다.
     */
    @Query(value = "SELECT m.* FROM memos m JOIN members mem ON m.member_id = mem.id WHERE m.member_id = :memberId AND mem.business_place_id = :businessPlaceId AND m.is_deleted = false ORDER BY COALESCE(m.updated_at, m.created_at) DESC LIMIT 1", nativeQuery = true)
    Optional<Memo> findFirstByMemberIdAndBusinessPlaceIdAndIsDeletedFalseOrderByCreatedAtDesc(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId
    );

    /**
     * 삭제되지 않은 메모 수 조회 (회원별, 사업장 필터링 포함)
     */
    @Query("SELECT COUNT(m) FROM Memo m JOIN m.member mem WHERE m.memberId = :memberId AND mem.businessPlaceId = :businessPlaceId AND m.isDeleted = false")
    long countByMemberIdAndBusinessPlaceIdAndIsDeletedFalse(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId
    );

    /**
     * 삭제되지 않은 메모 수 조회 (회원별, 사업장 필터링 포함, 비관적 잠금)
     *
     * Race Condition 방지를 위해 비관적 잠금(FOR UPDATE)을 사용합니다.
     * 메모 생성 시 제한 체크에 사용됩니다.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT COUNT(m) FROM Memo m JOIN m.member mem WHERE m.memberId = :memberId AND mem.businessPlaceId = :businessPlaceId AND m.isDeleted = false")
    long countByMemberIdAndBusinessPlaceIdAndIsDeletedFalseWithLock(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId
    );

    /**
     * 삭제 대기 중인 메모 목록 조회 (회원별, 사업장 필터링 포함)
     */
    @Query("SELECT m FROM Memo m JOIN m.member mem WHERE m.memberId = :memberId AND mem.businessPlaceId = :businessPlaceId AND m.isDeleted = true ORDER BY m.deletedAt DESC")
    List<Memo> findByMemberIdAndBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(
            @Param("memberId") UUID memberId,
            @Param("businessPlaceId") String businessPlaceId
    );

    /**
     * 사용자가 접근 가능한 모든 사업장의 삭제 대기 메모 목록 조회
     *
     * UserBusinessPlace를 통해 사용자가 APPROVED 상태로 접근할 수 있는 사업장의
     * 모든 회원들의 삭제된 메모를 조회합니다.
     *
     * @param userId 사용자 ID
     * @return 삭제 대기 중인 메모 목록 (삭제 시간 내림차순)
     */
    @Query("SELECT m FROM Memo m " +
           "JOIN m.member mem " +
           "JOIN UserBusinessPlace ubp ON ubp.businessPlaceId = mem.businessPlaceId " +
           "WHERE ubp.userId = :userId " +
           "AND ubp.status = com.vocacrm.api.model.AccessStatus.APPROVED " +
           "AND m.isDeleted = true " +
           "ORDER BY m.deletedAt DESC")
    List<Memo> findDeletedMemosByUserId(@Param("userId") UUID userId);

    /**
     * 특정 사업장의 삭제 대기 메모 목록 조회
     *
     * @param businessPlaceId 사업장 ID
     * @return 삭제 대기 중인 메모 목록 (삭제 시간 내림차순)
     */
    @Query("SELECT m FROM Memo m " +
           "JOIN m.member mem " +
           "WHERE mem.businessPlaceId = :businessPlaceId " +
           "AND m.isDeleted = true " +
           "ORDER BY m.deletedAt DESC")
    List<Memo> findDeletedMemosByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);

    // ===== 기존 메서드들 (내부용, Service에서 권한 체크 후 사용) =====

    /**
     * 삭제되지 않은 메모 목록 조회 (회원별, 최근 수정순)
     * 수정일(updated_at) 기준으로 정렬하며, 수정일이 없으면 생성일(created_at)로 판단합니다.
     * ⚠️ 주의: Service 레이어에서 사업장 권한 체크 후에만 사용
     */
    @Query(value = "SELECT * FROM memos WHERE member_id = :memberId AND is_deleted = false ORDER BY COALESCE(updated_at, created_at) DESC", nativeQuery = true)
    List<Memo> findByMemberIdAndIsDeletedFalseOrderByCreatedAtDesc(@Param("memberId") UUID memberId);

    /**
     * 삭제되지 않은 가장 최근 수정된 메모 조회 (회원별)
     * 수정일(updated_at) 기준으로 정렬하며, 수정일이 없으면 생성일(created_at)로 판단합니다.
     * ⚠️ 주의: Service 레이어에서 사업장 권한 체크 후에만 사용
     */
    @Query(value = "SELECT * FROM memos WHERE member_id = :memberId AND is_deleted = false ORDER BY COALESCE(updated_at, created_at) DESC LIMIT 1", nativeQuery = true)
    Optional<Memo> findFirstByMemberIdAndIsDeletedFalseOrderByCreatedAtDesc(@Param("memberId") UUID memberId);

    /**
     * 삭제되지 않은 메모 수 조회 (회원별)
     * ⚠️ 주의: Service 레이어에서 사업장 권한 체크 후에만 사용
     */
    long countByMemberIdAndIsDeletedFalse(UUID memberId);

    /**
     * 삭제되지 않은 메모 목록 조회 (회원별, 수정일 오름차순)
     * 수정일(updated_at) 기준으로 정렬하며, 수정일이 없으면 생성일(created_at)로 판단합니다.
     * ⚠️ 주의: Service 레이어에서 사업장 권한 체크 후에만 사용
     */
    @Query(value = "SELECT * FROM memos WHERE member_id = :memberId AND is_deleted = false ORDER BY COALESCE(updated_at, created_at) ASC", nativeQuery = true)
    List<Memo> findByMemberIdAndIsDeletedFalseOrderByCreatedAtAsc(@Param("memberId") UUID memberId);

    /**
     * 삭제 대기 중인 메모 목록 조회 (회원별)
     * ⚠️ 주의: Service 레이어에서 사업장 권한 체크 후에만 사용
     */
    List<Memo> findByMemberIdAndIsDeletedTrueOrderByDeletedAtDesc(UUID memberId);

    /**
     * 회원의 삭제되지 않은 메모 전체 조회
     * ⚠️ 주의: Service 레이어에서 사업장 권한 체크 후에만 사용
     */
    List<Memo> findByMemberIdAndIsDeletedFalse(UUID memberId);

    // ===== 사용자 참조 정리 (사업장 탈퇴 시 사용) =====

    /**
     * 특정 사업장에서 특정 사용자의 owner_id를 NULL로 설정
     */
    @Modifying
    @Query("UPDATE Memo m SET m.ownerId = null WHERE m.member.businessPlaceId = :businessPlaceId AND m.ownerId = :userId")
    int clearOwnerIdByBusinessPlaceIdAndUserId(@Param("businessPlaceId") String businessPlaceId, @Param("userId") UUID userId);

    /**
     * 특정 사업장에서 특정 사용자의 last_modified_by_id를 NULL로 설정
     */
    @Modifying
    @Query("UPDATE Memo m SET m.lastModifiedById = null WHERE m.member.businessPlaceId = :businessPlaceId AND m.lastModifiedById = :userId")
    int clearLastModifiedByIdByBusinessPlaceIdAndUserId(@Param("businessPlaceId") String businessPlaceId, @Param("userId") UUID userId);

    /**
     * 특정 사업장에서 특정 사용자의 deleted_by를 NULL로 설정
     */
    @Modifying
    @Query("UPDATE Memo m SET m.deletedBy = null WHERE m.member.businessPlaceId = :businessPlaceId AND m.deletedBy = :userId")
    int clearDeletedByByBusinessPlaceIdAndUserId(@Param("businessPlaceId") String businessPlaceId, @Param("userId") UUID userId);

    // ===== 사업장 삭제 관련 메서드 =====

    /**
     * 특정 사업장의 전체 메모 수 조회
     */
    @Query("SELECT COUNT(m) FROM Memo m WHERE m.member.businessPlaceId = :businessPlaceId")
    long countByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);

    /**
     * 특정 회원 ID 목록에 속한 모든 메모 삭제 (Hard Delete)
     */
    @Modifying
    @Query("DELETE FROM Memo m WHERE m.memberId IN :memberIds")
    int deleteAllByMemberIds(@Param("memberIds") List<UUID> memberIds);
}