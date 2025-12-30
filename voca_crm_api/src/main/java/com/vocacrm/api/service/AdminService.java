package com.vocacrm.api.service;

import com.vocacrm.api.dto.admin.AdminBusinessPlaceDTO;
import com.vocacrm.api.dto.admin.AdminUserDTO;
import com.vocacrm.api.dto.admin.SystemStatsDTO;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.model.UserOAuthConnection;
import com.vocacrm.api.repository.BusinessPlaceRepository;
import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 시스템 관리자용 서비스
 * 사용자 관리, 사업장 관리, 시스템 통계 등을 제공합니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AdminService {

    private final UserRepository userRepository;
    private final BusinessPlaceRepository businessPlaceRepository;
    private final UserBusinessPlaceRepository userBusinessPlaceRepository;
    private final MemberRepository memberRepository;
    private final SystemAdminService systemAdminService;

    /**
     * 시스템 관리자 권한 검증
     */
    public void validateSystemAdmin(Boolean isSystemAdmin) {
        if (isSystemAdmin == null || !isSystemAdmin) {
            throw new RuntimeException("시스템 관리자 권한이 필요합니다.");
        }
    }

    // ==================== 시스템 통계 ====================

    /**
     * 시스템 전체 통계 조회
     */
    @Transactional(readOnly = true)
    public SystemStatsDTO getSystemStats() {
        long totalUsers = userRepository.count();
        long totalBusinessPlaces = businessPlaceRepository.count();

        // 오늘 가입자 수
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        long newUsersToday = userRepository.findAll().stream()
                .filter(u -> u.getCreatedAt() != null && u.getCreatedAt().isAfter(todayStart))
                .count();

        // 이번 주 가입자 수
        LocalDateTime weekStart = LocalDate.now().minusDays(7).atStartOfDay();
        long newUsersThisWeek = userRepository.findAll().stream()
                .filter(u -> u.getCreatedAt() != null && u.getCreatedAt().isAfter(weekStart))
                .count();

        return SystemStatsDTO.builder()
                .totalUsers(totalUsers)
                .activeUsers(totalUsers)  // 현재 모든 사용자가 활성 상태
                .newUsersToday(newUsersToday)
                .newUsersThisWeek(newUsersThisWeek)
                .totalBusinessPlaces(totalBusinessPlaces)
                .activeBusinessPlaces(totalBusinessPlaces)  // 현재 모든 사업장이 활성 상태
                .dau(0)  // TODO: 실제 DAU 계산 로직 필요
                .mau(0)  // TODO: 실제 MAU 계산 로직 필요
                .build();
    }

    // ==================== 사용자 관리 ====================

    /**
     * 전체 사용자 목록 조회 (페이징)
     */
    @Transactional(readOnly = true)
    public Page<AdminUserDTO> getAllUsers(String search, String status, Pageable pageable) {
        List<User> allUsers = userRepository.findAll();

        // 검색 필터링
        if (search != null && !search.isEmpty()) {
            String searchLower = search.toLowerCase();
            allUsers = allUsers.stream()
                    .filter(u ->
                        (u.getUsername() != null && u.getUsername().toLowerCase().contains(searchLower)) ||
                        (u.getEmail() != null && u.getEmail().toLowerCase().contains(searchLower)) ||
                        (u.getPhone() != null && u.getPhone().contains(search))
                    )
                    .collect(Collectors.toList());
        }

        // 사용자별 사업장 수 계산
        Map<UUID, Long> businessPlaceCountMap = userBusinessPlaceRepository.findAll().stream()
                .filter(ubp -> ubp.getStatus() == AccessStatus.APPROVED)
                .collect(Collectors.groupingBy(UserBusinessPlace::getUserId, Collectors.counting()));

        // DTO 변환
        List<AdminUserDTO> userDTOs = allUsers.stream()
                .map(user -> convertToAdminUserDTO(user, businessPlaceCountMap.getOrDefault(user.getId(), 0L)))
                .collect(Collectors.toList());

        // 페이징 적용
        int start = (int) pageable.getOffset();
        int end = Math.min(start + pageable.getPageSize(), userDTOs.size());

        if (start > userDTOs.size()) {
            return new PageImpl<>(List.of(), pageable, userDTOs.size());
        }

        return new PageImpl<>(userDTOs.subList(start, end), pageable, userDTOs.size());
    }

    private AdminUserDTO convertToAdminUserDTO(User user, long businessPlaceCount) {
        // OAuth provider 정보 가져오기
        String provider = "UNKNOWN";
        if (user.getOauthConnections() != null && !user.getOauthConnections().isEmpty()) {
            UserOAuthConnection firstConnection = user.getOauthConnections().get(0);
            provider = firstConnection.getProvider().name();
        }

        return AdminUserDTO.builder()
                .providerId(user.getId().toString())
                .provider(provider)
                .name(user.getUsername())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role("USER")
                .isSystemAdmin(systemAdminService.isSystemAdmin(user.getId()))
                .status("ACTIVE")  // 현재 모든 사용자가 활성 상태
                .lastLoginAt(null)  // TODO: 로그인 기록 테이블 연동 필요
                .loginCount(0)  // TODO: 로그인 카운트 테이블 연동 필요
                .businessPlaceCount(businessPlaceCount)
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .build();
    }

    // ==================== 사업장 관리 ====================

    /**
     * 전체 사업장 목록 조회 (페이징)
     */
    @Transactional(readOnly = true)
    public Page<AdminBusinessPlaceDTO> getAllBusinessPlaces(String search, String status, Pageable pageable) {
        List<BusinessPlace> allPlaces = businessPlaceRepository.findAll();

        // 검색 필터링
        if (search != null && !search.isEmpty()) {
            String searchLower = search.toLowerCase();
            allPlaces = allPlaces.stream()
                    .filter(bp ->
                        (bp.getName() != null && bp.getName().toLowerCase().contains(searchLower)) ||
                        (bp.getAddress() != null && bp.getAddress().toLowerCase().contains(searchLower))
                    )
                    .collect(Collectors.toList());
        }

        // 사업장별 회원 수 계산
        Map<String, Long> memberCountMap = allPlaces.stream()
                .collect(Collectors.toMap(
                        BusinessPlace::getId,
                        bp -> memberRepository.countByBusinessPlaceIdAndIsDeletedFalse(bp.getId())
                ));

        // 사업장별 직원 수 계산
        Map<String, Long> staffCountMap = allPlaces.stream()
                .collect(Collectors.toMap(
                        BusinessPlace::getId,
                        bp -> userBusinessPlaceRepository.countStaffByBusinessPlaceId(bp.getId())
                ));

        // 사업장별 Owner 정보 조회
        Map<String, User> ownerMap = allPlaces.stream()
                .collect(Collectors.toMap(
                        BusinessPlace::getId,
                        bp -> findOwnerByBusinessPlaceId(bp.getId()),
                        (existing, replacement) -> existing
                ));

        // DTO 변환
        List<AdminBusinessPlaceDTO> placeDTOs = allPlaces.stream()
                .map(bp -> convertToAdminBusinessPlaceDTO(
                        bp,
                        memberCountMap.getOrDefault(bp.getId(), 0L),
                        staffCountMap.getOrDefault(bp.getId(), 0L),
                        ownerMap.get(bp.getId())
                ))
                .collect(Collectors.toList());

        // 페이징 적용
        int start = (int) pageable.getOffset();
        int end = Math.min(start + pageable.getPageSize(), placeDTOs.size());

        if (start > placeDTOs.size()) {
            return new PageImpl<>(List.of(), pageable, placeDTOs.size());
        }

        return new PageImpl<>(placeDTOs.subList(start, end), pageable, placeDTOs.size());
    }

    private User findOwnerByBusinessPlaceId(String businessPlaceId) {
        return userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus(businessPlaceId, AccessStatus.APPROVED)
                .stream()
                .filter(ubp -> ubp.getRole() == Role.OWNER)
                .findFirst()
                .map(ubp -> userRepository.findById(ubp.getUserId()).orElse(null))
                .orElse(null);
    }

    private AdminBusinessPlaceDTO convertToAdminBusinessPlaceDTO(
            BusinessPlace bp, long memberCount, long staffCount, User owner) {
        return AdminBusinessPlaceDTO.builder()
                .id(bp.getId())
                .name(bp.getName())
                .address(bp.getAddress())
                .phone(bp.getPhone())
                .description(null)  // BusinessPlace에 description 필드 없음
                .ownerId(owner != null ? owner.getId().toString() : null)
                .ownerName(owner != null ? owner.getUsername() : "알 수 없음")
                .ownerEmail(owner != null ? owner.getEmail() : null)
                .status("ACTIVE")  // 현재 모든 사업장이 활성 상태
                .memberCount(memberCount)
                .staffCount(staffCount)
                .lastActivityAt(null)  // TODO: 활동 로그 연동 필요
                .createdAt(bp.getCreatedAt())
                .updatedAt(bp.getUpdatedAt())
                .build();
    }
}
