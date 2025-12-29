package com.vocacrm.api.repository;

import com.vocacrm.api.enums.Provider;
import com.vocacrm.api.model.UserOAuthConnection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserOAuthConnectionRepository extends JpaRepository<UserOAuthConnection, UUID> {

    /**
     * Provider와 Provider User ID로 OAuth 연결 조회
     * 로그인 시 사용
     */
    Optional<UserOAuthConnection> findByProviderAndProviderUserId(Provider provider, String providerUserId);

    /**
     * Provider User ID로 OAuth 연결 조회 (Provider 무관)
     */
    Optional<UserOAuthConnection> findByProviderUserId(String providerUserId);

    /**
     * 사용자의 모든 OAuth 연결 조회
     */
    List<UserOAuthConnection> findByUserId(UUID userId);

    /**
     * 사용자의 특정 Provider OAuth 연결 조회
     */
    Optional<UserOAuthConnection> findByUserIdAndProvider(UUID userId, Provider provider);

    /**
     * Provider와 Provider User ID로 OAuth 연결 존재 여부 확인
     */
    boolean existsByProviderAndProviderUserId(Provider provider, String providerUserId);

    /**
     * Provider User ID로 User 조회 (JOIN FETCH)
     */
    @Query("SELECT uoc FROM UserOAuthConnection uoc JOIN FETCH uoc.user WHERE uoc.provider = :provider AND uoc.providerUserId = :providerUserId")
    Optional<UserOAuthConnection> findWithUserByProviderAndProviderUserId(
            @Param("provider") Provider provider,
            @Param("providerUserId") String providerUserId
    );
}
