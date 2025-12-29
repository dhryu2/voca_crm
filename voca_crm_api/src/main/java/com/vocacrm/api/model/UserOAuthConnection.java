package com.vocacrm.api.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.vocacrm.api.enums.Provider;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.ToString;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 사용자 OAuth 연결 정보
 *
 * 한 사용자가 여러 OAuth 제공자(Google, Kakao, Apple 등)를 연결할 수 있습니다.
 * users : user_oauth_connections = 1 : N 관계
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "user_oauth_connections",
       uniqueConstraints = {
           @UniqueConstraint(name = "uk_provider_user", columnNames = {"provider", "provider_user_id"})
       })
public class UserOAuthConnection {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    @ToString.Exclude
    @JsonIgnore
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "provider", nullable = false, length = 50)
    private Provider provider;

    @Column(name = "provider_user_id", nullable = false, length = 256)
    private String providerUserId;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    /**
     * User 연결을 위한 생성자
     */
    public static UserOAuthConnection create(User user, Provider provider, String providerUserId) {
        return UserOAuthConnection.builder()
                .user(user)
                .provider(provider)
                .providerUserId(providerUserId)
                .build();
    }
}
