package com.vocacrm.api.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 시스템 관리자 권한 확인을 위한 서비스
 * application.yaml의 app.system-admin-ids 설정을 기반으로 관리자 여부를 판단합니다.
 */
@Slf4j
@Service
public class SystemAdminService {

    private final Set<String> systemAdminIds;

    public SystemAdminService(@Value("${app.system-admin-ids:}") String systemAdminIdsConfig) {
        if (systemAdminIdsConfig == null || systemAdminIdsConfig.trim().isEmpty()) {
            this.systemAdminIds = Set.of();
            log.info("No system admin IDs configured");
        } else {
            this.systemAdminIds = Arrays.stream(systemAdminIdsConfig.split(","))
                    .map(String::trim)
                    .filter(id -> !id.isEmpty())
                    .collect(Collectors.toUnmodifiableSet());
            log.info("Loaded {} system admin ID(s)", this.systemAdminIds.size());
        }
    }

    /**
     * 주어진 사용자 ID가 시스템 관리자인지 확인합니다.
     *
     * @param userId 사용자 ID (String)
     * @return 시스템 관리자 여부
     */
    public boolean isSystemAdmin(String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            return false;
        }
        return systemAdminIds.contains(userId.trim());
    }

    /**
     * 주어진 사용자 UUID가 시스템 관리자인지 확인합니다.
     *
     * @param userId 사용자 UUID
     * @return 시스템 관리자 여부
     */
    public boolean isSystemAdmin(UUID userId) {
        if (userId == null) {
            return false;
        }
        return isSystemAdmin(userId.toString());
    }

    /**
     * 현재 설정된 시스템 관리자 수를 반환합니다.
     *
     * @return 시스템 관리자 수
     */
    public int getAdminCount() {
        return systemAdminIds.size();
    }
}
