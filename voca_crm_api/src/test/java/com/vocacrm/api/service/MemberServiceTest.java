package com.vocacrm.api.service;

import com.vocacrm.api.exception.AccessDeniedException;
import com.vocacrm.api.exception.ResourceNotFoundException;
import com.vocacrm.api.model.AccessStatus;
import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Memo;
import com.vocacrm.api.model.Role;
import com.vocacrm.api.model.User;
import com.vocacrm.api.model.UserBusinessPlace;
import com.vocacrm.api.repository.BusinessPlaceRepository;
import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.repository.MemoRepository;
import com.vocacrm.api.repository.RefreshTokenRepository;
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * MemberService integration test with @SpringBootTest
 *
 * Test scope:
 * - Business logic verification (full stack)
 * - Permission checks (OWNER/MANAGER/STAFF)
 * - Soft delete cascade (Member -> Memos)
 * - Transactional behavior
 *
 * @SpringBootTest loads full application context for
 * Service -> Repository -> Database full stack verification
 *
 * NOTE: This test requires Docker/Testcontainers to run.
 * Current blocker: Testcontainers 1.20.4 has Docker connectivity issue
 * with Docker Desktop 4.55.0 on macOS (see STATE.md for details).
 */
@SpringBootTest
@Testcontainers
@Transactional
class MemberServiceTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private MemberService memberService;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private MemoRepository memoRepository;

    @Autowired
    private UserBusinessPlaceRepository userBusinessPlaceRepository;

    @Autowired
    private BusinessPlaceRepository businessPlaceRepository;

    @Autowired
    private UserRepository userRepository;

    private String testBusinessPlaceId;
    private UUID testUserId;

    @BeforeEach
    void setUp() {
        testBusinessPlaceId = UUID.randomUUID().toString();
        testUserId = UUID.randomUUID();

        // Clear test data
        memoRepository.deleteAll();
        memberRepository.deleteAll();
        userBusinessPlaceRepository.deleteAll();
        businessPlaceRepository.deleteAll();
        userRepository.deleteAll();

        // Create test user and business place
        User testUser = new User();
        testUser.setId(testUserId);
        testUser.setUsername("testuser");
        testUser.setEmail("test@example.com");
        testUser.setTier("FREE");
        testUser.setCreatedAt(LocalDateTime.now());
        testUser.setUpdatedAt(LocalDateTime.now());
        userRepository.save(testUser);

        BusinessPlace testBusinessPlace = new BusinessPlace();
        testBusinessPlace.setId(testBusinessPlaceId);
        testBusinessPlace.setName("Test Business Place");
        testBusinessPlace.setCreatedAt(LocalDateTime.now());
        testBusinessPlace.setUpdatedAt(LocalDateTime.now());
        businessPlaceRepository.save(testBusinessPlace);
    }

    @Test
    @Transactional
    void getMemberByIdWithUserCheck_whenMemberExists_shouldReturnMember() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        Member member = createTestMember("GET-001", testBusinessPlaceId, false);

        // When
        Member found = memberService.getMemberByIdWithUserCheck(
            member.getId().toString(),
            testUserId.toString()
        );

        // Then
        assertThat(found).isNotNull();
        assertThat(found.getId()).isEqualTo(member.getId());
    }

    @Test
    @Transactional
    void getMemberByIdWithUserCheck_whenMemberNotFound_shouldThrowException() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        String nonExistentId = UUID.randomUUID().toString();

        // When & Then
        assertThrows(ResourceNotFoundException.class, () -> {
            memberService.getMemberByIdWithUserCheck(nonExistentId, testUserId.toString());
        });
    }

    @Test
    @Transactional
    void updateMemberWithPermission_whenUserHasPermission_shouldUpdate() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        Member member = createTestMember("UPD-001", testBusinessPlaceId, false);
        member.setOwnerId(testUserId);
        memberRepository.save(member);

        Member updateDetails = new Member();
        updateDetails.setMemberNumber(member.getMemberNumber());
        updateDetails.setName("Updated Name");
        updateDetails.setPhone("010-9999-9999");
        updateDetails.setEmail(member.getEmail());

        // When
        Member updated = memberService.updateMemberWithPermission(
            member.getId().toString(),
            updateDetails,
            testUserId.toString(),
            testBusinessPlaceId
        );

        // Then
        assertThat(updated.getName()).isEqualTo("Updated Name");
        assertThat(updated.getPhone()).isEqualTo("010-9999-9999");
        assertThat(updated.getUpdatedAt()).isAfter(member.getUpdatedAt());
    }

    @Test
    @Transactional
    void updateMemberWithPermission_whenUserLacksPermission_shouldThrowException() {
        // Given
        UUID unauthorizedUserId = UUID.randomUUID();
        setupUserAccess(testUserId, testBusinessPlaceId);
        Member member = createTestMember("UPD-002", testBusinessPlaceId, false);
        member.setOwnerId(testUserId);
        memberRepository.save(member);

        Member updateDetails = new Member();
        updateDetails.setMemberNumber(member.getMemberNumber());
        updateDetails.setName("Attempted Update");
        updateDetails.setEmail(member.getEmail());

        // When & Then
        assertThrows(AccessDeniedException.class, () -> {
            memberService.updateMemberWithPermission(
                member.getId().toString(),
                updateDetails,
                unauthorizedUserId.toString(),
                testBusinessPlaceId
            );
        });
    }

    @Test
    @Transactional
    void softDeleteMember_shouldMarkMemberAndMemosAsDeleted() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        Member member = createTestMember("DEL-001", testBusinessPlaceId, false);
        member.setOwnerId(testUserId);
        memberRepository.save(member);

        // Create related memos
        Memo memo1 = createTestMemo(member.getId(), testBusinessPlaceId, "Memo 1");
        Memo memo2 = createTestMemo(member.getId(), testBusinessPlaceId, "Memo 2");

        // When
        Member deleted = memberService.softDeleteMember(
            member.getId().toString(),
            testUserId.toString(),
            testBusinessPlaceId
        );

        // Then - Member is soft-deleted
        assertThat(deleted.getIsDeleted()).isTrue();
        assertThat(deleted.getDeletedAt()).isNotNull();
        assertThat(deleted.getDeletedBy()).isEqualTo(testUserId);

        // Then - Related memos are also soft-deleted (cascade)
        List<Memo> deletedMemos = memoRepository
            .findByMemberIdAndBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(
                member.getId(),
                testBusinessPlaceId
            );
        assertThat(deletedMemos).hasSize(2);
        assertThat(deletedMemos).allMatch(Memo::getIsDeleted);
    }

    @Test
    @Transactional
    void searchMembers_shouldReturnFilteredResults() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        createTestMember("SEARCH-001", "Kim철수", testBusinessPlaceId);
        createTestMember("SEARCH-002", "Kim 영희", testBusinessPlaceId);
        createTestMember("SEARCH-003", "Lee철수", testBusinessPlaceId);

        // When - Search by name
        List<Member> results = memberService.searchMembers(
            null,  // memberNumber
            "철수",  // name
            null,  // phone
            null,  // email
            testBusinessPlaceId
        );

        // Then
        assertThat(results).hasSize(2);
        assertThat(results)
            .extracting(Member::getName)
            .allMatch(name -> name.contains("철수"));
    }

    @Test
    @Transactional
    void getMembersByUserId_shouldReturnOnlyUserAccessibleMembers() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        String otherBusinessPlaceId = UUID.randomUUID().toString();

        Member accessible = createTestMember("ACC-001", testBusinessPlaceId, false);
        Member notAccessible = createTestMember("NAC-001", otherBusinessPlaceId, false);

        // When
        Page<Member> results = memberService.getMembersByUserId(
            testUserId.toString(),
            PageRequest.of(0, 10)
        );

        // Then
        assertThat(results.getContent()).hasSize(1);
        assertThat(results.getContent().get(0).getId()).isEqualTo(accessible.getId());
    }

    @Test
    @Transactional
    void getMemberById_whenDeleted_shouldThrowException() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        Member member = createTestMember("DELETED-001", testBusinessPlaceId, true);

        // When & Then
        assertThrows(ResourceNotFoundException.class, () -> {
            memberService.getMemberById(member.getId().toString());
        });
    }

    @Test
    @Transactional
    void getMembersByBusinessPlace_shouldReturnOnlyNonDeletedMembers() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        Member active = createTestMember("ACTIVE-001", testBusinessPlaceId, false);
        Member deleted = createTestMember("DELETED-002", testBusinessPlaceId, true);

        // When
        List<Member> results = memberService.getMembersByBusinessPlace(testBusinessPlaceId);

        // Then
        assertThat(results).hasSize(1);
        assertThat(results.get(0).getId()).isEqualTo(active.getId());
    }

    // ========== Helper Methods ==========

    private void setupUserAccess(UUID userId, String businessPlaceId) {
        UserBusinessPlace access = new UserBusinessPlace();
        access.setUserId(userId);
        access.setBusinessPlaceId(businessPlaceId);
        access.setRole(Role.OWNER);
        access.setStatus(AccessStatus.APPROVED);
        access.setCreatedAt(LocalDateTime.now());
        access.setUpdatedAt(LocalDateTime.now());
        userBusinessPlaceRepository.save(access);
    }

    private Member createTestMember(String memberNumber, String businessPlaceId, boolean isDeleted) {
        return createTestMember(memberNumber, "Test Member " + memberNumber, businessPlaceId, isDeleted);
    }

    private Member createTestMember(String memberNumber, String name, String businessPlaceId) {
        return createTestMember(memberNumber, name, businessPlaceId, false);
    }

    private Member createTestMember(String memberNumber, String name, String businessPlaceId, boolean isDeleted) {
        Member member = new Member();
        member.setMemberNumber(memberNumber);
        member.setName(name);
        member.setPhone("010-0000-0000");
        member.setBusinessPlaceId(businessPlaceId);
        member.setCreatedAt(LocalDateTime.now());
        member.setUpdatedAt(LocalDateTime.now());
        member.setIsDeleted(isDeleted);
        if (isDeleted) {
            member.setDeletedAt(LocalDateTime.now());
            member.setDeletedBy(testUserId);
        }
        return memberRepository.save(member);
    }

    private Memo createTestMemo(UUID memberId, String businessPlaceId, String content) {
        Memo memo = new Memo();
        memo.setMemberId(memberId);
        memo.setContent(content);
        memo.setCreatedAt(LocalDateTime.now());
        memo.setUpdatedAt(LocalDateTime.now());
        memo.setIsDeleted(false);
        return memoRepository.save(memo);
    }
}
