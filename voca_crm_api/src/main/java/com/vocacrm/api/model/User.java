package com.vocacrm.api.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.ToString;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(length = 255)
    private String email;

    @Column(nullable = false, length = 100)
    private String username;

    @Column(name = "display_name", length = 100)
    private String displayName;

    @Column(name = "phone", length = 20)
    private String phone;

    @Column(name = "default_business_place_id", length = 7)
    private String defaultBusinessPlaceId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "default_business_place_id", insertable = false, updatable = false)
    @ToString.Exclude
    @JsonIgnore
    private BusinessPlace defaultBusinessPlace;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String tier = "FREE";

    @Column(name = "fcm_token", length = 500)
    private String fcmToken;

    @Column(name = "push_notification_enabled", nullable = false)
    @Builder.Default
    private Boolean pushNotificationEnabled = true;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    @ToString.Exclude
    @JsonIgnore
    private List<UserOAuthConnection> oauthConnections = new ArrayList<>();

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    /**
     * OAuth 연결 추가
     */
    public void addOAuthConnection(UserOAuthConnection connection) {
        oauthConnections.add(connection);
        connection.setUser(this);
    }

    /**
     * OAuth 연결 제거
     */
    public void removeOAuthConnection(UserOAuthConnection connection) {
        oauthConnections.remove(connection);
        connection.setUser(null);
    }
}
