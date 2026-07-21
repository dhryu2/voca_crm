package com.vocacrm.api.controller;

import com.vocacrm.api.dto.AccessRequestWithRequesterDTO;
import com.vocacrm.api.dto.BusinessPlaceDeletionPreviewDTO;
import com.vocacrm.api.dto.BusinessPlaceMemberDTO;
import com.vocacrm.api.dto.BusinessPlaceWithRoleDTO;
import com.vocacrm.api.dto.CreateBusinessPlaceResponse;
import com.vocacrm.api.dto.SetDefaultBusinessPlaceResponse;
import com.vocacrm.api.dto.request.BusinessPlaceCreateRequest;
import com.vocacrm.api.dto.request.BusinessPlaceUpdateRequest;
import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.BusinessPlaceAccessRequest;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.service.AccessControlService;
import com.vocacrm.api.service.BusinessPlaceService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BusinessPlaceControllerTest {

    private static final String USER_ID = "550e8400-e29b-41d4-a716-446655440000";
    private static final String BUSINESS_PLACE_ID = "ABC1234";
    private static final String REQUEST_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    private static final UUID USER_BUSINESS_PLACE_ID = UUID.fromString("bbbbbbbb-cccc-dddd-eeee-ffffffffffff");

    @Mock
    private BusinessPlaceService businessPlaceService;
    @Mock
    private AccessControlService accessControlService;
    @Mock
    private HttpServletRequest servletRequest;

    @InjectMocks
    private BusinessPlaceController businessPlaceController;

    @BeforeEach
    void setUp() {
        when(servletRequest.getAttribute("userId")).thenReturn(USER_ID);
    }

    @Test
    void createBusinessPlace_서비스_정상반환을_그대로_응답한다() {
        BusinessPlaceCreateRequest request = BusinessPlaceCreateRequest.builder()
                .name("테스트 사업장")
                .address("서울시")
                .phone("010-1234-5678")
                .build();
        CreateBusinessPlaceResponse serviceResponse = CreateBusinessPlaceResponse.builder()
                .businessPlaceId(BUSINESS_PLACE_ID)
                .businessPlaceName("테스트 사업장")
                .build();
        when(businessPlaceService.createBusinessPlace(any(BusinessPlace.class), eq(USER_ID)))
                .thenReturn(serviceResponse);

        ResponseEntity<CreateBusinessPlaceResponse> response =
                businessPlaceController.createBusinessPlace(request, servletRequest);

        ArgumentCaptor<BusinessPlace> captor = ArgumentCaptor.forClass(BusinessPlace.class);
        verify(businessPlaceService).createBusinessPlace(captor.capture(), eq(USER_ID));
        assertThat(captor.getValue().getName()).isEqualTo("테스트 사업장");
        assertThat(captor.getValue().getAddress()).isEqualTo("서울시");
        assertThat(captor.getValue().getPhone()).isEqualTo("010-1234-5678");
        assertThat(response.getBody()).isSameAs(serviceResponse);
    }

    @Test
    void createBusinessPlace_서비스_예외를_그대로_전파한다() {
        BusinessPlaceCreateRequest request = BusinessPlaceCreateRequest.builder()
                .name("테스트 사업장")
                .build();
        when(businessPlaceService.createBusinessPlace(any(BusinessPlace.class), eq(USER_ID)))
                .thenThrow(new AccessDeniedException("생성 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.createBusinessPlace(request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getMyBusinessPlaces_서비스_정상반환을_그대로_응답한다() {
        List<BusinessPlaceWithRoleDTO> list = List.of(BusinessPlaceWithRoleDTO.builder()
                .businessPlaceId(BUSINESS_PLACE_ID)
                .build());
        when(businessPlaceService.getMyBusinessPlaces(USER_ID)).thenReturn(list);

        ResponseEntity<List<BusinessPlaceWithRoleDTO>> response =
                businessPlaceController.getMyBusinessPlaces(servletRequest);

        assertThat(response.getBody()).isSameAs(list);
    }

    @Test
    void getMyBusinessPlaces_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.getMyBusinessPlaces(USER_ID))
                .thenThrow(new AccessDeniedException("조회 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.getMyBusinessPlaces(servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getBusinessPlace_멤버십_검증후_서비스_정상반환을_응답한다() {
        BusinessPlace businessPlace = new BusinessPlace();
        businessPlace.setId(BUSINESS_PLACE_ID);
        when(businessPlaceService.getBusinessPlaceById(BUSINESS_PLACE_ID)).thenReturn(businessPlace);

        ResponseEntity<BusinessPlace> response =
                businessPlaceController.getBusinessPlace(BUSINESS_PLACE_ID, servletRequest);

        verify(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getBody()).isSameAs(businessPlace);
    }

    @Test
    void getBusinessPlace_멤버십_검증_실패시_예외를_전파하고_서비스는_호출되지_않는다() {
        doThrow(new AccessDeniedException("접근 권한이 없습니다."))
                .when(accessControlService).requireApprovedMembership(USER_ID, BUSINESS_PLACE_ID);

        assertThatThrownBy(() -> businessPlaceController.getBusinessPlace(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
        verify(businessPlaceService, org.mockito.Mockito.never()).getBusinessPlaceById(any());
    }

    @Test
    void updateBusinessPlace_서비스_정상반환을_그대로_응답한다() {
        BusinessPlaceUpdateRequest request = BusinessPlaceUpdateRequest.builder()
                .name("수정된 사업장")
                .address("부산시")
                .phone("02-1234-5678")
                .build();
        BusinessPlace updated = new BusinessPlace();
        updated.setId(BUSINESS_PLACE_ID);
        when(businessPlaceService.updateBusinessPlace(eq(BUSINESS_PLACE_ID), any(BusinessPlace.class), eq(USER_ID)))
                .thenReturn(updated);

        ResponseEntity<BusinessPlace> response =
                businessPlaceController.updateBusinessPlace(BUSINESS_PLACE_ID, request, servletRequest);

        ArgumentCaptor<BusinessPlace> captor = ArgumentCaptor.forClass(BusinessPlace.class);
        verify(businessPlaceService).updateBusinessPlace(eq(BUSINESS_PLACE_ID), captor.capture(), eq(USER_ID));
        assertThat(captor.getValue().getName()).isEqualTo("수정된 사업장");
        assertThat(response.getBody()).isSameAs(updated);
    }

    @Test
    void updateBusinessPlace_서비스_예외를_그대로_전파한다() {
        BusinessPlaceUpdateRequest request = BusinessPlaceUpdateRequest.builder()
                .name("수정된 사업장")
                .build();
        when(businessPlaceService.updateBusinessPlace(eq(BUSINESS_PLACE_ID), any(BusinessPlace.class), eq(USER_ID)))
                .thenThrow(new AccessDeniedException("수정 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.updateBusinessPlace(BUSINESS_PLACE_ID, request, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void setDefaultBusinessPlace_서비스_정상반환을_그대로_응답한다() {
        SetDefaultBusinessPlaceResponse response = SetDefaultBusinessPlaceResponse.builder()
                .defaultBusinessPlaceId(BUSINESS_PLACE_ID)
                .build();
        when(businessPlaceService.setDefaultBusinessPlace(USER_ID, BUSINESS_PLACE_ID)).thenReturn(response);

        ResponseEntity<SetDefaultBusinessPlaceResponse> result =
                businessPlaceController.setDefaultBusinessPlace(BUSINESS_PLACE_ID, servletRequest);

        assertThat(result.getBody()).isSameAs(response);
    }

    @Test
    void setDefaultBusinessPlace_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.setDefaultBusinessPlace(USER_ID, BUSINESS_PLACE_ID))
                .thenThrow(new AccessDeniedException("기본 사업장 설정 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.setDefaultBusinessPlace(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void requestAccess_서비스_정상반환을_그대로_응답한다() {
        BusinessPlaceAccessRequest accessRequest = new BusinessPlaceAccessRequest();
        when(businessPlaceService.requestAccess(USER_ID, BUSINESS_PLACE_ID, Role.STAFF)).thenReturn(accessRequest);

        ResponseEntity<BusinessPlaceAccessRequest> response =
                businessPlaceController.requestAccess(BUSINESS_PLACE_ID, Role.STAFF, servletRequest);

        assertThat(response.getBody()).isSameAs(accessRequest);
    }

    @Test
    void requestAccess_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.requestAccess(USER_ID, BUSINESS_PLACE_ID, Role.STAFF))
                .thenThrow(new AccessDeniedException("이미 요청된 사업장입니다."));

        assertThatThrownBy(() -> businessPlaceController.requestAccess(BUSINESS_PLACE_ID, Role.STAFF, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getSentRequests_서비스_정상반환을_그대로_응답한다() {
        List<BusinessPlaceAccessRequest> list = List.of(new BusinessPlaceAccessRequest());
        when(businessPlaceService.getSentRequests(USER_ID)).thenReturn(list);

        ResponseEntity<List<BusinessPlaceAccessRequest>> response =
                businessPlaceController.getSentRequests(servletRequest);

        assertThat(response.getBody()).isSameAs(list);
    }

    @Test
    void getSentRequests_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.getSentRequests(USER_ID)).thenThrow(new AccessDeniedException("조회 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.getSentRequests(servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getReceivedRequests_서비스_정상반환을_그대로_응답한다() {
        List<AccessRequestWithRequesterDTO> list = List.of(AccessRequestWithRequesterDTO.builder().id(REQUEST_ID).build());
        when(businessPlaceService.getReceivedRequestsWithRequester(USER_ID)).thenReturn(list);

        ResponseEntity<List<AccessRequestWithRequesterDTO>> response =
                businessPlaceController.getReceivedRequests(servletRequest);

        assertThat(response.getBody()).isSameAs(list);
    }

    @Test
    void getReceivedRequests_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.getReceivedRequestsWithRequester(USER_ID))
                .thenThrow(new AccessDeniedException("조회 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.getReceivedRequests(servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getUnreadResults_서비스_정상반환을_그대로_응답한다() {
        List<BusinessPlaceAccessRequest> list = List.of(new BusinessPlaceAccessRequest());
        when(businessPlaceService.getUnreadResults(USER_ID)).thenReturn(list);

        ResponseEntity<List<BusinessPlaceAccessRequest>> response =
                businessPlaceController.getUnreadResults(servletRequest);

        assertThat(response.getBody()).isSameAs(list);
    }

    @Test
    void getUnreadResults_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.getUnreadResults(USER_ID)).thenThrow(new AccessDeniedException("조회 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.getUnreadResults(servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getPendingRequestCount_서비스_정상반환을_그대로_응답한다() {
        when(businessPlaceService.getPendingRequestCount(USER_ID)).thenReturn(3L);

        ResponseEntity<Long> response = businessPlaceController.getPendingRequestCount(servletRequest);

        assertThat(response.getBody()).isEqualTo(3L);
    }

    @Test
    void getPendingRequestCount_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.getPendingRequestCount(USER_ID))
                .thenThrow(new AccessDeniedException("조회 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.getPendingRequestCount(servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getUnreadResultCount_서비스_정상반환을_그대로_응답한다() {
        when(businessPlaceService.getUnreadResultCount(USER_ID)).thenReturn(2L);

        ResponseEntity<Long> response = businessPlaceController.getUnreadResultCount(servletRequest);

        assertThat(response.getBody()).isEqualTo(2L);
    }

    @Test
    void getUnreadResultCount_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.getUnreadResultCount(USER_ID))
                .thenThrow(new AccessDeniedException("조회 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.getUnreadResultCount(servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void approveRequest_서비스_정상반환을_그대로_응답한다() {
        BusinessPlaceAccessRequest approved = new BusinessPlaceAccessRequest();
        when(businessPlaceService.approveRequest(REQUEST_ID, USER_ID)).thenReturn(approved);

        ResponseEntity<BusinessPlaceAccessRequest> response =
                businessPlaceController.approveRequest(REQUEST_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(approved);
    }

    @Test
    void approveRequest_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.approveRequest(REQUEST_ID, USER_ID))
                .thenThrow(new AccessDeniedException("승인 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.approveRequest(REQUEST_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void rejectRequest_서비스_정상반환을_그대로_응답한다() {
        BusinessPlaceAccessRequest rejected = new BusinessPlaceAccessRequest();
        when(businessPlaceService.rejectRequest(REQUEST_ID, USER_ID)).thenReturn(rejected);

        ResponseEntity<BusinessPlaceAccessRequest> response =
                businessPlaceController.rejectRequest(REQUEST_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(rejected);
    }

    @Test
    void rejectRequest_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.rejectRequest(REQUEST_ID, USER_ID))
                .thenThrow(new AccessDeniedException("거절 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.rejectRequest(REQUEST_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void deleteRequest_서비스_호출후_204를_응답한다() {
        ResponseEntity<Void> response = businessPlaceController.deleteRequest(REQUEST_ID, servletRequest);

        verify(businessPlaceService).deleteRequest(REQUEST_ID, USER_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(204);
    }

    @Test
    void deleteRequest_서비스_예외를_그대로_전파한다() {
        doThrow(new AccessDeniedException("삭제 권한이 없습니다."))
                .when(businessPlaceService).deleteRequest(REQUEST_ID, USER_ID);

        assertThatThrownBy(() -> businessPlaceController.deleteRequest(REQUEST_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void markRequestAsRead_서비스_정상반환을_그대로_응답한다() {
        BusinessPlaceAccessRequest marked = new BusinessPlaceAccessRequest();
        when(businessPlaceService.markRequestAsRead(REQUEST_ID, USER_ID)).thenReturn(marked);

        ResponseEntity<BusinessPlaceAccessRequest> response =
                businessPlaceController.markRequestAsRead(REQUEST_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(marked);
    }

    @Test
    void markRequestAsRead_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.markRequestAsRead(REQUEST_ID, USER_ID))
                .thenThrow(new ResourceNotFoundException("요청을 찾을 수 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.markRequestAsRead(REQUEST_ID, servletRequest))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void removeBusinessPlace_서비스_호출후_204를_응답한다() {
        ResponseEntity<Void> response = businessPlaceController.removeBusinessPlace(BUSINESS_PLACE_ID, servletRequest);

        verify(businessPlaceService).removeBusinessPlace(USER_ID, BUSINESS_PLACE_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(204);
    }

    @Test
    void removeBusinessPlace_서비스_예외를_그대로_전파한다() {
        doThrow(new AccessDeniedException("탈퇴 권한이 없습니다."))
                .when(businessPlaceService).removeBusinessPlace(USER_ID, BUSINESS_PLACE_ID);

        assertThatThrownBy(() -> businessPlaceController.removeBusinessPlace(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getBusinessPlaceMembers_서비스_정상반환을_그대로_응답한다() {
        List<BusinessPlaceMemberDTO> list = List.of(BusinessPlaceMemberDTO.builder().userId(USER_ID).build());
        when(businessPlaceService.getBusinessPlaceMembers(BUSINESS_PLACE_ID, USER_ID)).thenReturn(list);

        ResponseEntity<List<BusinessPlaceMemberDTO>> response =
                businessPlaceController.getBusinessPlaceMembers(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(list);
    }

    @Test
    void getBusinessPlaceMembers_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.getBusinessPlaceMembers(BUSINESS_PLACE_ID, USER_ID))
                .thenThrow(new AccessDeniedException("멤버 조회 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.getBusinessPlaceMembers(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void updateMemberRole_서비스_정상반환을_그대로_응답한다() {
        BusinessPlaceMemberDTO updated = BusinessPlaceMemberDTO.builder().role(Role.MANAGER).build();
        when(businessPlaceService.updateMemberRole(USER_BUSINESS_PLACE_ID, Role.MANAGER, USER_ID)).thenReturn(updated);

        ResponseEntity<BusinessPlaceMemberDTO> response =
                businessPlaceController.updateMemberRole(USER_BUSINESS_PLACE_ID, Role.MANAGER, servletRequest);

        assertThat(response.getBody()).isSameAs(updated);
    }

    @Test
    void updateMemberRole_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.updateMemberRole(USER_BUSINESS_PLACE_ID, Role.MANAGER, USER_ID))
                .thenThrow(new AccessDeniedException("역할 변경 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.updateMemberRole(USER_BUSINESS_PLACE_ID, Role.MANAGER, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void removeMember_서비스_호출후_204를_응답한다() {
        ResponseEntity<Void> response = businessPlaceController.removeMember(USER_BUSINESS_PLACE_ID, servletRequest);

        verify(businessPlaceService).removeMember(USER_BUSINESS_PLACE_ID, USER_ID);
        assertThat(response.getStatusCode().value()).isEqualTo(204);
    }

    @Test
    void removeMember_서비스_예외를_그대로_전파한다() {
        doThrow(new AccessDeniedException("강제 탈퇴 권한이 없습니다."))
                .when(businessPlaceService).removeMember(USER_BUSINESS_PLACE_ID, USER_ID);

        assertThatThrownBy(() -> businessPlaceController.removeMember(USER_BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void getDeletionPreview_서비스_정상반환을_그대로_응답한다() {
        BusinessPlaceDeletionPreviewDTO preview = BusinessPlaceDeletionPreviewDTO.builder()
                .businessPlaceId(BUSINESS_PLACE_ID)
                .build();
        when(businessPlaceService.getDeletionPreview(BUSINESS_PLACE_ID, USER_ID)).thenReturn(preview);

        ResponseEntity<BusinessPlaceDeletionPreviewDTO> response =
                businessPlaceController.getDeletionPreview(BUSINESS_PLACE_ID, servletRequest);

        assertThat(response.getBody()).isSameAs(preview);
    }

    @Test
    void getDeletionPreview_서비스_예외를_그대로_전파한다() {
        when(businessPlaceService.getDeletionPreview(BUSINESS_PLACE_ID, USER_ID))
                .thenThrow(new AccessDeniedException("미리보기 조회 권한이 없습니다."));

        assertThatThrownBy(() -> businessPlaceController.getDeletionPreview(BUSINESS_PLACE_ID, servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void deleteBusinessPlacePermanently_서비스_호출후_204를_응답한다() {
        ResponseEntity<Void> response =
                businessPlaceController.deleteBusinessPlacePermanently(BUSINESS_PLACE_ID, "테스트 사업장", servletRequest);

        verify(businessPlaceService).deleteBusinessPlacePermanently(BUSINESS_PLACE_ID, USER_ID, "테스트 사업장");
        assertThat(response.getStatusCode().value()).isEqualTo(204);
    }

    @Test
    void deleteBusinessPlacePermanently_서비스_예외를_그대로_전파한다() {
        doThrow(new AccessDeniedException("영구 삭제 권한이 없습니다."))
                .when(businessPlaceService).deleteBusinessPlacePermanently(BUSINESS_PLACE_ID, USER_ID, "테스트 사업장");

        assertThatThrownBy(() ->
                businessPlaceController.deleteBusinessPlacePermanently(BUSINESS_PLACE_ID, "테스트 사업장", servletRequest))
                .isInstanceOf(AccessDeniedException.class);
    }
}
