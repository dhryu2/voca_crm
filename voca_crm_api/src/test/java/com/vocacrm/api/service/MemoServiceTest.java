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
import com.vocacrm.api.repository.UserBusinessPlaceRepository;
import com.vocacrm.api.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
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
 * MemoService integration test with @SpringBootTest
 *
 * Test scope:
 * - Memo CRUD business logic
 * - Member-specific queries
 * - Latest memo retrieval (sorting)
 * - Permission checks
 * - Soft delete
 *
 * NOTE: This test requires Docker/Testcontainers to run.
 * Current blocker: Testcontainers 1.20.4 has Docker connectivity issue
 * with Docker Desktop 4.55.0 on macOS (see STATE.md for details).
 */
@SpringBootTest
@Testcontainers
@Transactional
class MemoServiceTest {

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
    private MemoService memoService;

    @Autowired
    private MemoRepository memoRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private UserBusinessPlaceRepository userBusinessPlaceRepository;

    @Autowired
    private BusinessPlaceRepository businessPlaceRepository;

    @Autowired
    private UserRepository userRepository;

    private String testBusinessPlaceId;
    private UUID testUserId;
    private UUID testMemberId;

    @BeforeEach
    void setUp() {
        testBusinessPlaceId = UUID.randomUUID().toString();
        testUserId = UUID.randomUUID();
        testMemberId = UUID.randomUUID();

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

        // Create test member
        Member testMember = new Member();
        testMember.setId(testMemberId);
        testMember.setMemberNumber("MEMO-TEST-001");
        testMember.setName("Memo Test Member");
        testMember.setBusinessPlaceId(testBusinessPlaceId);
        testMember.setCreatedAt(LocalDateTime.now());
        testMember.setUpdatedAt(LocalDateTime.now());
        testMember.setIsDeleted(false);
        memberRepository.save(testMember);
    }

    @Test
    @Transactional
    void getMemosByMemberId_shouldReturnAllMemberMemos() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        createTestMemo(testMemberId, "Memo 1", false);
        createTestMemo(testMemberId, "Memo 2", false);
        createTestMemo(testMemberId, "Memo 3", false);

        // Different member's memo (should not be returned)
        UUID otherMemberId = UUID.randomUUID();
        Member otherMember = new Member();
        otherMember.setId(otherMemberId);
        otherMember.setMemberNumber("OTHER-001");
        otherMember.setName("Other Member");
        otherMember.setBusinessPlaceId(testBusinessPlaceId);
        otherMember.setCreatedAt(LocalDateTime.now());
        otherMember.setUpdatedAt(LocalDateTime.now());
        otherMember.setIsDeleted(false);
        memberRepository.save(otherMember);
        createTestMemo(otherMemberId, "Other Member Memo", false);

        // When
        List<Memo> memos = memoService.getMemosByMemberId(
            testMemberId.toString(),
            testBusinessPlaceId
        );

        // Then
        assertThat(memos).hasSize(3);
        assertThat(memos).allMatch(memo -> memo.getMemberId().equals(testMemberId));
    }

    @Test
    @Transactional
    void getLatestMemoByMemberId_shouldReturnNewestMemo() throws Exception {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        LocalDateTime now = LocalDateTime.now();

        Memo old = createTestMemo(testMemberId, "Old Memo", false);
        old.setCreatedAt(now.minusHours(2));
        memoRepository.save(old);

        Thread.sleep(100);  // Ensure timestamp difference

        Memo latest = createTestMemo(testMemberId, "Latest Memo", false);
        latest.setCreatedAt(now);
        memoRepository.save(latest);

        // When
        Memo result = memoService.getLatestMemoByMemberId(
            testMemberId.toString(),
            testBusinessPlaceId
        );

        // Then
        assertThat(result).isNotNull();
        assertThat(result.getContent()).isEqualTo("Latest Memo");
    }

    @Test
    @Transactional
    void updateMemoWithPermission_whenUserHasPermission_shouldUpdate() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        Memo memo = createTestMemo(testMemberId, "Original Content", false);
        memo.setOwnerId(testUserId);
        memoRepository.save(memo);

        Memo updateDetails = new Memo();
        updateDetails.setContent("Updated Content");

        // When
        Memo updated = memoService.updateMemoWithPermission(
            memo.getId().toString(),
            updateDetails,
            testUserId.toString(),
            testBusinessPlaceId
        );

        // Then
        assertThat(updated.getContent()).isEqualTo("Updated Content");
        assertThat(updated.getUpdatedAt()).isAfter(memo.getUpdatedAt());
    }

    @Test
    @Transactional
    void updateMemoWithPermission_whenUserLacksPermission_shouldThrowException() {
        // Given
        UUID unauthorizedUserId = UUID.randomUUID();
        setupUserAccess(testUserId, testBusinessPlaceId);
        Memo memo = createTestMemo(testMemberId, "Original", false);
        memo.setOwnerId(testUserId);
        memoRepository.save(memo);

        Memo updateDetails = new Memo();
        updateDetails.setContent("Attempted Update");

        // When & Then
        assertThrows(AccessDeniedException.class, () -> {
            memoService.updateMemoWithPermission(
                memo.getId().toString(),
                updateDetails,
                unauthorizedUserId.toString(),
                testBusinessPlaceId
            );
        });
    }

    @Test
    @Transactional
    void softDeleteMemo_shouldMarkMemoAsDeleted() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        Memo memo = createTestMemo(testMemberId, "To Be Deleted", false);
        memo.setOwnerId(testUserId);
        memoRepository.save(memo);

        // When
        Memo deleted = memoService.softDeleteMemo(
            memo.getId().toString(),
            testUserId.toString(),
            testBusinessPlaceId
        );

        // Then
        assertThat(deleted.getIsDeleted()).isTrue();
        assertThat(deleted.getDeletedAt()).isNotNull();
        assertThat(deleted.getDeletedBy()).isEqualTo(testUserId);

        // Verify not returned in active memo queries
        List<Memo> activeMemos = memoService.getMemosByMemberId(
            testMemberId.toString(),
            testBusinessPlaceId
        );
        assertThat(activeMemos).doesNotContain(deleted);
    }

    @Test
    @Transactional
    void getMemosByBusinessPlace_shouldReturnOnlyNonDeletedMemos() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        Memo active = createTestMemo(testMemberId, "Active Memo", false);
        Memo deleted = createTestMemo(testMemberId, "Deleted Memo", true);

        // When
        List<Memo> results = memoService.getMemosByBusinessPlace(testBusinessPlaceId);

        // Then
        assertThat(results).hasSize(1);
        assertThat(results.get(0).getId()).isEqualTo(active.getId());
    }

    @Test
    @Transactional
    void getMemoById_whenDeleted_shouldThrowException() {
        // Given
        setupUserAccess(testUserId, testBusinessPlaceId);
        Memo memo = createTestMemo(testMemberId, "Deleted Memo", true);

        // When & Then
        assertThrows(ResourceNotFoundException.class, () -> {
            memoService.getMemoById(memo.getId().toString(), testBusinessPlaceId);
        });
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

    private Memo createTestMemo(UUID memberId, String content, boolean isDeleted) {
        Memo memo = new Memo();
        memo.setMemberId(memberId);
        memo.setContent(content);
        memo.setCreatedAt(LocalDateTime.now());
        memo.setUpdatedAt(LocalDateTime.now());
        memo.setIsDeleted(isDeleted);
        if (isDeleted) {
            memo.setDeletedAt(LocalDateTime.now());
            memo.setDeletedBy(testUserId);
        }
        return memoRepository.save(memo);
    }
}
