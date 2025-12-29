package com.vocacrm.api.repository;

import java.util.UUID;

import com.vocacrm.api.model.DeviceToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 디바이스 토큰 Repository
 */
@Repository
public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {

    /**
     * 사용자의 모든 활성 토큰 조회
     */
    List<DeviceToken> findByUserIdAndIsActiveTrue(UUID userId);

    /**
     * 특정 FCM 토큰으로 조회
     */
    Optional<DeviceToken> findByFcmToken(String fcmToken);

    /**
     * 사용자 ID와 FCM 토큰으로 조회
     */
    Optional<DeviceToken> findByUserIdAndFcmToken(UUID userId, String fcmToken);

    /**
     * 사용자의 모든 토큰 조회
     */
    List<DeviceToken> findByUserId(UUID userId);

    /**
     * 특정 토큰 비활성화
     */
    @Modifying
    @Query("UPDATE DeviceToken d SET d.isActive = false WHERE d.fcmToken = :fcmToken")
    void deactivateByFcmToken(@Param("fcmToken") String fcmToken);

    /**
     * 사용자의 모든 토큰 비활성화
     */
    @Modifying
    @Query("UPDATE DeviceToken d SET d.isActive = false WHERE d.userId = :userId")
    void deactivateAllByUserId(@Param("userId") UUID userId);

    /**
     * 마지막 사용 시간 업데이트
     */
    @Modifying
    @Query("UPDATE DeviceToken d SET d.lastUsedAt = :lastUsedAt WHERE d.fcmToken = :fcmToken")
    void updateLastUsedAt(@Param("fcmToken") String fcmToken, @Param("lastUsedAt") LocalDateTime lastUsedAt);

    /**
     * 오래된 비활성 토큰 삭제
     */
    @Modifying
    @Query("DELETE FROM DeviceToken d WHERE d.isActive = false AND d.updatedAt < :before")
    void deleteInactiveTokensBefore(@Param("before") LocalDateTime before);

    /**
     * 사용자 토큰 개수 조회
     */
    long countByUserIdAndIsActiveTrue(UUID userId);
}
