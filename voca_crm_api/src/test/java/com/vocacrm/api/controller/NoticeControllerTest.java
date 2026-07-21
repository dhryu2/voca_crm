package com.vocacrm.api.controller;

import com.vocacrm.api.dto.request.NoticeViewRequest;
import com.vocacrm.api.service.NoticeService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NoticeControllerTest {

    private static final String JWT_USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String BODY_USER_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    private static final String NOTICE_ID = "11111111-2222-3333-4444-555555555555";

    @Mock
    private NoticeService noticeService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private NoticeController noticeController;

    @BeforeEach
    void setUp() {
        when(servletRequest.getAttribute("userId")).thenReturn(JWT_USER_ID);
    }

    @Test
    void recordView_JWT_userId를_서비스에_전달하고_바디의_userId는_무시한다() {
        NoticeViewRequest request = NoticeViewRequest.builder()
                .userId(BODY_USER_ID)
                .doNotShowAgain(true)
                .build();

        ResponseEntity<Map<String, String>> response =
                noticeController.recordView(NOTICE_ID, request, servletRequest);

        verify(noticeService).recordView(JWT_USER_ID, NOTICE_ID, true);
        verify(noticeService, never()).recordView(eq(BODY_USER_ID), anyString(), anyBoolean());
        assertThat(response.getStatusCode().value()).isEqualTo(200);
    }

    @Test
    void recordView_doNotShowAgain이_null이면_false로_전달한다() {
        NoticeViewRequest request = NoticeViewRequest.builder()
                .userId(JWT_USER_ID)
                .doNotShowAgain(null)
                .build();

        noticeController.recordView(NOTICE_ID, request, servletRequest);

        verify(noticeService).recordView(JWT_USER_ID, NOTICE_ID, false);
    }

    @Test
    void recordView_doNotShowAgain이_false면_false로_전달한다() {
        NoticeViewRequest request = NoticeViewRequest.builder()
                .userId(JWT_USER_ID)
                .doNotShowAgain(false)
                .build();

        noticeController.recordView(NOTICE_ID, request, servletRequest);

        verify(noticeService).recordView(JWT_USER_ID, NOTICE_ID, false);
    }
}
