package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.Member;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * 회원(Member) 리포지토리 인터페이스
 *
 * Spring Data JPA를 활용한 회원 데이터 접근 계층입니다.
 * JpaRepository를 상속받아 기본 CRUD 메서드를 자동으로 제공받으며,
 * 추가적인 쿼리 메서드를 정의하여 다양한 검색 기능을 제공합니다.
 *
 * 기본 제공 메서드:
 * - save(Member): 회원 저장/수정
 * - findById(String): ID로 회원 조회
 * - findAll(): 전체 회원 조회
 * - delete(Member): 회원 삭제
 * - count(): 전체 회원 수
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@Repository  // Spring의 빈으로 등록 (DAO 계층 표시)
public interface MemberRepository extends JpaRepository<Member, UUID> {

    // ===== 사업장 필터링 없는 메서드들은 보안상 제거됨 =====
    // REMOVED: findByMemberNumber() - 사업장 필터링 필수
    // REMOVED: findByNameContaining() - 사업장 필터링 필수
    // REMOVED: findByPhoneContaining() - 사업장 필터링 필수
    // REMOVED: findByEmailContaining() - 사업장 필터링 필수
    // 대신 아래의 사업장 필터링이 포함된 메서드를 사용하세요.

    /**
     * 사업장별 회원 목록 조회
     *
     * 특정 사업장에 속한 모든 회원을 조회합니다.
     *
     * 생성되는 SQL:
     * SELECT * FROM members WHERE business_place_id = ?
     *
     * @param businessPlaceId 사업장 ID
     * @return 해당 사업장의 회원 목록
     */
    List<Member> findByBusinessPlaceId(String businessPlaceId);

    /**
     * 사업장별 회원 수 조회
     *
     * 특정 사업장에 속한 회원의 수를 카운트합니다.
     *
     * 생성되는 SQL:
     * SELECT COUNT(*) FROM members WHERE business_place_id = ?
     *
     * @param businessPlaceId 사업장 ID
     * @return 해당 사업장의 회원 수
     */
    long countByBusinessPlaceId(String businessPlaceId);

    /**
     * 사업장별 회원 수 조회 (비관적 잠금)
     *
     * Race Condition 방지를 위해 비관적 잠금(FOR UPDATE)을 사용합니다.
     * 회원 생성 시 제한 체크에 사용됩니다.
     *
     * @param businessPlaceId 사업장 ID
     * @return 해당 사업장의 회원 수
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT COUNT(m) FROM Member m WHERE m.businessPlaceId = :businessPlaceId")
    long countByBusinessPlaceIdWithLock(@Param("businessPlaceId") String businessPlaceId);

    /**
     * 회원번호와 사업장 ID로 회원 목록 조회
     *
     * @param memberNumber 검색할 회원번호
     * @param businessPlaceId 사업장 ID
     * @return 해당 회원번호와 사업장 ID를 가진 회원 목록
     */
    List<Member> findByMemberNumberAndBusinessPlaceId(String memberNumber, String businessPlaceId);

    /**
     * 이름과 사업장 ID로 회원 검색 (부분 일치)
     *
     * @param name 검색할 이름 (부분 문자열)
     * @param businessPlaceId 사업장 ID
     * @return 이름에 검색어가 포함되고 해당 사업장에 속한 회원 목록
     */
    List<Member> findByNameContainingAndBusinessPlaceId(String name, String businessPlaceId);

    /**
     * 전화번호와 사업장 ID로 회원 검색 (부분 일치)
     *
     * @param phone 검색할 전화번호 (부분 문자열)
     * @param businessPlaceId 사업장 ID
     * @return 전화번호에 검색어가 포함되고 해당 사업장에 속한 회원 목록
     */
    List<Member> findByPhoneContainingAndBusinessPlaceId(String phone, String businessPlaceId);

    /**
     * 이메일과 사업장 ID로 회원 검색 (부분 일치)
     *
     * @param email 검색할 이메일 (부분 문자열)
     * @param businessPlaceId 사업장 ID
     * @return 이메일에 검색어가 포함되고 해당 사업장에 속한 회원 목록
     */
    List<Member> findByEmailContainingAndBusinessPlaceId(String email, String businessPlaceId);

    // ===== Soft Delete 관련 메서드 =====

    /**
     * 삭제되지 않은 회원 목록 조회 (사업장별)
     */
    List<Member> findByBusinessPlaceIdAndIsDeletedFalse(String businessPlaceId);

    /**
     * 삭제되지 않은 회원 수 조회 (사업장별)
     */
    long countByBusinessPlaceIdAndIsDeletedFalse(String businessPlaceId);

    // REMOVED: findByMemberNumberAndIsDeletedFalse() - 사업장 필터링 필수
    // 대신 findByMemberNumberAndBusinessPlaceIdAndIsDeletedFalse() 사용

    /**
     * 삭제되지 않은 회원번호와 사업장 ID로 회원 목록 조회
     */
    List<Member> findByMemberNumberAndBusinessPlaceIdAndIsDeletedFalse(String memberNumber, String businessPlaceId);

    /**
     * 삭제되지 않은 이름으로 회원 검색 (부분 일치, 사업장별)
     */
    List<Member> findByNameContainingAndBusinessPlaceIdAndIsDeletedFalse(String name, String businessPlaceId);

    /**
     * 삭제되지 않은 전화번호로 회원 검색 (부분 일치, 사업장별)
     */
    List<Member> findByPhoneContainingAndBusinessPlaceIdAndIsDeletedFalse(String phone, String businessPlaceId);

    /**
     * 삭제되지 않은 이메일로 회원 검색 (부분 일치, 사업장별)
     */
    List<Member> findByEmailContainingAndBusinessPlaceIdAndIsDeletedFalse(String email, String businessPlaceId);

    /**
     * 삭제 대기 중인 회원 목록 조회 (사업장별)
     */
    List<Member> findByBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(String businessPlaceId);

    /**
     * 삭제 대기 중인 회원 수 조회 (사업장별)
     */
    long countByBusinessPlaceIdAndIsDeletedTrue(String businessPlaceId);

    /**
     * 사용자가 접근 가능한 모든 사업장의 삭제 대기 회원 목록 조회
     *
     * UserBusinessPlace를 통해 사용자가 APPROVED 상태로 접근할 수 있는 사업장의
     * 모든 삭제 대기 회원을 조회합니다.
     *
     * @param userId 사용자 ID
     * @return 삭제 대기 중인 회원 목록 (삭제 시간 내림차순)
     */
    @Query("SELECT m FROM Member m " +
           "JOIN UserBusinessPlace ubp ON ubp.businessPlaceId = m.businessPlaceId " +
           "WHERE ubp.userId = :userId " +
           "AND ubp.status = com.vocacrm.api.model.AccessStatus.APPROVED " +
           "AND m.isDeleted = true " +
           "ORDER BY m.deletedAt DESC")
    List<Member> findDeletedMembersByUserId(@Param("userId") UUID userId);

    /**
     * 사용자가 접근 가능한 모든 사업장의 삭제 대기 회원 수 조회
     *
     * @param userId 사용자 ID
     * @return 삭제 대기 중인 회원 수
     */
    @Query("SELECT COUNT(m) FROM Member m " +
           "JOIN UserBusinessPlace ubp ON ubp.businessPlaceId = m.businessPlaceId " +
           "WHERE ubp.userId = :userId " +
           "AND ubp.status = com.vocacrm.api.model.AccessStatus.APPROVED " +
           "AND m.isDeleted = true")
    long countDeletedMembersByUserId(@Param("userId") UUID userId);

    /**
     * 여러 사업장 ID에 속하는 삭제되지 않은 회원 목록 조회 (페이징)
     *
     * 사용자가 접근 가능한 여러 사업장의 회원을 한 번에 조회할 때 사용합니다.
     *
     * @param businessPlaceIds 사업장 ID 목록
     * @param pageable 페이지 정보
     * @return 해당 사업장들에 속한 삭제되지 않은 회원 목록 (페이징)
     */
    Page<Member> findByBusinessPlaceIdInAndIsDeletedFalse(List<String> businessPlaceIds, Pageable pageable);

    // ===== 사용자 참조 정리 (사업장 탈퇴 시 사용) =====

    /**
     * 특정 사업장에서 특정 사용자의 owner_id를 NULL로 설정
     */
    @Modifying
    @Query("UPDATE Member m SET m.ownerId = null WHERE m.businessPlaceId = :businessPlaceId AND m.ownerId = :userId")
    int clearOwnerIdByBusinessPlaceIdAndUserId(@Param("businessPlaceId") String businessPlaceId, @Param("userId") UUID userId);

    /**
     * 특정 사업장에서 특정 사용자의 last_modified_by_id를 NULL로 설정
     */
    @Modifying
    @Query("UPDATE Member m SET m.lastModifiedById = null WHERE m.businessPlaceId = :businessPlaceId AND m.lastModifiedById = :userId")
    int clearLastModifiedByIdByBusinessPlaceIdAndUserId(@Param("businessPlaceId") String businessPlaceId, @Param("userId") UUID userId);

    /**
     * 특정 사업장에서 특정 사용자의 deleted_by를 NULL로 설정
     */
    @Modifying
    @Query("UPDATE Member m SET m.deletedBy = null WHERE m.businessPlaceId = :businessPlaceId AND m.deletedBy = :userId")
    int clearDeletedByByBusinessPlaceIdAndUserId(@Param("businessPlaceId") String businessPlaceId, @Param("userId") UUID userId);

    // ===== 사업장 삭제 관련 메서드 =====

    /**
     * 특정 사업장의 모든 회원 ID 목록 조회
     * (메모, 방문 기록 삭제에 사용)
     */
    @Query("SELECT m.id FROM Member m WHERE m.businessPlaceId = :businessPlaceId")
    List<UUID> findMemberIdsByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);

    /**
     * 특정 사업장의 모든 회원 삭제 (Hard Delete)
     */
    @Modifying
    @Query("DELETE FROM Member m WHERE m.businessPlaceId = :businessPlaceId")
    int deleteAllByBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);
}