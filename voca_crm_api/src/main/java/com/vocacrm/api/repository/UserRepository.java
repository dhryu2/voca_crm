package com.vocacrm.api.repository;

import com.vocacrm.api.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    // ===== 사업장 삭제 관련 메서드 =====

    /**
     * 특정 사업장을 기본 사업장으로 설정한 사용자의 default_business_place_id를 NULL로 설정
     */
    @Modifying
    @Query("UPDATE User u SET u.defaultBusinessPlaceId = null WHERE u.defaultBusinessPlaceId = :businessPlaceId")
    int clearDefaultBusinessPlaceId(@Param("businessPlaceId") String businessPlaceId);
}
