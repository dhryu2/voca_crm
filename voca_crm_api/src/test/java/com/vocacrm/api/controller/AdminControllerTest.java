package com.vocacrm.api.controller;

import com.vocacrm.api.dto.admin.AdminBusinessPlaceDTO;
import com.vocacrm.api.dto.admin.AdminUserDTO;
import com.vocacrm.api.dto.admin.SystemStatsDTO;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.service.AdminService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminControllerTest {

    @Mock
    private AdminService adminService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private AdminController adminController;

    @Test
    void getSystemStats_시스템관리자면_정상_반환된다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        SystemStatsDTO stats = SystemStatsDTO.builder().totalUsers(10).build();
        when(adminService.getSystemStats()).thenReturn(stats);

        ResponseEntity<SystemStatsDTO> response = adminController.getSystemStats(servletRequest);

        assertThat(response.getBody()).isSameAs(stats);
    }

    @Test
    void getSystemStats_시스템관리자가_아니면_validateSystemAdmin에서_예외가_전파된다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.FALSE);
        doThrow(new AccessDeniedException("시스템 관리자 권한이 필요합니다."))
                .when(adminService).validateSystemAdmin(Boolean.FALSE);

        assertThatThrownBy(() -> adminController.getSystemStats(servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getAllUsers_시스템관리자면_페이징된_사용자_목록을_반환한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        Page<AdminUserDTO> page = new PageImpl<>(List.of(AdminUserDTO.builder().name("홍길동").build()));
        when(adminService.getAllUsers(eq("search"), eq("ACTIVE"), any(Pageable.class))).thenReturn(page);

        ResponseEntity<Page<AdminUserDTO>> response =
                adminController.getAllUsers(0, 20, "search", "ACTIVE", servletRequest);

        assertThat(response.getBody()).isSameAs(page);
    }

    @Test
    void getAllUsers_시스템관리자가_아니면_AccessDeniedException_전파() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(null);
        doThrow(new AccessDeniedException("시스템 관리자 권한이 필요합니다."))
                .when(adminService).validateSystemAdmin(null);

        assertThatThrownBy(() -> adminController.getAllUsers(0, 20, null, null, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getAllBusinessPlaces_시스템관리자면_페이징된_사업장_목록을_반환한다() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.TRUE);
        Page<AdminBusinessPlaceDTO> page = new PageImpl<>(List.of(AdminBusinessPlaceDTO.builder().name("사업장1").build()));
        when(adminService.getAllBusinessPlaces(eq("search"), eq("ACTIVE"), any(Pageable.class))).thenReturn(page);

        ResponseEntity<Page<AdminBusinessPlaceDTO>> response =
                adminController.getAllBusinessPlaces(0, 20, "search", "ACTIVE", servletRequest);

        assertThat(response.getBody()).isSameAs(page);
    }

    @Test
    void getAllBusinessPlaces_시스템관리자가_아니면_AccessDeniedException_전파() {
        when(servletRequest.getAttribute("isSystemAdmin")).thenReturn(Boolean.FALSE);
        doThrow(new AccessDeniedException("시스템 관리자 권한이 필요합니다."))
                .when(adminService).validateSystemAdmin(Boolean.FALSE);

        assertThatThrownBy(() -> adminController.getAllBusinessPlaces(0, 20, null, null, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }
}
