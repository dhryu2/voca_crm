package com.vocacrm.api.service;

import com.vocacrm.api.dto.admin.AdminBusinessPlaceDTO;
import com.vocacrm.api.dto.admin.AdminUserDTO;
import com.vocacrm.api.dto.admin.SystemStatsDTO;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.repository.BusinessPlaceRepository;
import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private BusinessPlaceRepository businessPlaceRepository;

    @Mock
    private UserBusinessPlaceRepository userBusinessPlaceRepository;

    @Mock
    private MemberRepository memberRepository;

    @Mock
    private SystemAdminService systemAdminService;

    @InjectMocks
    private AdminService adminService;

    @Test
    void validateSystemAdmin_true면_예외를_던지지않는다() {
        adminService.validateSystemAdmin(true);
    }

    @Test
    void validateSystemAdmin_null이면_예외를_던진다() {
        assertThatThrownBy(() -> adminService.validateSystemAdmin(null))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void validateSystemAdmin_false면_예외를_던진다() {
        assertThatThrownBy(() -> adminService.validateSystemAdmin(false))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getSystemStats_사용자와_사업장_통계를_계산한다() {
        User recentUser = User.builder().id(UUID.randomUUID()).createdAt(LocalDateTime.now()).build();
        User oldUser = User.builder().id(UUID.randomUUID()).createdAt(LocalDateTime.now().minusDays(30)).build();

        when(userRepository.count()).thenReturn(2L);
        when(businessPlaceRepository.count()).thenReturn(1L);
        when(userRepository.findAll()).thenReturn(List.of(recentUser, oldUser));

        SystemStatsDTO stats = adminService.getSystemStats();

        assertThat(stats.getTotalUsers()).isEqualTo(2L);
        assertThat(stats.getTotalBusinessPlaces()).isEqualTo(1L);
        assertThat(stats.getNewUsersToday()).isEqualTo(1L);
        assertThat(stats.getNewUsersThisWeek()).isEqualTo(1L);
    }

    @Test
    void getAllUsers_검색어로_필터링하고_사업장수를_계산한다() {
        UUID userId = UUID.randomUUID();
        User user = User.builder().id(userId).username("홍길동").email("hong@example.com").phone("01011112222")
                .createdAt(LocalDateTime.now()).updatedAt(LocalDateTime.now()).build();
        User other = User.builder().id(UUID.randomUUID()).username("김철수").email("kim@example.com").phone("01033334444")
                .createdAt(LocalDateTime.now()).updatedAt(LocalDateTime.now()).build();

        UserBusinessPlace ubp = UserBusinessPlace.builder().userId(userId).status(AccessStatus.APPROVED).build();

        when(userRepository.findAll()).thenReturn(List.of(user, other));
        when(userBusinessPlaceRepository.findAll()).thenReturn(List.of(ubp));
        when(systemAdminService.isSystemAdmin(userId)).thenReturn(false);

        Pageable pageable = PageRequest.of(0, 10);
        Page<AdminUserDTO> result = adminService.getAllUsers("홍길동", null, pageable);

        assertThat(result.getContent()).hasSize(1);
        assertThat(result.getContent().get(0).getName()).isEqualTo("홍길동");
        assertThat(result.getContent().get(0).getBusinessPlaceCount()).isEqualTo(1L);
    }

    @Test
    void getAllUsers_페이지_시작이_전체크기를_초과하면_빈페이지를_반환한다() {
        User user = User.builder().id(UUID.randomUUID()).username("user1")
                .createdAt(LocalDateTime.now()).updatedAt(LocalDateTime.now()).build();

        when(userRepository.findAll()).thenReturn(List.of(user));
        when(userBusinessPlaceRepository.findAll()).thenReturn(List.of());

        Pageable pageable = PageRequest.of(5, 10);
        Page<AdminUserDTO> result = adminService.getAllUsers(null, null, pageable);

        assertThat(result.getContent()).isEmpty();
        assertThat(result.getTotalElements()).isEqualTo(1L);
    }

    @Test
    void getAllBusinessPlaces_검색어로_필터링하고_통계를_계산한다() {
        BusinessPlace place = BusinessPlace.builder().id("BP00001").name("테스트매장").address("서울시")
                .createdAt(LocalDateTime.now()).updatedAt(LocalDateTime.now()).build();

        UUID ownerId = UUID.randomUUID();
        User owner = User.builder().id(ownerId).username("사장님").email("owner@example.com").build();
        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(ownerId).businessPlaceId("BP00001").role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(businessPlaceRepository.findAll()).thenReturn(List.of(place));
        when(memberRepository.countByBusinessPlaceIdAndIsDeletedFalse("BP00001")).thenReturn(3L);
        when(userBusinessPlaceRepository.countStaffByBusinessPlaceId("BP00001")).thenReturn(2L);
        when(userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus("BP00001", AccessStatus.APPROVED))
                .thenReturn(List.of(ownerUbp));
        when(userRepository.findById(ownerId)).thenReturn(java.util.Optional.of(owner));

        Pageable pageable = PageRequest.of(0, 10);
        Page<AdminBusinessPlaceDTO> result = adminService.getAllBusinessPlaces("테스트", null, pageable);

        assertThat(result.getContent()).hasSize(1);
        AdminBusinessPlaceDTO dto = result.getContent().get(0);
        assertThat(dto.getMemberCount()).isEqualTo(3L);
        assertThat(dto.getStaffCount()).isEqualTo(2L);
        assertThat(dto.getOwnerName()).isEqualTo("사장님");
    }

    @Test
    void getAllBusinessPlaces_페이지_시작이_전체크기를_초과하면_빈페이지를_반환한다() {
        BusinessPlace place = BusinessPlace.builder().id("BP00001").name("테스트매장")
                .createdAt(LocalDateTime.now()).updatedAt(LocalDateTime.now()).build();

        UUID ownerId = UUID.randomUUID();
        User owner = User.builder().id(ownerId).username("사장님").build();
        UserBusinessPlace ownerUbp = UserBusinessPlace.builder()
                .userId(ownerId).businessPlaceId("BP00001").role(Role.OWNER).status(AccessStatus.APPROVED).build();

        when(businessPlaceRepository.findAll()).thenReturn(List.of(place));
        when(memberRepository.countByBusinessPlaceIdAndIsDeletedFalse("BP00001")).thenReturn(0L);
        when(userBusinessPlaceRepository.countStaffByBusinessPlaceId("BP00001")).thenReturn(0L);
        when(userBusinessPlaceRepository.findByBusinessPlaceIdAndStatus("BP00001", AccessStatus.APPROVED))
                .thenReturn(List.of(ownerUbp));
        when(userRepository.findById(ownerId)).thenReturn(java.util.Optional.of(owner));

        Pageable pageable = PageRequest.of(5, 10);
        Page<AdminBusinessPlaceDTO> result = adminService.getAllBusinessPlaces(null, null, pageable);

        assertThat(result.getContent()).isEmpty();
        assertThat(result.getTotalElements()).isEqualTo(1L);
    }
}
