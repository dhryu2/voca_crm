package com.vocacrm.api.repository;

import com.vocacrm.api.model.Memo;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Disabled;
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
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * MemoRepository integration tests using Testcontainers PostgreSQL
 *
 * Test scope:
 * - Memo CRUD queries
 * - Member-specific memo retrieval (foreign key relationship)
 * - Latest memo retrieval (sorting + pagination)
 * - Soft delete filtering
 *
 * NOTE: Tests are currently disabled due to Testcontainers Docker connectivity issue
 * documented in 02-01-SUMMARY. Docker Desktop 4.55.0 incompatible with Testcontainers 1.20.4.
 * Tests will run once Docker environment is updated or Testcontainers version is upgraded.
 */
@SpringBootTest
@Testcontainers
@Transactional
@Disabled("Testcontainers Docker connectivity issue - see .planning/phases/02-api-testing-infrastructure/02-01-SUMMARY.md")
class MemoRepositoryTest {

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
    private MemoRepository memoRepository;

    private UUID testMemberId;
    private String testBusinessPlaceId;

    @BeforeEach
    void setUp() {
        testMemberId = UUID.randomUUID();
        testBusinessPlaceId = "BIZ" + String.format("%04d", (int)(Math.random() * 10000));
        memoRepository.deleteAll();
    }

    private Memo createMemo(String content, boolean isDeleted, LocalDateTime createdAt) {
        Memo memo = new Memo();
        memo.setMemberId(testMemberId);
        memo.setContent(content);
        memo.setCreatedAt(createdAt != null ? createdAt : LocalDateTime.now());
        memo.setUpdatedAt(LocalDateTime.now());
        memo.setIsDeleted(isDeleted);
        if (isDeleted) {
            memo.setDeletedAt(LocalDateTime.now());
            memo.setDeletedBy(UUID.randomUUID());
        }
        return memo;
    }

    @Test
    void findById_shouldReturnMemo() {
        Memo saved = memoRepository.save(createMemo("Test memo", false, null));

        Optional<Memo> found = memoRepository.findById(saved.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getContent()).isEqualTo("Test memo");
    }

    @Test
    void findByMemberIdAndIsDeletedFalseOrderByCreatedAtDesc_shouldReturnSortedMemos() {
        LocalDateTime now = LocalDateTime.now();
        Memo memo1 = memoRepository.save(createMemo("First memo", false, now.minusHours(2)));
        Memo memo2 = memoRepository.save(createMemo("Second memo", false, now.minusHours(1)));
        Memo memo3 = memoRepository.save(createMemo("Third memo", false, now));
        Memo deleted = memoRepository.save(createMemo("Deleted memo", true, now.minusMinutes(30)));

        List<Memo> results = memoRepository
            .findByMemberIdAndIsDeletedFalseOrderByCreatedAtDesc(testMemberId);

        assertThat(results).hasSize(3);
        assertThat(results.get(0).getContent()).isEqualTo("Third memo");
        assertThat(results.get(1).getContent()).isEqualTo("Second memo");
        assertThat(results.get(2).getContent()).isEqualTo("First memo");
        assertThat(results).noneMatch(Memo::getIsDeleted);
    }

    @Test
    void findFirstByMemberIdAndIsDeletedFalseOrderByCreatedAtDesc_shouldReturnLatestMemo() {
        LocalDateTime now = LocalDateTime.now();
        memoRepository.save(createMemo("Old memo", false, now.minusDays(1)));
        Memo latest = memoRepository.save(createMemo("Latest memo", false, now));

        Optional<Memo> result = memoRepository
            .findFirstByMemberIdAndIsDeletedFalseOrderByCreatedAtDesc(testMemberId);

        assertThat(result).isPresent();
        assertThat(result.get().getContent()).isEqualTo("Latest memo");
    }

    @Test
    void countByMemberIdAndIsDeletedFalse_shouldCountActiveMemos() {
        memoRepository.save(createMemo("Memo 1", false, null));
        memoRepository.save(createMemo("Memo 2", false, null));
        memoRepository.save(createMemo("Deleted memo", true, null));

        long count = memoRepository.countByMemberIdAndIsDeletedFalse(testMemberId);

        assertThat(count).isEqualTo(2);
    }

    @Test
    void findByMemberId_multipleMembers_shouldFilterByMemberId() {
        UUID member1 = UUID.randomUUID();
        UUID member2 = UUID.randomUUID();

        Memo memo1 = createMemo("Member1 Memo1", false, null);
        memo1.setMemberId(member1);
        memoRepository.save(memo1);

        Memo memo2 = createMemo("Member1 Memo2", false, null);
        memo2.setMemberId(member1);
        memoRepository.save(memo2);

        Memo memo3 = createMemo("Member2 Memo1", false, null);
        memo3.setMemberId(member2);
        memoRepository.save(memo3);

        List<Memo> results = memoRepository.findByMemberIdAndIsDeletedFalseOrderByCreatedAtDesc(member1);

        assertThat(results).hasSize(2);
        assertThat(results).allMatch(m -> m.getMemberId().equals(member1));
    }

    @Test
    void save_shouldGenerateIdAndTimestamps() {
        Memo memo = createMemo("Test memo", false, null);
        memo.setId(null);

        Memo saved = memoRepository.save(memo);

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
    }

    @Test
    void softDelete_shouldSetDeletedFlagsWithoutRemoving() {
        Memo memo = memoRepository.save(createMemo("Test memo", false, null));

        memo.setIsDeleted(true);
        memo.setDeletedAt(LocalDateTime.now());
        memo.setDeletedBy(UUID.randomUUID());
        memoRepository.save(memo);

        Optional<Memo> found = memoRepository.findById(memo.getId());
        assertThat(found).isPresent();
        assertThat(found.get().getIsDeleted()).isTrue();
        assertThat(found.get().getDeletedAt()).isNotNull();

        List<Memo> activeMemos = memoRepository
            .findByMemberIdAndIsDeletedFalseOrderByCreatedAtDesc(testMemberId);
        assertThat(activeMemos).doesNotContain(memo);
    }

    @Test
    void findByMemberIdAndIsDeletedTrueOrderByDeletedAtDesc_shouldReturnDeletedMemos() {
        LocalDateTime now = LocalDateTime.now();

        Memo deleted1 = createMemo("Deleted 1", true, now.minusHours(2));
        deleted1.setDeletedAt(now.minusHours(2));
        memoRepository.save(deleted1);

        Memo deleted2 = createMemo("Deleted 2", true, now.minusHours(1));
        deleted2.setDeletedAt(now.minusHours(1));
        memoRepository.save(deleted2);

        memoRepository.save(createMemo("Active memo", false, now));

        List<Memo> results = memoRepository
            .findByMemberIdAndIsDeletedTrueOrderByDeletedAtDesc(testMemberId);

        assertThat(results).hasSize(2);
        assertThat(results).allMatch(Memo::getIsDeleted);
        assertThat(results.get(0).getContent()).isEqualTo("Deleted 2");
        assertThat(results.get(1).getContent()).isEqualTo("Deleted 1");
    }

    @Test
    void update_shouldModifyUpdatedAtTimestamp() throws InterruptedException {
        Memo memo = memoRepository.save(createMemo("Original content", false, null));
        LocalDateTime originalUpdatedAt = memo.getUpdatedAt();

        Thread.sleep(100);

        memo.setContent("Updated content");
        Memo updated = memoRepository.save(memo);

        assertThat(updated.getContent()).isEqualTo("Updated content");
        assertThat(updated.getUpdatedAt()).isAfter(originalUpdatedAt);
        assertThat(updated.getCreatedAt()).isEqualTo(memo.getCreatedAt());
    }
}
