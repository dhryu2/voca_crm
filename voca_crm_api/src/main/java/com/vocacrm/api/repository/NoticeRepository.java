package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.Notice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 공지사항 Repository
 *
 * Notice 엔티티에 대한 데이터베이스 접근을 담당합니다.
 */
@Repository
public interface NoticeRepository extends JpaRepository<Notice, UUID> {

    /**
     * 현재 활성화된 공지사항 조회
     *
     * 조건:
     * - isActive = true
     * - 현재 날짜가 startDate와 endDate 사이
     *
     * 정렬: priority 내림차순 -> createdAt 내림차순
     */
    @Query("SELECT n FROM Notice n WHERE n.isActive = true " +
           "AND n.startDate <= :currentDate AND n.endDate >= :currentDate " +
           "ORDER BY n.priority DESC, n.createdAt DESC")
    List<Notice> findActiveNotices(@Param("currentDate") LocalDateTime currentDate);

    /**
     * 모든 공지사항 조회 (관리자용)
     *
     * 정렬: priority 내림차순 -> createdAt 내림차순
     */
    List<Notice> findAllByOrderByPriorityDescCreatedAtDesc();

    /**
     * 활성화 여부로 공지사항 조회
     */
    List<Notice> findByIsActiveOrderByPriorityDescCreatedAtDesc(Boolean isActive);
}
