package com.vocacrm.api.controller;

import com.vocacrm.api.dto.ConversationContextDTO;
import com.vocacrm.api.dto.ConversationStep;
import com.vocacrm.api.dto.VoiceCommandRequest;
import com.vocacrm.api.dto.VoiceCommandResponse;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.service.AccessControlService;
import com.vocacrm.api.service.VoiceCommandService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VoiceCommandControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String BUSINESS_PLACE_ID = "ABC1234";

    @Mock
    private VoiceCommandService voiceCommandService;
    @Mock
    private AccessControlService accessControlService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private VoiceCommandController voiceCommandController;

    @Test
    void processVoiceCommand_context가_없으면_정상_처리된다() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText("1234 회원 메모 알려줘");
        VoiceCommandResponse serviceResponse = VoiceCommandResponse.builder().status("completed").build();
        when(voiceCommandService.processNewCommand(request)).thenReturn(serviceResponse);

        ResponseEntity<VoiceCommandResponse> response =
                voiceCommandController.processVoiceCommand(request, servletRequest);

        assertThat(request.getUserId()).isEqualTo(USER_ID);
        assertThat(response.getBody()).isSameAs(serviceResponse);
    }

    @Test
    void processVoiceCommand_context가_있으면_잘못된_엔드포인트_안내를_반환한다() {
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText("첫 번째");
        request.setContext(ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("member_selection").build())
                .build());

        ResponseEntity<VoiceCommandResponse> response =
                voiceCommandController.processVoiceCommand(request, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
        assertThat(response.getBody().getErrorCode()).isEqualTo("WRONG_ENDPOINT");
    }

    @Test
    void processVoiceCommand_서비스에서_예외가_발생하면_500_에러응답을_반환한다() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText("1234 회원 메모 알려줘");
        when(voiceCommandService.processNewCommand(request)).thenThrow(new RuntimeException("AI 서버 오류"));

        ResponseEntity<VoiceCommandResponse> response =
                voiceCommandController.processVoiceCommand(request, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(500);
        assertThat(response.getBody().getErrorCode()).isEqualTo("INTERNAL_ERROR");
    }

    @Test
    void continueConversation_context가_있으면_정상_처리된다() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText("첫 번째");
        request.setContext(ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("member_selection").build())
                .build());
        VoiceCommandResponse serviceResponse = VoiceCommandResponse.builder().status("completed").build();
        when(voiceCommandService.processContinuedConversation(request)).thenReturn(serviceResponse);

        ResponseEntity<VoiceCommandResponse> response =
                voiceCommandController.continueConversation(request, servletRequest);

        assertThat(request.getUserId()).isEqualTo(USER_ID);
        assertThat(response.getBody()).isSameAs(serviceResponse);
    }

    @Test
    void continueConversation_context가_없으면_에러응답을_반환한다() {
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText("첫 번째");

        ResponseEntity<VoiceCommandResponse> response =
                voiceCommandController.continueConversation(request, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(400);
        assertThat(response.getBody().getErrorCode()).isEqualTo("MISSING_CONTEXT");
    }

    @Test
    void continueConversation_서비스가_AccessDeniedException을_던지면_그대로_전파한다() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText("첫 번째");
        request.setContext(ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("member_selection").build())
                .build());
        when(voiceCommandService.processContinuedConversation(request))
                .thenThrow(new AccessDeniedException("접근 권한이 없습니다."));

        org.junit.jupiter.api.Assertions.assertThrows(AccessDeniedException.class,
                () -> voiceCommandController.continueConversation(request, servletRequest));
    }

    @Test
    void continueConversation_서비스에서_일반_예외가_발생하면_500_에러응답을_반환한다() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText("첫 번째");
        request.setContext(ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("member_selection").build())
                .build());
        when(voiceCommandService.processContinuedConversation(request))
                .thenThrow(new RuntimeException("처리 오류"));

        ResponseEntity<VoiceCommandResponse> response =
                voiceCommandController.continueConversation(request, servletRequest);

        assertThat(response.getStatusCode().value()).isEqualTo(500);
        assertThat(response.getBody().getErrorCode()).isEqualTo("INTERNAL_ERROR");
    }

    @Test
    void healthCheck_정상_응답을_반환한다() {
        ResponseEntity<String> response = voiceCommandController.healthCheck();

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isEqualTo("Voice command service is running");
    }

    @Test
    void getDailyBriefing_businessPlaceId가_있으면_멤버십_검증_후_반환한다() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        VoiceCommandResponse serviceResponse = VoiceCommandResponse.builder().status("completed").build();
        when(voiceCommandService.generateDailyBriefing(USER_ID, BUSINESS_PLACE_ID)).thenReturn(serviceResponse);

        ResponseEntity<VoiceCommandResponse> response =
                voiceCommandController.getDailyBriefing(BUSINESS_PLACE_ID, servletRequest);

        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getBody()).isSameAs(serviceResponse);
    }

    @Test
    void getDailyBriefing_businessPlaceId가_없으면_기본_사업장을_사용한다() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        when(servletRequest.getAttribute("defaultBusinessPlaceId")).thenReturn(BUSINESS_PLACE_ID);
        VoiceCommandResponse serviceResponse = VoiceCommandResponse.builder().status("completed").build();
        when(voiceCommandService.generateDailyBriefing(USER_ID, BUSINESS_PLACE_ID)).thenReturn(serviceResponse);

        ResponseEntity<VoiceCommandResponse> response =
                voiceCommandController.getDailyBriefing(null, servletRequest);

        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getBody()).isSameAs(serviceResponse);
    }

    @Test
    void getDailyBriefing_멤버십_검증_실패시_AccessDeniedException_전파() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        org.mockito.Mockito.doThrow(new AccessDeniedException("접근 권한이 없습니다."))
                .when(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);

        org.junit.jupiter.api.Assertions.assertThrows(AccessDeniedException.class,
                () -> voiceCommandController.getDailyBriefing(BUSINESS_PLACE_ID, servletRequest));
    }

    @Test
    void getDailyBriefing_서비스에서_일반_예외가_발생하면_500_에러응답을_반환한다() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
        when(voiceCommandService.generateDailyBriefing(USER_ID, BUSINESS_PLACE_ID))
                .thenThrow(new RuntimeException("브리핑 생성 오류"));

        ResponseEntity<VoiceCommandResponse> response =
                voiceCommandController.getDailyBriefing(BUSINESS_PLACE_ID, servletRequest);

        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(500);
        assertThat(response.getBody().getErrorCode()).isEqualTo("BRIEFING_ERROR");
    }
}
