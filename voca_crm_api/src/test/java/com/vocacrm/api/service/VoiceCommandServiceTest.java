package com.vocacrm.api.service;

import com.vocacrm.api.dto.AiAnalysisResult;
import com.vocacrm.api.dto.ConversationContextDTO;
import com.vocacrm.api.dto.ConversationStep;
import com.vocacrm.api.dto.SelectedEntity;
import com.vocacrm.api.dto.VoiceCommandRequest;
import com.vocacrm.api.dto.VoiceCommandResponse;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Memo;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.Visit;
import com.vocacrm.api.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * VoiceCommandService 순수 단위 테스트 (Spring Context 미로딩, 의존성 전부 Mockito 모킹)
 *
 * 검증 대상:
 * - processContinuedConversation: 크로스테넌트 IDOR 인가 검증 흐름
 * - processMultipleActions: 멀티액션 clarification/error 승격 흐름 (public 진입점 processNewCommand 경유)
 */
@ExtendWith(MockitoExtension.class)
class VoiceCommandServiceTest {

    @Mock
    private AiServerClient aiServerClient;
    @Mock
    private MemberService memberService;
    @Mock
    private MemoService memoService;
    @Mock
    private VisitService visitService;
    @Mock
    private ReservationService reservationService;
    @Mock
    private AccessControlService accessControlService;
    @Mock
    private UserRepository userRepository;

    private VoiceCommandService voiceCommandService;

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String MEMBER_ID = "11111111-2222-3333-4444-555555555555";
    private static final String MEMBER_ID_2 = "66666666-7777-8888-9999-aaaaaaaaaaaa";
    private static final String BUSINESS_PLACE_ID = "ABC1234";
    private static final String OTHER_BUSINESS_PLACE_ID = "ZZZ9999";

    @BeforeEach
    void setUp() {
        voiceCommandService = new VoiceCommandService(
                aiServerClient,
                memberService,
                memoService,
                visitService,
                reservationService,
                accessControlService,
                userRepository
        );
    }

    // ===== [A] processContinuedConversation - 크로스테넌트 IDOR 인가 검증 =====

    @Test
    void continue_선택된_회원이_요청자_권한_사업장_소속이면_정상_처리된다() {
        // 이미 선택된 회원이 있는 컨텍스트. getMemberByIdWithUserCheck가 정상 회원을 반환 = 권한 있음.
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));
        when(memberService.getMemberByIdWithUserCheck(MEMBER_ID, USER_ID)).thenReturn(member);

        VoiceCommandRequest request = continueRequest("아니오", contextWithSelectedMember("confirmation"));

        VoiceCommandResponse response = voiceCommandService.processContinuedConversation(request);

        assertThat(response.getStatus()).isEqualTo("completed");
        verify(memberService).getMemberByIdWithUserCheck(MEMBER_ID, USER_ID);
        verify(accessControlService, never()).requireApprovedMembership(anyString(), anyString());
    }

    @Test
    void continue_선택된_회원이_타사업장_소속이면_AccessDeniedException이_전파된다() {
        // getMemberByIdWithUserCheck가 권한 예외를 던지는 케이스 = 요청자에게 APPROVED 멤버십 없는 회원.
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));
        when(memberService.getMemberByIdWithUserCheck(MEMBER_ID, USER_ID))
                .thenThrow(new AccessDeniedException("해당 회원에 대한 접근 권한이 없습니다."));

        VoiceCommandRequest request = continueRequest("아니오", contextWithSelectedMember("confirmation"));

        assertThatThrownBy(() -> voiceCommandService.processContinuedConversation(request))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void continue_선택된_회원없이_사업장만_있고_APPROVED면_requireApprovedMembership을_호출하고_정상처리한다() {
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));
        // requireApprovedMembership는 예외 없이 통과 (APPROVED).

        VoiceCommandRequest request = continueRequest("아니오", contextWithoutSelectedMember("confirmation"));

        VoiceCommandResponse response = voiceCommandService.processContinuedConversation(request);

        assertThat(response.getStatus()).isEqualTo("completed");
        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
        verify(memberService, never()).getMemberByIdWithUserCheck(anyString(), anyString());
    }

    @Test
    void continue_선택된_회원없이_사업장_비APPROVED면_AccessDeniedException이_전파된다() {
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(OTHER_BUSINESS_PLACE_ID).build()));
        doThrow(new AccessDeniedException("해당 사업장에 대한 접근 권한이 없습니다."))
                .when(accessControlService).requireApprovedMembership(USER_ID, OTHER_BUSINESS_PLACE_ID);

        VoiceCommandRequest request = continueRequest("아니오", contextWithoutSelectedMember("confirmation"));

        assertThatThrownBy(() -> voiceCommandService.processContinuedConversation(request))
                .isInstanceOf(AccessDeniedException.class);
        verify(accessControlService).requireApprovedMembership(USER_ID, OTHER_BUSINESS_PLACE_ID);
    }

    // ===== [B] processMultipleActions - 멀티액션 clarification/error 승격 =====

    @Test
    void multiAction_한_스텝이_clarification이면_그대로_반환하고_이후_스텝은_실행되지_않는다() {
        stubDefaultBusinessPlace();
        // 스텝1: MEMBER DELETE → 단일 회원 매칭 후 confirmation 요구 = clarification_needed.
        AiAnalysisResult delete = aiResult("MEMBER", "DELETE",
                Map.of("searchCriteria", Map.of("name", "홍길동")));
        // 스텝2: MEMBER GET_ALL → 실행되면 getMembersByBusinessPlace 호출됨.
        AiAnalysisResult getAll = aiResult("MEMBER", "GET_ALL", Map.of());
        when(aiServerClient.analyzeCommand("홍길동 삭제하고 전체 회원 보여줘"))
                .thenReturn(List.of(delete, getAll));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID)));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(
                newCommandRequest("홍길동 삭제하고 전체 회원 보여줘"));

        assertThat(response.getStatus()).isEqualTo("clarification_needed");
        assertThat(response.getContext()).isNotNull();
        verify(memberService, never()).getMembersByBusinessPlace(anyString());
    }

    @Test
    void multiAction_한_스텝이_error면_최종상태가_error로_승격되고_errorCode가_전달된다() {
        stubDefaultBusinessPlace();
        // 스텝1: ERROR(MISSING_PARAMETER) → error 승격, errorCode 전달.
        AiAnalysisResult error = aiResult("ERROR", "MISSING_PARAMETER", Map.of());
        // 스텝2: 정상 completed.
        AiAnalysisResult getAll = aiResult("MEMBER", "GET_ALL", Map.of());
        when(aiServerClient.analyzeCommand("잘못된 명령 그리고 전체 회원"))
                .thenReturn(List.of(error, getAll));
        when(memberService.getMembersByBusinessPlace(BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID)));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(
                newCommandRequest("잘못된 명령 그리고 전체 회원"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("MISSING_PARAMETER");
    }

    @Test
    void multiAction_모든_스텝이_completed면_최종상태가_completed다() {
        stubDefaultBusinessPlace();
        AiAnalysisResult getAll1 = aiResult("MEMBER", "GET_ALL", Map.of());
        AiAnalysisResult getAll2 = aiResult("MEMBER", "GET_ALL", Map.of());
        when(aiServerClient.analyzeCommand("전체 회원 보여주고 또 전체 회원"))
                .thenReturn(List.of(getAll1, getAll2));
        when(memberService.getMembersByBusinessPlace(BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID)));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(
                newCommandRequest("전체 회원 보여주고 또 전체 회원"));

        assertThat(response.getStatus()).isEqualTo("completed");
    }

    // ===== [C] MEMBER 카테고리 라우팅 =====

    @Test
    void member_search_결과0건이면_회원을_찾을수없다는_completed를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("홍길동 검색"))
                .thenReturn(List.of(aiResult("MEMBER", "SEARCH", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of());

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 검색"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("찾을 수 없습니다");
    }

    @Test
    void member_search_결과1건이면_상세정보와_최신메모를_담아_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        member.setPhone("010-1234-5678");
        member.setGrade("VIP");
        when(aiServerClient.analyzeCommand("홍길동 검색"))
                .thenReturn(List.of(aiResult("MEMBER", "SEARCH", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memoService.getLatestMemoByMemberId(MEMBER_ID, BUSINESS_PLACE_ID))
                .thenReturn(buildMemo("최근 상담 내용"));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 검색"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("홍길동");
        assertThat(response.getMessage()).contains("최근 상담 내용");
    }

    @Test
    void member_search_결과다수면_회원선택_clarification을_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("홍길동 검색"))
                .thenReturn(List.of(aiResult("MEMBER", "SEARCH", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(
                        buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID),
                        buildMember(MEMBER_ID_2, "홍길동", "1002", BUSINESS_PLACE_ID)));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 검색"));

        assertThat(response.getStatus()).isEqualTo("clarification_needed");
        assertThat(response.getContext()).isNotNull();
        assertThat(response.getContext().getCurrentStep().getStepType()).isEqualTo("member_selection");
    }

    @Test
    void member_search_회원번호조건이면_getMembersByNumber로_조회한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("1001번 회원"))
                .thenReturn(List.of(aiResult("MEMBER", "SEARCH", Map.of("searchCriteria", Map.of("memberNumber", "1001")))));
        when(memberService.getMembersByNumber("1001", BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID)));
        when(memoService.getLatestMemoByMemberId(MEMBER_ID, BUSINESS_PLACE_ID)).thenReturn(null);

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("1001번 회원"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("홍길동");
    }

    @Test
    void member_create_이름있으면_회원을_생성하고_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member created = buildMember(MEMBER_ID, "김철수", "2002", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("김철수 등록"))
                .thenReturn(List.of(aiResult("MEMBER", "CREATE", Map.of("memberData", Map.of("name", "김철수")))));
        when(memberService.createMember(org.mockito.ArgumentMatchers.any(Member.class))).thenReturn(created);

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("김철수 등록"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("김철수");
    }

    @Test
    void member_create_이름없으면_MISSING_PARAMETER_error를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("회원 등록"))
                .thenReturn(List.of(aiResult("MEMBER", "CREATE", Map.of())));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("회원 등록"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("MISSING_PARAMETER");
    }

    @Test
    void member_update_대상1건이고_수정필드있으면_수정하고_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 등급 VIP로"))
                .thenReturn(List.of(aiResult("MEMBER", "UPDATE", Map.of(
                        "searchCriteria", Map.of("name", "홍길동"),
                        "updateFields", Map.of("grade", "VIP")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memberService.updateMemberWithPermission(MEMBER_ID, member, USER_ID, BUSINESS_PLACE_ID))
                .thenReturn(member);

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 등급 VIP로"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("수정");
    }

    @Test
    void member_update_수정필드없으면_MISSING_PARAMETER_error를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("홍길동 수정"))
                .thenReturn(List.of(aiResult("MEMBER", "UPDATE", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID)));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 수정"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("MISSING_PARAMETER");
    }

    @Test
    void member_delete_단일회원이고_확인전이면_confirmation_clarification을_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("홍길동 삭제"))
                .thenReturn(List.of(aiResult("MEMBER", "DELETE", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID)));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 삭제"));

        assertThat(response.getStatus()).isEqualTo("clarification_needed");
        assertThat(response.getMessage()).contains("삭제");
        assertThat(response.getContext().getCurrentStep().getStepType()).isEqualTo("confirmation");
    }

    @Test
    void member_getAll_회원없으면_등록된_회원이_없다는_completed를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("전체 회원"))
                .thenReturn(List.of(aiResult("MEMBER", "GET_ALL", Map.of())));
        when(memberService.getMembersByBusinessPlace(BUSINESS_PLACE_ID)).thenReturn(List.of());

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("전체 회원"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("등록된 회원이 없습니다");
    }

    @Test
    void member_getAll_사업장없으면_전역조회하지_않고_거부한다() {
        // WB-04: 사업장 미지정 시 전역(getAllMembers) 폴백은 타 사업장 회원 노출(테넌트 격리 위반) → 거부
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText("전체 회원");
        when(aiServerClient.analyzeCommand("전체 회원"))
                .thenReturn(List.of(aiResult("MEMBER", "GET_ALL", Map.of())));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(request);

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("NO_BUSINESS_PLACE");
    }

    // ===== [D] MEMO 카테고리 라우팅 =====

    @Test
    void memo_getByMember_메모있으면_개수를_담아_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 메모"))
                .thenReturn(List.of(aiResult("MEMO", "GET_BY_MEMBER", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memoService.getMemosByMemberId(MEMBER_ID, BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMemo("메모1"), buildMemo("메모2")));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 메모"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("2개");
    }

    @Test
    void memo_getByMember_메모없으면_메모가_없다는_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 메모"))
                .thenReturn(List.of(aiResult("MEMO", "GET_BY_MEMBER", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memoService.getMemosByMemberId(MEMBER_ID, BUSINESS_PLACE_ID)).thenReturn(List.of());

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 메모"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("메모가 없습니다");
    }

    @Test
    void memo_getLatest_최신메모있으면_내용을_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 최신 메모"))
                .thenReturn(List.of(aiResult("MEMO", "GET_LATEST", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memoService.getLatestMemoByMemberId(MEMBER_ID, BUSINESS_PLACE_ID))
                .thenReturn(buildMemo("가장 최근 메모"));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 최신 메모"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).isEqualTo("가장 최근 메모");
    }

    @Test
    void memo_getLatest_메모없으면_메모가_없다는_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 최신 메모"))
                .thenReturn(List.of(aiResult("MEMO", "GET_LATEST", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memoService.getLatestMemoByMemberId(MEMBER_ID, BUSINESS_PLACE_ID)).thenReturn(null);

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 최신 메모"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("메모가 없습니다");
    }

    @Test
    void memo_create_내용있으면_메모를_저장하고_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 메모 남겨"))
                .thenReturn(List.of(aiResult("MEMO", "CREATE", Map.of(
                        "searchCriteria", Map.of("name", "홍길동"),
                        "content", "상담 완료"))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memoService.createMemo(MEMBER_ID, "상담 완료", USER_ID)).thenReturn(buildMemo("상담 완료"));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 메모 남겨"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("메모를 저장");
    }

    @Test
    void memo_create_내용없으면_content_input_clarification을_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 메모"))
                .thenReturn(List.of(aiResult("MEMO", "CREATE", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 메모"));

        assertThat(response.getStatus()).isEqualTo("clarification_needed");
        assertThat(response.getContext().getCurrentStep().getStepType()).isEqualTo("content_input");
    }

    @Test
    void memo_updateLatest_내용과_기존메모있으면_수정하고_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        Memo memo = buildMemo("이전 내용");
        when(aiServerClient.analyzeCommand("홍길동 메모 수정"))
                .thenReturn(List.of(aiResult("MEMO", "UPDATE_LATEST", Map.of(
                        "searchCriteria", Map.of("name", "홍길동"),
                        "content", "새 내용"))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memoService.getLatestMemoByMemberId(MEMBER_ID, BUSINESS_PLACE_ID)).thenReturn(memo);
        when(memoService.updateMemoWithPermission(memo.getId().toString(), memo, USER_ID, BUSINESS_PLACE_ID))
                .thenReturn(memo);

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 메모 수정"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("수정");
    }

    @Test
    void memo_updateLatest_내용없으면_MISSING_PARAMETER_error를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("홍길동 메모 수정"))
                .thenReturn(List.of(aiResult("MEMO", "UPDATE_LATEST", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID)));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 메모 수정"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("MISSING_PARAMETER");
    }

    @Test
    void memo_deleteLatest_기존메모있으면_soft_delete하고_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        Memo memo = buildMemo("삭제 대상");
        when(aiServerClient.analyzeCommand("홍길동 최신 메모 삭제"))
                .thenReturn(List.of(aiResult("MEMO", "DELETE_LATEST", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memoService.getLatestMemoByMemberId(MEMBER_ID, BUSINESS_PLACE_ID)).thenReturn(memo);

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 최신 메모 삭제"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("삭제 대기");
        verify(memoService).softDeleteMemo(memo.getId().toString(), USER_ID, BUSINESS_PLACE_ID);
    }

    @Test
    void memo_deleteAll_메모여러개면_모두_soft_delete하고_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 메모 전체 삭제"))
                .thenReturn(List.of(aiResult("MEMO", "DELETE_ALL", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(memoService.getMemosByMemberId(MEMBER_ID, BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMemo("메모1"), buildMemo("메모2")));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 메모 전체 삭제"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("2개");
    }

    // ===== [E] VISIT 카테고리 라우팅 =====

    @Test
    void visit_checkin_성공하면_체크인_완료_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        Visit visit = buildVisit();
        when(aiServerClient.analyzeCommand("홍길동 체크인"))
                .thenReturn(List.of(aiResult("VISIT", "CHECKIN", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(visitService.checkInWithUserCheck(MEMBER_ID, USER_ID, null)).thenReturn(visit);

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 체크인"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("체크인 완료");
    }

    @Test
    void visit_getByMember_방문기록있으면_건수를_담아_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 방문 기록"))
                .thenReturn(List.of(aiResult("VISIT", "GET_BY_MEMBER", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(visitService.getVisitsByMemberId(MEMBER_ID, BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildVisit(), buildVisit()));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 방문 기록"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("2건");
    }

    @Test
    void visit_getByMember_방문기록없으면_기록이_없다는_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("홍길동 방문 기록"))
                .thenReturn(List.of(aiResult("VISIT", "GET_BY_MEMBER", Map.of("searchCriteria", Map.of("name", "홍길동")))));
        when(memberService.searchMembers(null, "홍길동", null, null, BUSINESS_PLACE_ID))
                .thenReturn(List.of(member));
        when(visitService.getVisitsByMemberId(MEMBER_ID, BUSINESS_PLACE_ID)).thenReturn(List.of());

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홍길동 방문 기록"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("방문 기록이 없습니다");
    }

    // ===== [F] STATISTICS 카테고리 라우팅 =====

    @Test
    void statistics_getHome_예약과_회원수를_담아_completed를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("홈 통계"))
                .thenReturn(List.of(aiResult("STATISTICS", "GET_HOME", Map.of())));
        when(reservationService.getTodayReservationCount(BUSINESS_PLACE_ID)).thenReturn(3L);
        when(memberService.getMembersByBusinessPlace(BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID)));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("홈 통계"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("3건");
        assertThat(response.getMessage()).contains("1명");
    }

    @Test
    void statistics_getRecentActivities_최근_메모기반_활동을_담아_completed를_반환한다() {
        stubDefaultBusinessPlace();
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(aiServerClient.analyzeCommand("최근 활동"))
                .thenReturn(List.of(aiResult("STATISTICS", "GET_RECENT_ACTIVITIES", Map.of())));
        when(memberService.getMembersByBusinessPlace(BUSINESS_PLACE_ID)).thenReturn(List.of(member));
        when(memoService.getMemosByMemberId(MEMBER_ID, BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMemo("활동1"), buildMemo("활동2")));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("최근 활동"));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("최근 활동");
    }

    // ===== [G] ERROR / 라우팅 예외 처리 =====

    @Test
    void error_MISSING_PARAMETER면_한국어_안내와_errorCode를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("음"))
                .thenReturn(List.of(aiResult("ERROR", "MISSING_PARAMETER", Map.of())));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("음"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("MISSING_PARAMETER");
        assertThat(response.getMessage()).contains("필요한 정보를 말씀");
    }

    @Test
    void error_DAILY_LIMIT_EXCEEDED면_사용량_초과_안내를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("뭐해"))
                .thenReturn(List.of(aiResult("ERROR", "DAILY_LIMIT_EXCEEDED", Map.of())));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("뭐해"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("DAILY_LIMIT_EXCEEDED");
        assertThat(response.getMessage()).contains("사용량을 초과");
    }

    @Test
    void error_UNKNOWN이면_UNKNOWN_COMMAND로_매핑한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("아무말"))
                .thenReturn(List.of(aiResult("ERROR", "UNKNOWN", Map.of())));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("아무말"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("UNKNOWN_COMMAND");
    }

    @Test
    void route_지원하지않는_카테고리면_UNSUPPORTED_CATEGORY를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("사업장 만들어"))
                .thenReturn(List.of(aiResult("BUSINESS_PLACE", "CREATE", Map.of())));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("사업장 만들어"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("UNSUPPORTED_CATEGORY");
    }

    @Test
    void route_카테고리가_null이면_INVALID_CATEGORY를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("이상한 명령"))
                .thenReturn(List.of(aiResult(null, "SEARCH", Map.of())));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("이상한 명령"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("INVALID_CATEGORY");
    }

    @Test
    void route_member_액션이_null이면_INVALID_ACTION을_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("회원"))
                .thenReturn(List.of(aiResult("MEMBER", null, Map.of())));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("회원"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("INVALID_ACTION");
    }

    @Test
    void route_지원하지않는_member_액션이면_UNSUPPORTED_ACTION을_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("회원 뭐시기"))
                .thenReturn(List.of(aiResult("MEMBER", "FLY", Map.of())));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("회원 뭐시기"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("UNSUPPORTED_ACTION");
    }

    @Test
    void processNewCommand_AI결과가_비면_AI_NO_RESULT를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("무응답")).thenReturn(List.of());

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("무응답"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("AI_NO_RESULT");
    }

    @Test
    void processNewCommand_처리중_예외면_PROCESSING_ERROR를_반환한다() {
        stubDefaultBusinessPlace();
        when(aiServerClient.analyzeCommand("펑")).thenThrow(new RuntimeException("boom"));

        VoiceCommandResponse response = voiceCommandService.processNewCommand(newCommandRequest("펑"));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("PROCESSING_ERROR");
    }

    // ===== [H] 대화 이어가기 (continued) 각 stepType =====

    @Test
    void continue_member_selection_후보선택이_매칭되면_원의도를_실행한다() {
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));
        when(memberService.getMemberByIdWithUserCheck(MEMBER_ID, USER_ID)).thenReturn(member);
        when(memoService.getLatestMemoByMemberId(MEMBER_ID, BUSINESS_PLACE_ID)).thenReturn(null);

        Map<String, Object> candidate = new HashMap<>();
        candidate.put("id", MEMBER_ID);
        candidate.put("name", "홍길동");
        Map<String, Object> additionalData = new HashMap<>();
        additionalData.put("candidates", List.of(candidate));

        Map<String, Object> originalIntent = new HashMap<>();
        originalIntent.put("category", "MEMBER");
        originalIntent.put("action", "SEARCH");
        originalIntent.put("parameters", Map.of("searchCriteria", Map.of("name", "홍길동")));

        ConversationContextDTO context = ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("member_selection").build())
                .additionalData(additionalData)
                .originalIntent(originalIntent)
                .build();

        VoiceCommandResponse response = voiceCommandService.processContinuedConversation(
                continueRequest("홍길동", context));

        assertThat(response.getStatus()).isEqualTo("completed");
        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
    }

    @Test
    void continue_member_selection_매칭실패면_clarification을_반환한다() {
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));

        Map<String, Object> candidate = new HashMap<>();
        candidate.put("id", MEMBER_ID);
        candidate.put("name", "홍길동");
        Map<String, Object> additionalData = new HashMap<>();
        additionalData.put("candidates", List.of(candidate));

        ConversationContextDTO context = ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("member_selection").build())
                .additionalData(additionalData)
                .build();

        VoiceCommandResponse response = voiceCommandService.processContinuedConversation(
                continueRequest("전혀다른이름", context));

        assertThat(response.getStatus()).isEqualTo("clarification_needed");
        assertThat(response.getMessage()).contains("다시 선택");
    }

    @Test
    void continue_memo_selection_전체선택이면_원의도를_실행한다() {
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));
        when(memberService.getMembersByBusinessPlace(BUSINESS_PLACE_ID))
                .thenReturn(List.of(buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID)));

        Map<String, Object> originalIntent = new HashMap<>();
        originalIntent.put("category", "MEMBER");
        originalIntent.put("action", "GET_ALL");
        originalIntent.put("parameters", new HashMap<>());

        ConversationContextDTO context = ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("memo_selection").build())
                .originalIntent(originalIntent)
                .build();

        VoiceCommandResponse response = voiceCommandService.processContinuedConversation(
                continueRequest("전체", context));

        assertThat(response.getStatus()).isEqualTo("completed");
    }

    @Test
    void continue_content_input_내용입력되면_메모를_생성한다() {
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));
        when(memberService.getMemberByIdWithUserCheck(MEMBER_ID, USER_ID)).thenReturn(member);
        when(memoService.createMemo(MEMBER_ID, "특이사항 있음", USER_ID)).thenReturn(buildMemo("특이사항 있음"));

        Map<String, Object> originalIntent = new HashMap<>();
        originalIntent.put("category", "MEMO");
        originalIntent.put("action", "CREATE");
        originalIntent.put("parameters", new HashMap<>());

        ConversationContextDTO context = ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("content_input").build())
                .originalIntent(originalIntent)
                .selectedEntities(new ArrayList<>(List.of(
                        SelectedEntity.builder()
                                .entityType("member")
                                .ids(new ArrayList<>(List.of(MEMBER_ID)))
                                .build())))
                .build();

        VoiceCommandResponse response = voiceCommandService.processContinuedConversation(
                continueRequest("특이사항 있음", context));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("메모를 저장");
    }

    @Test
    void continue_content_input_빈내용이면_clarification을_반환한다() {
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));

        ConversationContextDTO context = ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("content_input").build())
                .build();

        VoiceCommandResponse response = voiceCommandService.processContinuedConversation(
                continueRequest("   ", context));

        assertThat(response.getStatus()).isEqualTo("clarification_needed");
        assertThat(response.getMessage()).contains("내용을 말씀");
    }

    @Test
    void continue_confirmation_긍정이면_원의도_삭제를_실행한다() {
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));
        when(memberService.getMemberByIdWithUserCheck(MEMBER_ID, USER_ID)).thenReturn(member);

        Map<String, Object> originalIntent = new HashMap<>();
        originalIntent.put("category", "MEMBER");
        originalIntent.put("action", "DELETE");
        originalIntent.put("parameters", new HashMap<>());

        ConversationContextDTO context = ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("confirmation").build())
                .originalIntent(originalIntent)
                .selectedEntities(new ArrayList<>(List.of(
                        SelectedEntity.builder()
                                .entityType("member")
                                .ids(new ArrayList<>(List.of(MEMBER_ID)))
                                .build())))
                .build();

        VoiceCommandResponse response = voiceCommandService.processContinuedConversation(
                continueRequest("예", context));

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("삭제 대기");
        verify(memberService).softDeleteMember(MEMBER_ID, USER_ID, BUSINESS_PLACE_ID);
    }

    @Test
    void continue_알수없는_stepType이면_UNKNOWN_STEP을_반환한다() {
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(null).build()));

        ConversationContextDTO context = ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType("bogus_step").build())
                .build();

        VoiceCommandResponse response = voiceCommandService.processContinuedConversation(
                continueRequest("아무말", context));

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("UNKNOWN_STEP");
    }

    // ===== [I] 일일 브리핑 =====

    @Test
    void dailyBriefing_사업장있으면_예약과_중요메모를_담아_completed를_반환한다() {
        Member member = buildMember(MEMBER_ID, "홍길동", "1001", BUSINESS_PLACE_ID);
        Memo important = buildMemo("중요한 확인 사항");
        important.setIsImportant(true);
        when(reservationService.getTodayReservationCount(BUSINESS_PLACE_ID)).thenReturn(2L);
        when(memberService.getMembersByBusinessPlace(BUSINESS_PLACE_ID)).thenReturn(List.of(member));
        when(memoService.getMemosByMemberId(MEMBER_ID, BUSINESS_PLACE_ID)).thenReturn(List.of(important));
        when(memberService.getMemberById(MEMBER_ID)).thenReturn(member);

        VoiceCommandResponse response = voiceCommandService.generateDailyBriefing(USER_ID, BUSINESS_PLACE_ID);

        assertThat(response.getStatus()).isEqualTo("completed");
        assertThat(response.getMessage()).contains("오늘 예약은 총 2건");
        assertThat(response.getMessage()).contains("중요 메모는 1개");
    }

    @Test
    void dailyBriefing_사업장없으면_전역조회하지_않고_거부한다() {
        // WB-04: 사업장 미지정 시 전체회원 폴백은 타 사업장 회원명·중요메모 노출 → 거부
        VoiceCommandResponse response = voiceCommandService.generateDailyBriefing(USER_ID, null);

        assertThat(response.getStatus()).isEqualTo("error");
        assertThat(response.getErrorCode()).isEqualTo("NO_BUSINESS_PLACE");
    }

    // ===== Helpers =====

    private void stubDefaultBusinessPlace() {
        when(userRepository.findById(UUID.fromString(USER_ID)))
                .thenReturn(Optional.of(User.builder().defaultBusinessPlaceId(BUSINESS_PLACE_ID).build()));
    }

    private VoiceCommandRequest newCommandRequest(String text) {
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText(text);
        request.setUserId(USER_ID);
        return request;
    }

    private VoiceCommandRequest continueRequest(String text, ConversationContextDTO context) {
        VoiceCommandRequest request = new VoiceCommandRequest();
        request.setText(text);
        request.setUserId(USER_ID);
        request.setContext(context);
        return request;
    }

    private ConversationContextDTO contextWithSelectedMember(String stepType) {
        return ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType(stepType).build())
                .selectedEntities(new java.util.ArrayList<>(List.of(
                        SelectedEntity.builder()
                                .entityType("member")
                                .ids(new java.util.ArrayList<>(List.of(MEMBER_ID)))
                                .build())))
                .build();
    }

    private ConversationContextDTO contextWithoutSelectedMember(String stepType) {
        return ConversationContextDTO.builder()
                .currentStep(ConversationStep.builder().stepType(stepType).build())
                .build();
    }

    private AiAnalysisResult aiResult(String category, String action, Map<String, Object> parameters) {
        AiAnalysisResult result = new AiAnalysisResult();
        result.setCategory(category);
        result.setAction(action);
        result.setParameters(parameters);
        return result;
    }

    private Member buildMember(String id, String name, String memberNumber, String businessPlaceId) {
        Member member = new Member();
        member.setId(UUID.fromString(id));
        member.setName(name);
        member.setMemberNumber(memberNumber);
        member.setBusinessPlaceId(businessPlaceId);
        return member;
    }

    private Memo buildMemo(String content) {
        Memo memo = new Memo();
        memo.setId(UUID.randomUUID());
        memo.setMemberId(UUID.fromString(MEMBER_ID));
        memo.setContent(content);
        memo.setCreatedAt(LocalDateTime.now());
        return memo;
    }

    private Visit buildVisit() {
        Visit visit = new Visit();
        visit.setId(UUID.randomUUID());
        visit.setMemberId(UUID.fromString(MEMBER_ID));
        visit.setVisitedAt(LocalDateTime.now());
        return visit;
    }
}
