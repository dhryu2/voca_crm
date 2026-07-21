package com.vocacrm.api.service;

import com.vocacrm.api.dto.*;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Memo;
import com.vocacrm.api.model.Visit;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.*;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 음성 명령 처리 서비스
 * Modelfile.txt의 category/action 형식에 맞춰 명령 처리
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class VoiceCommandService {

    private final AiServerClient aiServerClient;
    private final MemberService memberService;
    private final MemoService memoService;
    private final VisitService visitService;
    private final ReservationService reservationService;
    private final AccessControlService accessControlService;
    private final com.vocacrm.api.repository.UserRepository userRepository;

    /**
     * 새 음성 명령 처리 (AI 분석 필요)
     * /api/voice/command 엔드포인트에서 호출
     */
    public VoiceCommandResponse processNewCommand(VoiceCommandRequest request) {
        try {
            // 사용자 ID로 User 조회하여 defaultBusinessPlaceId 가져오기
            String businessPlaceId = null;
            if (request.getUserId() != null) {
                businessPlaceId = userRepository.findById(UUID.fromString(request.getUserId()))
                        .map(com.vocacrm.api.model.User::getDefaultBusinessPlaceId)
                        .orElse(null);
            }

            return processNewCommandInternal(request, businessPlaceId);

        } catch (Exception e) {
            log.error("Error processing voice command: {}", e.getMessage(), e);
            return createErrorResponse("명령 처리 중 오류가 발생했습니다: " + e.getMessage(), "PROCESSING_ERROR");
        }
    }

    /**
     * 대화 이어가기 처리 (AI 분석 없음)
     * /api/voice/continue 엔드포인트에서 호출
     */
    public VoiceCommandResponse processContinuedConversation(VoiceCommandRequest request) {
        try {
            // 사용자 ID로 User 조회하여 defaultBusinessPlaceId 가져오기
            String businessPlaceId = null;
            if (request.getUserId() != null) {
                businessPlaceId = userRepository.findById(UUID.fromString(request.getUserId()))
                        .map(com.vocacrm.api.model.User::getDefaultBusinessPlaceId)
                        .orElse(null);
            }

            return processContinuedConversationInternal(request, businessPlaceId);

        } catch (AccessDeniedException e) {
            throw e;
        } catch (Exception e) {
            log.error("Error continuing conversation: {}", e.getMessage(), e);
            return createErrorResponse("대화 처리 중 오류가 발생했습니다: " + e.getMessage(), "PROCESSING_ERROR");
        }
    }

    /**
     * 새로운 명령 처리 (내부)
     */
    private VoiceCommandResponse processNewCommandInternal(VoiceCommandRequest request, String businessPlaceId) {
        // AI 서버에 명령 분석 요청 (멀티액션 시 결과가 여러 개)
        List<AiAnalysisResult> aiResults = aiServerClient.analyzeCommand(request.getText());

        if (aiResults.isEmpty()) {
            return createErrorResponse("AI 분석 결과를 받지 못했습니다.", "AI_NO_RESULT");
        }

        // 컨텍스트 생성 (requestUserId 포함)
        ConversationContextDTO context = ConversationContextDTO.builder()
                .conversationId(UUID.randomUUID().toString())
                .businessPlaceId(businessPlaceId)
                .requestUserId(request.getUserId())
                .build();

        // 단일 액션: 기존 대화형 처리 흐름 유지
        if (aiResults.size() == 1) {
            AiAnalysisResult aiResult = aiResults.get(0);
            if (aiResult.isError()) {
                return handleErrorResponse(aiResult);
            }
            return routeByCategory(aiResult, context);
        }

        // 멀티액션: 순차 실행 후 결과 집계
        return processMultipleActions(aiResults, context);
    }

    /**
     * 멀티액션 순차 처리
     * 한 명령에 여러 작업이 포함된 경우(예: "등록하고 바로 체크인") 각 작업을 순서대로 실행한다.
     * 어떤 단계가 후보 선택/확인/내용 입력 같은 대화형(clarification) 응답을 요구하면
     * 그 응답을 그대로 반환해 대화가 이어지도록 한다.
     * 어떤 단계가 error를 반환하면 최종 상태를 error로 승격하고 errorCode를 전달한다.
     */
    private VoiceCommandResponse processMultipleActions(List<AiAnalysisResult> aiResults, ConversationContextDTO context) {
        List<String> messages = new ArrayList<>();
        List<Map<String, Object>> steps = new ArrayList<>();
        boolean hasError = false;
        String errorCode = null;

        for (AiAnalysisResult aiResult : aiResults) {
            VoiceCommandResponse stepResponse = aiResult.isError()
                    ? handleErrorResponse(aiResult)
                    : routeByCategory(aiResult, context);

            // 후보 선택/확인/내용 입력이 필요한 단계는 대화를 이어가도록 그대로 반환
            if ("clarification_needed".equals(stepResponse.getStatus())) {
                return stepResponse;
            }

            if (stepResponse.getMessage() != null) {
                messages.add(stepResponse.getMessage());
            }

            Map<String, Object> step = new HashMap<>();
            step.put("status", stepResponse.getStatus());
            step.put("message", stepResponse.getMessage());
            if (stepResponse.getData() != null) {
                step.put("data", stepResponse.getData());
            }
            steps.add(step);

            if ("error".equals(stepResponse.getStatus())) {
                hasError = true;
                if (errorCode == null) {
                    errorCode = stepResponse.getErrorCode();
                }
            }
        }

        return VoiceCommandResponse.builder()
                .status(hasError ? "error" : "completed")
                .message(String.join(" ", messages))
                .errorCode(errorCode)
                .data(Map.of("steps", steps))
                .build();
    }

    /**
     * 카테고리별 라우팅
     */
    private VoiceCommandResponse routeByCategory(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String category = aiResult.getCategory();

        if (category == null) {
            return createErrorResponse("명령 카테고리를 인식할 수 없습니다.", "INVALID_CATEGORY");
        }

        return switch (category.toUpperCase()) {
            case "MEMBER" -> handleMemberCategory(aiResult, context);
            case "MEMO" -> handleMemoCategory(aiResult, context);
            case "VISIT" -> handleVisitCategory(aiResult, context);
            case "STATISTICS" -> handleStatisticsCategory(aiResult, context);
            // BUSINESS_PLACE는 Modelfile에서 ERROR/UNKNOWN으로 처리하도록 설정됨
            default -> createErrorResponse("지원하지 않는 명령입니다: " + category, "UNSUPPORTED_CATEGORY");
        };
    }

    /**
     * AI 에러 응답 처리
     * AI가 채운 message는 Modelfile 내부 표현(영어 포함)일 수 있으므로 사용자에게 그대로 노출하지 않고
     * errorCode별로 한국어 안내 메시지를 확정해서 반환한다.
     */
    private VoiceCommandResponse handleErrorResponse(AiAnalysisResult aiResult) {
        String action = aiResult.getAction();

        String errorCode;
        String message;

        if ("MISSING_PARAMETER".equals(action)) {
            errorCode = "MISSING_PARAMETER";
            message = "이름이나 회원번호 등 필요한 정보를 말씀해주세요.";
        } else if ("DAILY_LIMIT_EXCEEDED".equals(action)) {
            errorCode = "DAILY_LIMIT_EXCEEDED";
            message = "오늘의 AI 분석 사용량을 초과했습니다. 내일 다시 시도해주세요.";
        } else {
            errorCode = "UNKNOWN_COMMAND";
            message = "명령을 이해하지 못했습니다. 다시 말씀해주세요.";
        }

        return createErrorResponse(message, errorCode);
    }

    // ===== MEMBER 카테고리 처리 =====

    private VoiceCommandResponse handleMemberCategory(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String action = aiResult.getAction();

        if (action == null) {
            return createErrorResponse("회원 명령의 액션을 인식할 수 없습니다.", "INVALID_ACTION");
        }

        return switch (action.toUpperCase()) {
            case "SEARCH" -> handleMemberSearch(aiResult, context);
            case "CREATE" -> handleMemberCreate(aiResult, context);
            case "UPDATE" -> handleMemberUpdate(aiResult, context);
            case "DELETE" -> handleMemberDelete(aiResult, context);
            case "GET_ALL" -> handleMemberGetAll(aiResult, context);
            default -> createErrorResponse("지원하지 않는 회원 액션입니다: " + action, "UNSUPPORTED_ACTION");
        };
    }

    private VoiceCommandResponse handleMemberSearch(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        Map<String, Object> searchCriteria = aiResult.getSearchCriteria();

        // 검색 조건이 전혀 없으면 전체 회원 조회로 처리 (예: "전체 회원 보여줘")
        if (specificMemberId == null && (searchCriteria == null || searchCriteria.isEmpty())) {
            return handleMemberGetAll(aiResult, context);
        }

        List<Member> members = findMembersBySearchCriteria(searchCriteria, specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("조건에 맞는 회원을 찾을 수 없습니다.", Map.of());
        }

        // 중복 체크
        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        Member member = members.get(0);

        // 회원 상세 정보 메시지 구성
        StringBuilder msg = new StringBuilder();
        msg.append(member.getName()).append(" 회원님 정보입니다. ");
        if (member.getMemberNumber() != null) {
            msg.append("회원번호 ").append(member.getMemberNumber()).append(", ");
        }
        if (member.getPhone() != null && !member.getPhone().isEmpty()) {
            msg.append("전화번호 ").append(member.getPhone()).append(", ");
        }
        if (member.getEmail() != null && !member.getEmail().isEmpty()) {
            msg.append("이메일 ").append(member.getEmail()).append(", ");
        }
        if (member.getGrade() != null && !member.getGrade().isEmpty()) {
            msg.append("등급 ").append(member.getGrade());
        }

        // 최신 메모 조회
        Memo latestMemo = null;
        try {
            latestMemo = memoService.getLatestMemoByMemberId(member.getId().toString(), member.getBusinessPlaceId());
            if (latestMemo != null) {
                msg.append(". 최신 메모: ").append(latestMemo.getContent());
            }
        } catch (Exception e) {
            // 메모가 없는 경우 무시
        }

        Map<String, Object> data = new HashMap<>();
        data.put("member", member);
        if (latestMemo != null) {
            data.put("memo", latestMemo);
        }

        return createCompletedResponse(msg.toString().replaceAll(",\\s*$", ""), data);
    }

    private VoiceCommandResponse handleMemberCreate(AiAnalysisResult aiResult, ConversationContextDTO context) {
        Map<String, Object> memberData = aiResult.getMemberData();

        if (memberData == null || memberData.get("name") == null) {
            return createErrorResponse("회원 이름이 필요합니다.", "MISSING_PARAMETER");
        }

        try {
            Member member = new Member();
            member.setName((String) memberData.get("name"));
            member.setPhone((String) memberData.get("phone"));
            member.setEmail((String) memberData.get("email"));
            member.setMemberNumber((String) memberData.get("memberNumber"));
            member.setGrade((String) memberData.get("grade"));
            member.setBusinessPlaceId(context.getBusinessPlaceId());
            // 회원 소유자 설정 (권한 체크용)
            member.setOwnerId(UUID.fromString(context.getRequestUserId()));

            Member created = memberService.createMember(member);

            return createCompletedResponse(
                    created.getName() + " 회원이 등록되었습니다.",
                    Map.of("member", created));
        } catch (Exception e) {
            log.error("Error creating member: {}", e.getMessage(), e);
            return createErrorResponse("회원 등록 중 오류가 발생했습니다: " + e.getMessage(), "CREATE_ERROR");
        }
    }

    private VoiceCommandResponse handleMemberUpdate(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("수정할 회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        Member member = members.get(0);
        Map<String, Object> updateFields = aiResult.getUpdateFields();

        if (updateFields == null || updateFields.isEmpty()) {
            return createErrorResponse("수정할 내용이 없습니다.", "MISSING_PARAMETER");
        }

        // 업데이트 적용
        if (updateFields.containsKey("name")) member.setName((String) updateFields.get("name"));
        if (updateFields.containsKey("phone")) member.setPhone((String) updateFields.get("phone"));
        if (updateFields.containsKey("email")) member.setEmail((String) updateFields.get("email"));
        if (updateFields.containsKey("memberNumber")) member.setMemberNumber((String) updateFields.get("memberNumber"));
        if (updateFields.containsKey("grade")) member.setGrade((String) updateFields.get("grade"));

        try {
            // 권한 체크 후 수정
            Member updated = memberService.updateMemberWithPermission(
                    member.getId().toString(),
                    member,
                    context.getRequestUserId(),
                    context.getBusinessPlaceId()
            );

            String updateMsg = updateFields.entrySet().stream()
                    .map(e -> e.getKey() + ": " + e.getValue())
                    .collect(Collectors.joining(", "));

            return createCompletedResponse(
                    member.getName() + " 회원 정보가 수정되었습니다. (" + updateMsg + ")",
                    Map.of("member", updated));
        } catch (RuntimeException e) {
            log.warn("Permission denied for member update: {}", e.getMessage());
            return createErrorResponse(e.getMessage(), "PERMISSION_DENIED");
        }
    }

    private VoiceCommandResponse handleMemberDelete(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("삭제할 회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        Member member = members.get(0);

        // 확인이 필요한 경우
        if (context.getCurrentStep() == null || !"confirmation".equals(context.getCurrentStep().getStepType())) {
            return createConfirmationResponse(member, "DELETE", context);
        }

        // 권한 체크 후 Soft Delete 실행 (회원의 모든 메모도 함께 soft delete)
        try {
            memberService.softDeleteMember(
                    member.getId().toString(),
                    context.getRequestUserId(),
                    context.getBusinessPlaceId()
            );
            return createCompletedResponse(
                    member.getName() + " 회원과 관련 메모가 삭제 대기 상태로 전환되었습니다.",
                    Map.of("deletedMember", member));
        } catch (RuntimeException e) {
            log.warn("Permission denied for member delete: {}", e.getMessage());
            return createErrorResponse(e.getMessage(), "PERMISSION_DENIED");
        } catch (Exception e) {
            log.error("Error deleting member: {}", e.getMessage(), e);
            return createErrorResponse("회원 삭제 중 오류가 발생했습니다: " + e.getMessage(), "DELETE_ERROR");
        }
    }

    private VoiceCommandResponse handleMemberGetAll(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String businessPlaceId = context.getBusinessPlaceId();
        List<Member> members;

        if (businessPlaceId != null) {
            members = memberService.getMembersByBusinessPlace(businessPlaceId);
        } else {
            members = memberService.getAllMembers(0, 100);
        }

        if (members.isEmpty()) {
            return createCompletedResponse("등록된 회원이 없습니다.", Map.of());
        }

        return createCompletedResponse(
                String.format("총 %d명의 회원이 있습니다.", members.size()),
                Map.of("members", members, "totalCount", members.size()));
    }

    // ===== MEMO 카테고리 처리 =====

    private VoiceCommandResponse handleMemoCategory(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String action = aiResult.getAction();

        if (action == null) {
            return createErrorResponse("메모 명령의 액션을 인식할 수 없습니다.", "INVALID_ACTION");
        }

        return switch (action.toUpperCase()) {
            case "GET_BY_MEMBER" -> handleMemoGetByMember(aiResult, context);
            case "GET_LATEST" -> handleMemoGetLatest(aiResult, context);
            case "CREATE" -> handleMemoCreate(aiResult, context);
            case "UPDATE_LATEST" -> handleMemoUpdateLatest(aiResult, context);
            case "DELETE_LATEST" -> handleMemoDeleteLatest(aiResult, context);
            case "DELETE_ALL" -> handleMemoDeleteAll(aiResult, context);
            default -> createErrorResponse("지원하지 않는 메모 액션입니다: " + action, "UNSUPPORTED_ACTION");
        };
    }

    private VoiceCommandResponse handleMemoGetByMember(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        Member member = members.get(0);
        List<Memo> memos = memoService.getMemosByMemberId(member.getId().toString(), member.getBusinessPlaceId());

        if (memos.isEmpty()) {
            return createCompletedResponse(member.getName() + " 회원의 메모가 없습니다.", Map.of("member", member));
        }

        return createCompletedResponse(
                String.format("%s 회원의 메모 %d개를 찾았습니다.", member.getName(), memos.size()),
                Map.of("member", member, "memos", memos));
    }

    private VoiceCommandResponse handleMemoGetLatest(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        Member member = members.get(0);
        Map<String, Object> data = new HashMap<>();
        data.put("member", member);

        try {
            Memo memo = memoService.getLatestMemoByMemberId(member.getId().toString(), member.getBusinessPlaceId());
            if (memo != null) {
                data.put("memo", memo);
                return createCompletedResponse(memo.getContent(), data);
            } else {
                return createCompletedResponse(member.getName() + " 회원의 메모가 없습니다.", data);
            }
        } catch (Exception e) {
            return createCompletedResponse(member.getName() + " 회원의 메모가 없습니다.", data);
        }
    }

    private VoiceCommandResponse handleMemoCreate(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        String content = aiResult.getContent();
        if (content == null || content.trim().isEmpty()) {
            return createContentInputResponse(members.get(0), aiResult, context, "어떤 내용의 메모를 남길까요?");
        }

        Member member = members.get(0);
        Memo memo = memoService.createMemo(member.getId().toString(), content, context.getRequestUserId());

        return createCompletedResponse(
                member.getName() + " 회원에게 메모를 저장했습니다.",
                Map.of("member", member, "memo", memo));
    }

    private VoiceCommandResponse handleMemoUpdateLatest(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        String content = aiResult.getContent();
        if (content == null || content.trim().isEmpty()) {
            return createErrorResponse("수정할 메모 내용이 필요합니다.", "MISSING_PARAMETER");
        }

        Member member = members.get(0);
        try {
            Memo memo = memoService.getLatestMemoByMemberId(member.getId().toString(), member.getBusinessPlaceId());
            if (memo == null) {
                return createCompletedResponse(member.getName() + " 회원의 메모가 없습니다.", Map.of("member", member));
            }
            memo.setContent(content);
            // 권한 체크 후 수정
            Memo updated = memoService.updateMemoWithPermission(
                    memo.getId().toString(),
                    memo,
                    context.getRequestUserId(),
                    context.getBusinessPlaceId()
            );

            return createCompletedResponse(
                    "메모가 수정되었습니다.",
                    Map.of("member", member, "memo", updated));
        } catch (RuntimeException e) {
            log.warn("Permission denied for memo update: {}", e.getMessage());
            return createErrorResponse(e.getMessage(), "PERMISSION_DENIED");
        } catch (Exception e) {
            return createCompletedResponse(member.getName() + " 회원의 메모가 없습니다.", Map.of("member", member));
        }
    }

    private VoiceCommandResponse handleMemoDeleteLatest(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        Member member = members.get(0);
        try {
            Memo memo = memoService.getLatestMemoByMemberId(member.getId().toString(), member.getBusinessPlaceId());
            if (memo == null) {
                return createCompletedResponse(member.getName() + " 회원의 메모가 없습니다.", Map.of("member", member));
            }
            // 권한 체크 후 Soft Delete
            memoService.softDeleteMemo(
                    memo.getId().toString(),
                    context.getRequestUserId(),
                    context.getBusinessPlaceId()
            );

            return createCompletedResponse(
                    member.getName() + " 회원의 최신 메모가 삭제 대기 상태로 전환되었습니다.",
                    Map.of("member", member, "deletedCount", 1));
        } catch (RuntimeException e) {
            log.warn("Permission denied for memo delete: {}", e.getMessage());
            return createErrorResponse(e.getMessage(), "PERMISSION_DENIED");
        } catch (Exception e) {
            return createCompletedResponse(member.getName() + " 회원의 메모가 없습니다.", Map.of("member", member));
        }
    }

    private VoiceCommandResponse handleMemoDeleteAll(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        Member member = members.get(0);
        List<Memo> memos = memoService.getMemosByMemberId(member.getId().toString(), member.getBusinessPlaceId());

        if (memos.isEmpty()) {
            return createCompletedResponse(member.getName() + " 회원의 메모가 없습니다.", Map.of("member", member));
        }

        int deletedCount = 0;
        int failedCount = 0;
        List<String> failedMessages = new ArrayList<>();

        for (Memo memo : memos) {
            try {
                // 권한 체크 후 Soft Delete
                memoService.softDeleteMemo(
                        memo.getId().toString(),
                        context.getRequestUserId(),
                        context.getBusinessPlaceId()
                );
                deletedCount++;
            } catch (RuntimeException e) {
                log.warn("Permission denied for memo delete (id: {}): {}", memo.getId(), e.getMessage());
                failedCount++;
                if (failedMessages.size() < 3) {
                    failedMessages.add(e.getMessage());
                }
            }
        }

        if (deletedCount == 0 && failedCount > 0) {
            return createErrorResponse("메모 삭제 권한이 없습니다.", "PERMISSION_DENIED");
        }

        String message = String.format("%s 회원의 메모 %d개가 삭제 대기 상태로 전환되었습니다.", member.getName(), deletedCount);
        if (failedCount > 0) {
            message += String.format(" (권한 부족으로 %d개 실패)", failedCount);
        }

        return createCompletedResponse(message, Map.of("member", member, "deletedCount", deletedCount, "failedCount", failedCount));
    }

    // ===== VISIT 카테고리 처리 =====

    private VoiceCommandResponse handleVisitCategory(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String action = aiResult.getAction();

        if (action == null) {
            return createErrorResponse("방문 명령의 액션을 인식할 수 없습니다.", "INVALID_ACTION");
        }

        return switch (action.toUpperCase()) {
            case "CHECKIN" -> handleVisitCheckin(aiResult, context);
            case "GET_BY_MEMBER" -> handleVisitGetByMember(aiResult, context);
            default -> createErrorResponse("지원하지 않는 방문 액션입니다: " + action, "UNSUPPORTED_ACTION");
        };
    }

    private VoiceCommandResponse handleVisitCheckin(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        Member member = members.get(0);
        String note = aiResult.getNote();

        try {
            Visit visit = visitService.checkInWithUserCheck(
                    member.getId().toString(), context.getRequestUserId(), note);

            LocalDateTime kstTime = visit.getVisitedAt().atZone(ZoneId.of("UTC"))
                    .withZoneSameInstant(ZoneId.of("Asia/Seoul")).toLocalDateTime();
            String timeStr = String.format("%d월 %d일 %d시 %d분",
                    kstTime.getMonthValue(), kstTime.getDayOfMonth(),
                    kstTime.getHour(), kstTime.getMinute());

            Map<String, Object> data = new HashMap<>();
            data.put("member", member);
            data.put("visit", visit);

            return createCompletedResponse(
                    member.getName() + " 회원님 " + timeStr + " 방문 체크인 완료되었습니다.", data);
        } catch (Exception e) {
            log.error("Visit checkin failed: {}", e.getMessage(), e);
            return createErrorResponse(
                    member.getName() + " 회원 체크인 처리 중 오류: " + e.getMessage(), "CHECKIN_ERROR");
        }
    }

    private VoiceCommandResponse handleVisitGetByMember(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String specificMemberId = getSelectedMemberId(context);
        List<Member> members = findMembersBySearchCriteria(aiResult.getSearchCriteria(), specificMemberId, context.getBusinessPlaceId(), context.getRequestUserId());

        if (members.isEmpty()) {
            return createCompletedResponse("회원을 찾을 수 없습니다.", Map.of());
        }

        if (members.size() > 1 && specificMemberId == null) {
            return createMemberSelectionResponse(members, aiResult, context);
        }

        Member member = members.get(0);

        try {
            List<Visit> visits = visitService.getVisitsByMemberId(
                    member.getId().toString(), member.getBusinessPlaceId());

            if (visits.isEmpty()) {
                return createCompletedResponse(
                        member.getName() + " 회원의 방문 기록이 없습니다.", Map.of("member", member));
            }

            Map<String, Object> data = new HashMap<>();
            data.put("member", member);
            data.put("visits", visits);

            return createCompletedResponse(
                    String.format("%s 회원의 방문 기록 %d건을 찾았습니다.", member.getName(), visits.size()), data);
        } catch (Exception e) {
            log.error("Visit lookup failed: {}", e.getMessage(), e);
            return createCompletedResponse(
                    member.getName() + " 회원의 방문 기록 조회 중 오류가 발생했습니다.", Map.of("member", member));
        }
    }

    // ===== STATISTICS 카테고리 처리 =====

    private VoiceCommandResponse handleStatisticsCategory(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String action = aiResult.getAction();

        if (action == null) {
            return createErrorResponse("통계 명령의 액션을 인식할 수 없습니다.", "INVALID_ACTION");
        }

        return switch (action.toUpperCase()) {
            case "GET_HOME" -> handleStatisticsGetHome(context);
            case "GET_RECENT_ACTIVITIES" -> handleStatisticsGetRecentActivities(aiResult, context);
            default -> createErrorResponse("지원하지 않는 통계 액션입니다: " + action, "UNSUPPORTED_ACTION");
        };
    }

    private VoiceCommandResponse handleStatisticsGetHome(ConversationContextDTO context) {
        String businessPlaceId = context.getBusinessPlaceId();

        if (businessPlaceId == null) {
            return createErrorResponse("사업장이 설정되지 않았습니다.", "MISSING_BUSINESS_PLACE");
        }

        try {
            Long todayReservations = reservationService.getTodayReservationCount(businessPlaceId);
            List<Member> members = memberService.getMembersByBusinessPlace(businessPlaceId);

            return createCompletedResponse(
                    String.format("오늘 예약은 %d건이고, 등록된 회원은 %d명입니다.", todayReservations, members.size()),
                    Map.of("todayReservations", todayReservations, "totalMembers", members.size()));
        } catch (Exception e) {
            log.error("Error getting home statistics: {}", e.getMessage(), e);
            return createErrorResponse("통계 조회 중 오류가 발생했습니다.", "STATISTICS_ERROR");
        }
    }

    private VoiceCommandResponse handleStatisticsGetRecentActivities(AiAnalysisResult aiResult, ConversationContextDTO context) {
        String businessPlaceId = context.getBusinessPlaceId();

        if (businessPlaceId == null) {
            return createErrorResponse("사업장이 설정되지 않았습니다.", "MISSING_BUSINESS_PLACE");
        }

        Integer limit = aiResult.getLimit();
        if (limit == null) limit = 10;

        // 최근 활동 조회 (최근 메모 기반)
        try {
            List<Member> members = memberService.getMembersByBusinessPlace(businessPlaceId);
            List<Map<String, Object>> recentActivities = new ArrayList<>();

            for (Member member : members) {
                List<Memo> memos = memoService.getMemosByMemberId(member.getId().toString(), member.getBusinessPlaceId());
                for (Memo memo : memos) {
                    Map<String, Object> activity = new HashMap<>();
                    activity.put("memberId", member.getId());
                    activity.put("memberName", member.getName());
                    activity.put("content", memo.getContent());
                    activity.put("createdAt", memo.getCreatedAt());
                    recentActivities.add(activity);
                }
            }

            // 최신순 정렬 후 제한
            recentActivities.sort((a, b) -> {
                LocalDateTime timeA = (LocalDateTime) a.get("createdAt");
                LocalDateTime timeB = (LocalDateTime) b.get("createdAt");
                return timeB.compareTo(timeA);
            });

            if (recentActivities.size() > limit) {
                recentActivities = recentActivities.subList(0, limit);
            }

            return createCompletedResponse(
                    String.format("최근 활동 %d건입니다.", recentActivities.size()),
                    Map.of("activities", recentActivities));
        } catch (Exception e) {
            log.error("Error getting recent activities: {}", e.getMessage(), e);
            return createErrorResponse("최근 활동 조회 중 오류가 발생했습니다.", "STATISTICS_ERROR");
        }
    }

    // ===== 대화 이어서 처리 =====

    private VoiceCommandResponse processContinuedConversationInternal(VoiceCommandRequest request, String businessPlaceId) {
        ConversationContextDTO context = request.getContext();
        ConversationStep currentStep = context.getCurrentStep();

        // 신뢰 가능한 유일 입력은 JWT userId. 클라이언트가 보낸 context의 인가 정보는 서버 값으로 재설정한다.
        String userId = request.getUserId();
        context.setRequestUserId(userId);

        // 이미 선택된 회원이 있으면 그 회원의 실제 사업장을 서버에서 도출해 인가 검증한다.
        // (클라이언트가 보낸 businessPlaceId/회원 UUID를 인가 근거로 신뢰하지 않는다.)
        String selectedMemberId = getSelectedMemberId(context);
        if (selectedMemberId != null) {
            Member member = memberService.getMemberByIdWithUserCheck(selectedMemberId, userId);
            context.setBusinessPlaceId(member.getBusinessPlaceId());
        } else {
            context.setBusinessPlaceId(businessPlaceId);
            if (businessPlaceId != null) {
                accessControlService.requireApprovedMembership(userId, businessPlaceId);
            }
        }

        return switch (currentStep.getStepType()) {
            case "member_selection" -> handleMemberSelection(request, context);
            case "memo_selection" -> handleMemoSelection(request, context);
            case "content_input" -> handleContentInput(request, context);
            case "confirmation" -> handleConfirmation(request, context);
            default -> createErrorResponse("알 수 없는 대화 단계입니다.", "UNKNOWN_STEP");
        };
    }

    private VoiceCommandResponse handleMemberSelection(VoiceCommandRequest request, ConversationContextDTO context) {
        List<String> selectedIds = extractSelectedIds(request.getText(), context);

        if (selectedIds.isEmpty()) {
            return VoiceCommandResponse.builder()
                    .status("clarification_needed")
                    .message("선택한 회원을 찾을 수 없습니다. 다시 선택해주세요.")
                    .context(context)
                    .build();
        }

        SelectedEntity selectedMember = SelectedEntity.builder()
                .entityType("member")
                .ids(selectedIds)
                .selectAll(false)
                .build();

        context.addSelectedEntity(selectedMember);

        Map<String, Object> originalIntent = context.getOriginalIntent();
        return executeWithOriginalIntent(originalIntent, context);
    }

    private VoiceCommandResponse handleMemoSelection(VoiceCommandRequest request, ConversationContextDTO context) {
        String text = request.getText().toLowerCase();
        boolean selectAll = text.contains("전체") || text.contains("모두") || text.contains("다");

        SelectedEntity selectedMemo;
        if (selectAll) {
            selectedMemo = SelectedEntity.builder()
                    .entityType("memo")
                    .ids(new ArrayList<>())
                    .selectAll(true)
                    .build();
        } else {
            List<String> selectedIds = extractSelectedIds(request.getText(), context);
            if (selectedIds.isEmpty()) {
                return VoiceCommandResponse.builder()
                        .status("clarification_needed")
                        .message("선택한 메모를 찾을 수 없습니다. 다시 선택해주세요.")
                        .context(context)
                        .build();
            }
            selectedMemo = SelectedEntity.builder()
                    .entityType("memo")
                    .ids(selectedIds)
                    .selectAll(false)
                    .build();
        }

        context.addSelectedEntity(selectedMemo);

        Map<String, Object> originalIntent = context.getOriginalIntent();
        return executeWithOriginalIntent(originalIntent, context);
    }

    private VoiceCommandResponse handleContentInput(VoiceCommandRequest request, ConversationContextDTO context) {
        String inputText = request.getText();
        if (inputText == null || inputText.trim().isEmpty()) {
            return VoiceCommandResponse.builder()
                    .status("clarification_needed")
                    .message("내용을 말씀해주세요.")
                    .context(context)
                    .build();
        }

        Map<String, Object> originalIntent = context.getOriginalIntent();
        if (originalIntent == null) {
            return createErrorResponse("원래 명령 정보를 찾을 수 없습니다.", "MISSING_INTENT");
        }

        @SuppressWarnings("unchecked")
        Map<String, Object> parameters = (Map<String, Object>) originalIntent.get("parameters");
        if (parameters == null) {
            parameters = new HashMap<>();
            originalIntent.put("parameters", parameters);
        }
        parameters.put("content", inputText.trim());

        return executeWithOriginalIntent(originalIntent, context);
    }

    private VoiceCommandResponse handleConfirmation(VoiceCommandRequest request, ConversationContextDTO context) {
        String text = request.getText().toLowerCase();

        boolean confirmed = text.contains("예") || text.contains("네") ||
                text.contains("확인") || text.contains("ok") ||
                text.contains("yes") || text.contains("응") ||
                text.contains("맞") || text.contains("좋");

        if (!confirmed) {
            return createCompletedResponse("작업이 취소되었습니다.", Map.of());
        }

        Map<String, Object> originalIntent = context.getOriginalIntent();
        return executeWithOriginalIntent(originalIntent, context);
    }

    private VoiceCommandResponse executeWithOriginalIntent(Map<String, Object> originalIntent, ConversationContextDTO context) {
        if (originalIntent == null) {
            return createErrorResponse("원래 명령 정보를 찾을 수 없습니다.", "MISSING_INTENT");
        }

        String category = (String) originalIntent.get("category");
        String action = (String) originalIntent.get("action");

        AiAnalysisResult aiResult = new AiAnalysisResult();
        aiResult.setCategory(category);
        aiResult.setAction(action);

        @SuppressWarnings("unchecked")
        Map<String, Object> parameters = (Map<String, Object>) originalIntent.get("parameters");
        aiResult.setParameters(parameters);

        return routeByCategory(aiResult, context);
    }

    // ===== Helper Methods =====

    private List<Member> findMembersBySearchCriteria(Map<String, Object> searchCriteria, String specificMemberId, String businessPlaceId, String userId) {
        // 이미 선택된 회원이 있는 경우 (사용자 권한 체크 포함 조회로 크로스테넌트 접근 차단)
        if (specificMemberId != null && !specificMemberId.isEmpty()) {
            try {
                Member member = memberService.getMemberByIdWithUserCheck(specificMemberId, userId);
                return Collections.singletonList(member);
            } catch (Exception e) {
                return Collections.emptyList();
            }
        }

        if (searchCriteria == null || searchCriteria.isEmpty()) {
            return Collections.emptyList();
        }

        // AI가 placeholder("MISSING_PARAMETER")나 빈 값을 채운 경우 제거 (잘못된 조회 방지)
        String memberNumber = sanitizeCriteria((String) searchCriteria.get("memberNumber"));
        String name = sanitizeCriteria((String) searchCriteria.get("name"));
        String phone = sanitizeCriteria((String) searchCriteria.get("phone"));
        String email = sanitizeCriteria((String) searchCriteria.get("email"));

        // 유효한 조건이 하나도 없으면 빈 결과 반환
        // (searchMembers는 조건이 전부 비면 사업장 전체 회원을 반환하므로, 수정·삭제 오작동을 막기 위해 차단)
        if (memberNumber == null && name == null && phone == null && email == null) {
            return Collections.emptyList();
        }

        // 회원번호로 검색
        if (memberNumber != null) {
            List<Member> members = memberService.getMembersByNumber(memberNumber, businessPlaceId);
            // 이름도 있으면 추가 필터링
            if (name != null) {
                members = members.stream()
                        .filter(m -> m.getName().contains(name))
                        .collect(Collectors.toList());
            }
            return members;
        }

        // 이름, 전화번호, 이메일로 검색
        return memberService.searchMembers(null, name, phone, email, businessPlaceId);
    }

    /**
     * AI가 채운 검색 조건 값을 정규화한다.
     * 공백이거나 placeholder("MISSING_PARAMETER")이면 null로 처리해 잘못된 조회를 막는다.
     */
    private String sanitizeCriteria(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.isEmpty() || "MISSING_PARAMETER".equalsIgnoreCase(trimmed)) {
            return null;
        }
        return trimmed;
    }

    private String getSelectedMemberId(ConversationContextDTO context) {
        if (context == null) return null;

        SelectedEntity memberEntity = context.getSelectedEntityByType("member");
        if (memberEntity != null && !memberEntity.getIds().isEmpty()) {
            return memberEntity.getIds().get(0);
        }

        return null;
    }

    private List<String> extractSelectedIds(String text, ConversationContextDTO context) {
        // UUID 형식이면 직접 반환
        if (text.matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")) {
            return Collections.singletonList(text);
        }

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> candidates = (List<Map<String, Object>>) context.getAdditionalData().get("candidates");

        if (candidates == null || candidates.isEmpty()) {
            return Collections.emptyList();
        }

        return candidates.stream()
                .filter(candidate -> {
                    String name = (String) candidate.get("name");
                    String content = (String) candidate.get("content");
                    return (name != null && text.contains(name)) ||
                            (content != null && text.contains(content));
                })
                .map(candidate -> (String) candidate.get("id"))
                .collect(Collectors.toList());
    }

    private VoiceCommandResponse createMemberSelectionResponse(List<Member> members, AiAnalysisResult aiResult, ConversationContextDTO existingContext) {
        String conversationId = UUID.randomUUID().toString();

        List<Map<String, Object>> candidates = members.stream()
                .map(member -> {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id", member.getId().toString());
                    map.put("memberNumber", member.getMemberNumber());
                    map.put("name", member.getName());
                    map.put("phone", member.getPhone());
                    map.put("email", member.getEmail());
                    return map;
                })
                .collect(Collectors.toList());

        Map<String, Object> originalIntent = new HashMap<>();
        originalIntent.put("category", aiResult.getCategory());
        originalIntent.put("action", aiResult.getAction());
        originalIntent.put("parameters", aiResult.getParameters());

        ConversationStep step = ConversationStep.builder()
                .stepType("member_selection")
                .stepNumber(1)
                .targetEntityType("member")
                .allowMultipleSelection(false)
                .allowSelectAll(false)
                .build();

        Map<String, Object> additionalData = new HashMap<>();
        additionalData.put("candidates", candidates);

        ConversationContextDTO context = ConversationContextDTO.builder()
                .conversationId(conversationId)
                .businessPlaceId(existingContext != null ? existingContext.getBusinessPlaceId() : null)
                .requestUserId(existingContext != null ? existingContext.getRequestUserId() : null)
                .originalIntent(originalIntent)
                .currentStep(step)
                .additionalData(additionalData)
                .build();

        // 검색 키워드 생성
        String searchKeyword = buildSearchKeyword(aiResult.getSearchCriteria());

        return VoiceCommandResponse.builder()
                .status("clarification_needed")
                .conversationId(conversationId)
                .message(String.format("%s 회원이 %d명 있습니다. 어떤 회원을 선택하시겠습니까?", searchKeyword, members.size()))
                .data(Map.of("candidates", candidates, "searchKeyword", searchKeyword))
                .selectionOptions(VoiceCommandResponse.SelectionOptions.builder()
                        .allowMultipleSelection(false)
                        .allowSelectAll(false)
                        .targetEntityType("member")
                        .build())
                .context(context)
                .build();
    }

    private String buildSearchKeyword(Map<String, Object> searchCriteria) {
        if (searchCriteria == null) return "";

        List<String> keywords = new ArrayList<>();
        if (searchCriteria.get("memberNumber") != null) {
            keywords.add(searchCriteria.get("memberNumber") + "번");
        }
        if (searchCriteria.get("name") != null) {
            keywords.add((String) searchCriteria.get("name"));
        }
        if (searchCriteria.get("phone") != null) {
            keywords.add((String) searchCriteria.get("phone"));
        }

        return String.join(" ", keywords);
    }

    private VoiceCommandResponse createContentInputResponse(Member member, AiAnalysisResult aiResult, ConversationContextDTO existingContext, String promptMessage) {
        String conversationId = UUID.randomUUID().toString();

        Map<String, Object> originalIntent = new HashMap<>();
        originalIntent.put("category", aiResult.getCategory());
        originalIntent.put("action", aiResult.getAction());
        originalIntent.put("parameters", aiResult.getParameters() != null ? aiResult.getParameters() : new HashMap<>());

        ConversationStep step = ConversationStep.builder()
                .stepType("content_input")
                .stepNumber(1)
                .targetEntityType("content")
                .build();

        Map<String, Object> additionalData = new HashMap<>();
        additionalData.put("memberId", member.getId().toString());
        additionalData.put("memberName", member.getName());

        ConversationContextDTO context = ConversationContextDTO.builder()
                .conversationId(conversationId)
                .businessPlaceId(existingContext != null ? existingContext.getBusinessPlaceId() : null)
                .requestUserId(existingContext != null ? existingContext.getRequestUserId() : null)
                .originalIntent(originalIntent)
                .currentStep(step)
                .additionalData(additionalData)
                .selectedEntities(existingContext != null ? existingContext.getSelectedEntities() : new ArrayList<>())
                .build();

        return VoiceCommandResponse.builder()
                .status("clarification_needed")
                .conversationId(conversationId)
                .message(member.getName() + " 회원님에게 " + promptMessage)
                .context(context)
                .build();
    }

    private VoiceCommandResponse createConfirmationResponse(Member member, String action, ConversationContextDTO existingContext) {
        String conversationId = UUID.randomUUID().toString();

        Map<String, Object> originalIntent = new HashMap<>();
        originalIntent.put("category", "MEMBER");
        originalIntent.put("action", action);
        Map<String, Object> params = new HashMap<>();
        params.put("searchCriteria", Map.of("memberNumber", member.getMemberNumber()));
        originalIntent.put("parameters", params);

        ConversationStep step = ConversationStep.builder()
                .stepType("confirmation")
                .stepNumber(2)
                .targetEntityType("confirmation")
                .allowMultipleSelection(false)
                .allowSelectAll(false)
                .build();

        SelectedEntity memberEntity = SelectedEntity.builder()
                .entityType("member")
                .ids(Collections.singletonList(member.getId().toString()))
                .selectAll(false)
                .build();

        ConversationContextDTO context = ConversationContextDTO.builder()
                .conversationId(conversationId)
                .businessPlaceId(existingContext != null ? existingContext.getBusinessPlaceId() : null)
                .requestUserId(existingContext != null ? existingContext.getRequestUserId() : null)
                .originalIntent(originalIntent)
                .selectedEntities(new ArrayList<>(Collections.singletonList(memberEntity)))
                .currentStep(step)
                .build();

        String confirmMessage;
        if ("DELETE".equals(action)) {
            confirmMessage = String.format("%s 회원을 삭제 대기 상태로 전환하시겠습니까? 회원의 모든 메모도 함께 삭제 대기됩니다. (예/아니오)", member.getName());
        } else {
            confirmMessage = String.format("%s 회원에 대한 작업을 진행하시겠습니까? (예/아니오)", member.getName());
        }

        return VoiceCommandResponse.builder()
                .status("clarification_needed")
                .conversationId(conversationId)
                .message(confirmMessage)
                .data(Map.of("member", member))
                .selectionOptions(VoiceCommandResponse.SelectionOptions.builder()
                        .allowMultipleSelection(false)
                        .allowSelectAll(false)
                        .targetEntityType("confirmation")
                        .build())
                .context(context)
                .build();
    }

    private VoiceCommandResponse createCompletedResponse(String message, Map<String, Object> data) {
        return VoiceCommandResponse.builder()
                .status("completed")
                .message(message)
                .data(data)
                .build();
    }

    private VoiceCommandResponse createErrorResponse(String message, String errorCode) {
        return VoiceCommandResponse.builder()
                .status("error")
                .message(message)
                .errorCode(errorCode)
                .build();
    }

    /**
     * 일일 브리핑 생성
     */
    public VoiceCommandResponse generateDailyBriefing(String userId, String businessPlaceId) {
        try {
            StringBuilder briefing = new StringBuilder();
            Map<String, Object> data = new HashMap<>();

            briefing.append("안녕하세요! 오늘의 브리핑을 시작하겠습니다.\n\n");

            Long todayReservations = 0L;
            if (businessPlaceId != null) {
                todayReservations = reservationService.getTodayReservationCount(businessPlaceId);
            }
            briefing.append(String.format("오늘 예약은 총 %d건입니다.\n", todayReservations));
            data.put("todayReservations", todayReservations);

            List<Memo> importantMemos = new ArrayList<>();
            if (businessPlaceId != null) {
                List<Member> members = memberService.getMembersByBusinessPlace(businessPlaceId);
                for (Member member : members) {
                    List<Memo> memberMemos = memoService.getMemosByMemberId(member.getId().toString(), member.getBusinessPlaceId());
                    importantMemos.addAll(memberMemos.stream()
                            .filter(Memo::getIsImportant)
                            .collect(Collectors.toList()));
                }
            } else {
                List<Member> allMembers = memberService.getAllMembers(0, 1000);
                for (Member member : allMembers) {
                    List<Memo> memberMemos = memoService.getMemosByMemberId(member.getId().toString(), member.getBusinessPlaceId());
                    importantMemos.addAll(memberMemos.stream()
                            .filter(Memo::getIsImportant)
                            .collect(Collectors.toList()));
                }
            }

            int importantMemoCount = importantMemos.size();
            briefing.append(String.format("확인이 필요한 중요 메모는 %d개입니다.\n", importantMemoCount));
            data.put("importantMemoCount", importantMemoCount);

            if (importantMemoCount > 0) {
                briefing.append("\n주요 메모 내용:\n");
                List<Memo> topMemos = importantMemos.stream()
                        .sorted(Comparator.comparing(Memo::getCreatedAt).reversed())
                        .limit(3)
                        .collect(Collectors.toList());

                List<Map<String, Object>> memoPreview = new ArrayList<>();
                for (int i = 0; i < topMemos.size(); i++) {
                    Memo memo = topMemos.get(i);
                    Member member = memberService.getMemberById(memo.getMemberId().toString());
                    String previewText = memo.getContent().length() > 30
                            ? memo.getContent().substring(0, 30) + "..."
                            : memo.getContent();
                    briefing.append(String.format("%d. %s님: %s\n",
                            i + 1,
                            member != null ? member.getName() : "알 수 없음",
                            previewText));

                    Map<String, Object> memoInfo = new HashMap<>();
                    memoInfo.put("memoId", memo.getId());
                    memoInfo.put("memberId", memo.getMemberId());
                    memoInfo.put("memberName", member != null ? member.getName() : "알 수 없음");
                    memoInfo.put("content", memo.getContent());
                    memoInfo.put("createdAt", memo.getCreatedAt());
                    memoPreview.add(memoInfo);
                }
                data.put("topImportantMemos", memoPreview);
            }

            briefing.append("\n오늘도 좋은 하루 되세요!");

            return VoiceCommandResponse.builder()
                    .status("completed")
                    .message(briefing.toString())
                    .data(data)
                    .build();

        } catch (Exception e) {
            log.error("Error generating daily briefing: {}", e.getMessage(), e);
            return createErrorResponse("브리핑 생성 중 오류가 발생했습니다.", "BRIEFING_ERROR");
        }
    }
}
