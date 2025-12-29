package com.vocacrm.api.controller;

import com.vocacrm.api.dto.VoiceCommandRequest;
import com.vocacrm.api.dto.VoiceCommandResponse;
import com.vocacrm.api.service.VoiceCommandService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * 음성 명령 처리 컨트롤러
 * Flutter 앱에서 음성 명령을 받아 AI 서버로 분석 요청 후 처리
 */
@Slf4j
@RestController
@RequestMapping("/api/voice")
@RequiredArgsConstructor
public class VoiceCommandController {

    private final VoiceCommandService voiceCommandService;

    /**
     * 새 음성 명령 처리 엔드포인트 (AI 분석 필요)
     *
     * POST /api/voice/command
     * Request Body: { "text": "1234 회원 메모 알려줘" }
     * Response: VoiceCommandResponse (status, message, data, context)
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * Note: 이 엔드포인트는 AI 분석 + DeepL 번역을 사용하므로 보수적인 rate limiting 적용
     *       대화 이어가기는 /continue 엔드포인트 사용
     */
    @PostMapping("/command")
    public ResponseEntity<VoiceCommandResponse> processVoiceCommand(
            @RequestBody VoiceCommandRequest request,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        try {
            // context가 있으면 잘못된 엔드포인트 사용 - /continue 사용 안내
            if (request.getContext() != null && request.getContext().getCurrentStep() != null) {
                VoiceCommandResponse errorResponse = VoiceCommandResponse.builder()
                        .status("error")
                        .message("대화 이어가기는 /api/voice/continue 엔드포인트를 사용해주세요.")
                        .errorCode("WRONG_ENDPOINT")
                        .build();
                return ResponseEntity.badRequest().body(errorResponse);
            }

            // JWT에서 userId 추출하여 request에 설정 (DTO의 userId는 무시)
            String userId = (String) servletRequest.getAttribute("userId");
            request.setUserId(userId);

            VoiceCommandResponse response = voiceCommandService.processNewCommand(request);
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("❌ Error processing voice command: {}", e.getMessage(), e);

            VoiceCommandResponse errorResponse = VoiceCommandResponse.builder()
                    .status("error")
                    .message("명령 처리 중 오류가 발생했습니다.")
                    .errorCode("INTERNAL_ERROR")
                    .build();

            return ResponseEntity.status(500).body(errorResponse);
        }
    }

    /**
     * 대화 이어가기 엔드포인트 (AI 분석 없음)
     *
     * POST /api/voice/continue
     * Request Body: { "text": "첫 번째", "context": {...} }
     * Response: VoiceCommandResponse (status, message, data, context)
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * Note: 이 엔드포인트는 AI 분석 없이 사용자 선택/확인만 처리
     *       context 필수
     */
    @PostMapping("/continue")
    public ResponseEntity<VoiceCommandResponse> continueConversation(
            @RequestBody VoiceCommandRequest request,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        try {
            // context가 없으면 에러 반환
            if (request.getContext() == null || request.getContext().getCurrentStep() == null) {
                VoiceCommandResponse errorResponse = VoiceCommandResponse.builder()
                        .status("error")
                        .message("대화 컨텍스트가 필요합니다. 새 명령은 /api/voice/command 엔드포인트를 사용해주세요.")
                        .errorCode("MISSING_CONTEXT")
                        .build();
                return ResponseEntity.badRequest().body(errorResponse);
            }

            // JWT에서 userId 추출하여 request에 설정
            String userId = (String) servletRequest.getAttribute("userId");
            request.setUserId(userId);

            VoiceCommandResponse response = voiceCommandService.processContinuedConversation(request);
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("❌ Error continuing conversation: {}", e.getMessage(), e);

            VoiceCommandResponse errorResponse = VoiceCommandResponse.builder()
                    .status("error")
                    .message("대화 처리 중 오류가 발생했습니다.")
                    .errorCode("INTERNAL_ERROR")
                    .build();

            return ResponseEntity.status(500).body(errorResponse);
        }
    }

    /**
     * 헬스체크 엔드포인트
     */
    @GetMapping("/health")
    public ResponseEntity<String> healthCheck() {
        return ResponseEntity.ok("Voice command service is running");
    }

    /**
     * 일일 브리핑 엔드포인트
     *
     * GET /api/voice/daily-briefing?businessPlaceId={businessPlaceId}
     * Response: { "message": "오늘은 3명의 예약이 있습니다...", "data": {...} }
     *
     * Required Headers:
     * - Authorization: Bearer {JWT token}
     *
     * Note: businessPlaceId가 없으면 사용자의 기본 사업장 사용
     */
    @GetMapping("/daily-briefing")
    public ResponseEntity<VoiceCommandResponse> getDailyBriefing(
            @RequestParam(required = false) String businessPlaceId,
            jakarta.servlet.http.HttpServletRequest servletRequest) {
        try {
            // JWT에서 userId 추출
            String userId = (String) servletRequest.getAttribute("userId");

            // businessPlaceId가 없으면 defaultBusinessPlaceId 사용
            if (businessPlaceId == null) {
                businessPlaceId = (String) servletRequest.getAttribute("defaultBusinessPlaceId");
            }

            VoiceCommandResponse response = voiceCommandService.generateDailyBriefing(userId, businessPlaceId);
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("❌ Error generating daily briefing: {}", e.getMessage(), e);

            VoiceCommandResponse errorResponse = VoiceCommandResponse.builder()
                    .status("error")
                    .message("일일 브리핑 생성 중 오류가 발생했습니다.")
                    .errorCode("BRIEFING_ERROR")
                    .build();

            return ResponseEntity.status(500).body(errorResponse);
        }
    }
}
