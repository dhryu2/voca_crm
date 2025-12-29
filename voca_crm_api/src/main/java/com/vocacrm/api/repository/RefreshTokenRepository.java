package com.vocacrm.api.repository;

import com.vocacrm.api.model.RefreshToken;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Refresh Token Redis Repository
 *
 * Spring Data Redis를 사용하여 RefreshToken CRUD 작업 수행
 */
@Repository
public interface RefreshTokenRepository extends CrudRepository<RefreshToken, String> {

    /**
     * 사용자 ID로 모든 Refresh Token 조회
     */
    List<RefreshToken> findByUserId(String userId);

    /**
     * 사용자 ID로 폐기되지 않은 Refresh Token 조회
     */
    List<RefreshToken> findByUserIdAndRevokedFalse(String userId);

    /**
     * 토큰 ID로 조회
     */
    Optional<RefreshToken> findByTokenId(String tokenId);

    /**
     * 사용자 ID로 모든 토큰 삭제
     */
    void deleteByUserId(String userId);
}
