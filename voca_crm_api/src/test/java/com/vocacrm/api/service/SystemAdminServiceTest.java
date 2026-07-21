package com.vocacrm.api.service;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class SystemAdminServiceTest {

    @Test
    void isSystemAdmin_설정된_ID면_true를_반환한다() {
        SystemAdminService service = new SystemAdminService("admin-1,admin-2");

        assertThat(service.isSystemAdmin("admin-1")).isTrue();
        assertThat(service.isSystemAdmin(" admin-2 ")).isTrue(); // 조회 시에도 trim 후 비교
    }

    @Test
    void isSystemAdmin_설정되지않은_ID면_false를_반환한다() {
        SystemAdminService service = new SystemAdminService("admin-1,admin-2");

        assertThat(service.isSystemAdmin("admin-3")).isFalse();
    }

    @Test
    void isSystemAdmin_null_또는_빈문자열이면_false를_반환한다() {
        SystemAdminService service = new SystemAdminService("admin-1");

        assertThat(service.isSystemAdmin((String) null)).isFalse();
        assertThat(service.isSystemAdmin("")).isFalse();
        assertThat(service.isSystemAdmin("  ")).isFalse();
    }

    @Test
    void isSystemAdmin_UUID_오버로드는_문자열_변환후_판단한다() {
        UUID adminId = UUID.randomUUID();
        SystemAdminService service = new SystemAdminService(adminId.toString());

        assertThat(service.isSystemAdmin(adminId)).isTrue();
        assertThat(service.isSystemAdmin((UUID) null)).isFalse();
        assertThat(service.isSystemAdmin(UUID.randomUUID())).isFalse();
    }

    @Test
    void 설정값이_없으면_관리자_수가_0이다() {
        SystemAdminService service = new SystemAdminService("");

        assertThat(service.getAdminCount()).isEqualTo(0);
    }

    @Test
    void 설정값이_있으면_관리자_수를_반환한다() {
        SystemAdminService service = new SystemAdminService("admin-1, admin-2 ,admin-3");

        assertThat(service.getAdminCount()).isEqualTo(3);
    }

    @Test
    void 설정값이_null이면_관리자_수가_0이다() {
        SystemAdminService service = new SystemAdminService(null);

        assertThat(service.getAdminCount()).isEqualTo(0);
    }
}
