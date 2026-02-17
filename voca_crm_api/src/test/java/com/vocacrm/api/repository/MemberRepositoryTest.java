package com.vocacrm.api.repository;

import com.vocacrm.api.model.Member;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
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
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * MemberRepository integration tests using Testcontainers PostgreSQL
 *
 * Test scope:
 * - JPA query methods execution against PostgreSQL
 * - Custom query verification
 * - Soft delete filtering (isDeleted=false)
 * - Pagination and sorting
 *
 * NOTE: Tests are currently disabled due to Testcontainers Docker connectivity issue
 * documented in 02-01-SUMMARY. Docker Desktop 4.55.0 incompatible with Testcontainers 1.20.4.
 * Error: "Could not find a valid Docker environment" with HTTP 400 BadRequestException.
 * Tests will run once Docker environment is updated or Testcontainers version is upgraded.
 */
@SpringBootTest
@Testcontainers
@Transactional
@Disabled("Testcontainers Docker connectivity issue - see .planning/phases/02-api-testing-infrastructure/02-01-SUMMARY.md")
class MemberRepositoryTest {

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
    private MemberRepository memberRepository;

    private String testBusinessPlaceId;

    @BeforeEach
    void setUp() {
        testBusinessPlaceId = "BIZ" + String.format("%04d", (int)(Math.random() * 10000));
        memberRepository.deleteAll();
    }

    private Member createMember(String memberNumber, boolean isDeleted) {
        Member member = new Member();
        member.setMemberNumber(memberNumber);
        member.setName("Test Member " + memberNumber);
        member.setPhone("010-1234-5678");
        member.setEmail(memberNumber + "@test.com");
        member.setBusinessPlaceId(testBusinessPlaceId);
        member.setCreatedAt(LocalDateTime.now());
        member.setUpdatedAt(LocalDateTime.now());
        member.setIsDeleted(isDeleted);
        if (isDeleted) {
            member.setDeletedAt(LocalDateTime.now());
            member.setDeletedBy(UUID.randomUUID());
        }
        return member;
    }

    @Test
    void findById_shouldReturnMember() {
        Member saved = memberRepository.save(createMember("M001", false));

        Optional<Member> found = memberRepository.findById(saved.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getMemberNumber()).isEqualTo("M001");
    }

    @Test
    void findByBusinessPlaceIdAndIsDeletedFalse_shouldReturnOnlyActiveMembers() {
        Member active1 = memberRepository.save(createMember("M001", false));
        Member active2 = memberRepository.save(createMember("M002", false));
        Member deleted = memberRepository.save(createMember("M003", true));

        List<Member> results = memberRepository
            .findByBusinessPlaceIdAndIsDeletedFalse(testBusinessPlaceId);

        assertThat(results).hasSize(2);
        assertThat(results).extracting(Member::getMemberNumber)
            .containsExactlyInAnyOrder("M001", "M002");
        assertThat(results).noneMatch(Member::getIsDeleted);
    }

    @Test
    void findByIsDeletedFalse_withPagination_shouldReturnPagedResults() {
        for (int i = 1; i <= 5; i++) {
            memberRepository.save(createMember("M" + String.format("%03d", i), false));
        }

        Page<Member> page = memberRepository
            .findByIsDeletedFalse(PageRequest.of(0, 3));

        assertThat(page.getContent()).hasSize(3);
        assertThat(page.getTotalElements()).isEqualTo(5);
        assertThat(page.getTotalPages()).isEqualTo(2);
    }

    @Test
    void findByMemberNumberAndBusinessPlaceIdAndIsDeletedFalse_shouldFilterByNumber() {
        memberRepository.save(createMember("TEST-001", false));
        memberRepository.save(createMember("TEST-002", false));
        memberRepository.save(createMember("PROD-001", false));

        List<Member> results = memberRepository
            .findByMemberNumberAndBusinessPlaceIdAndIsDeletedFalse(
                "TEST-001",
                testBusinessPlaceId
            );

        assertThat(results).hasSize(1);
        assertThat(results.get(0).getMemberNumber()).isEqualTo("TEST-001");
    }

    @Test
    void findByNameContainingAndBusinessPlaceIdAndIsDeletedFalse_shouldFilterByName() {
        Member member1 = createMember("M001", false);
        member1.setName("Kim Chulsu");
        memberRepository.save(member1);

        Member member2 = createMember("M002", false);
        member2.setName("Kim Younghee");
        memberRepository.save(member2);

        Member member3 = createMember("M003", false);
        member3.setName("Lee Chulsu");
        memberRepository.save(member3);

        List<Member> results = memberRepository
            .findByNameContainingAndBusinessPlaceIdAndIsDeletedFalse(
                "Chulsu",
                testBusinessPlaceId
            );

        assertThat(results).hasSize(2);
        assertThat(results).extracting(Member::getName)
            .allMatch(name -> name.contains("Chulsu"));
    }

    @Test
    void findByPhoneContainingAndBusinessPlaceIdAndIsDeletedFalse_shouldFilterByPhone() {
        Member member1 = createMember("M001", false);
        member1.setPhone("010-1111-2222");
        memberRepository.save(member1);

        Member member2 = createMember("M002", false);
        member2.setPhone("010-3333-4444");
        memberRepository.save(member2);

        Member member3 = createMember("M003", false);
        member3.setPhone("010-1111-9999");
        memberRepository.save(member3);

        List<Member> results = memberRepository
            .findByPhoneContainingAndBusinessPlaceIdAndIsDeletedFalse(
                "1111",
                testBusinessPlaceId
            );

        assertThat(results).hasSize(2);
        assertThat(results).extracting(Member::getPhone)
            .allMatch(phone -> phone.contains("1111"));
    }

    @Test
    void findByEmailContainingAndBusinessPlaceIdAndIsDeletedFalse_shouldFilterByEmail() {
        Member member1 = createMember("M001", false);
        member1.setEmail("test001@gmail.com");
        memberRepository.save(member1);

        Member member2 = createMember("M002", false);
        member2.setEmail("test002@gmail.com");
        memberRepository.save(member2);

        Member member3 = createMember("M003", false);
        member3.setEmail("prod001@naver.com");
        memberRepository.save(member3);

        List<Member> results = memberRepository
            .findByEmailContainingAndBusinessPlaceIdAndIsDeletedFalse(
                "gmail",
                testBusinessPlaceId
            );

        assertThat(results).hasSize(2);
        assertThat(results).extracting(Member::getEmail)
            .allMatch(email -> email.contains("gmail"));
    }

    @Test
    void save_shouldGenerateIdAndTimestamps() {
        Member member = createMember("M001", false);
        member.setId(null);

        Member saved = memberRepository.save(member);

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
    }

    @Test
    void softDelete_shouldSetDeletedFlagsWithoutRemoving() {
        Member member = memberRepository.save(createMember("M001", false));

        member.setIsDeleted(true);
        member.setDeletedAt(LocalDateTime.now());
        member.setDeletedBy(UUID.randomUUID());
        memberRepository.save(member);

        Optional<Member> found = memberRepository.findById(member.getId());
        assertThat(found).isPresent();
        assertThat(found.get().getIsDeleted()).isTrue();
        assertThat(found.get().getDeletedAt()).isNotNull();
        assertThat(found.get().getDeletedBy()).isNotNull();

        List<Member> activeMembers = memberRepository
            .findByBusinessPlaceIdAndIsDeletedFalse(testBusinessPlaceId);
        assertThat(activeMembers).doesNotContain(member);
    }

    @Test
    void countByBusinessPlaceIdAndIsDeletedFalse_shouldCountActiveMembers() {
        memberRepository.save(createMember("M001", false));
        memberRepository.save(createMember("M002", false));
        memberRepository.save(createMember("M003", true));

        long count = memberRepository.countByBusinessPlaceIdAndIsDeletedFalse(testBusinessPlaceId);

        assertThat(count).isEqualTo(2);
    }

    @Test
    void findByBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc_shouldReturnDeletedMembers() {
        LocalDateTime now = LocalDateTime.now();

        Member deleted1 = createMember("M001", true);
        deleted1.setDeletedAt(now.minusHours(2));
        memberRepository.save(deleted1);

        Member deleted2 = createMember("M002", true);
        deleted2.setDeletedAt(now.minusHours(1));
        memberRepository.save(deleted2);

        memberRepository.save(createMember("M003", false));

        List<Member> results = memberRepository
            .findByBusinessPlaceIdAndIsDeletedTrueOrderByDeletedAtDesc(testBusinessPlaceId);

        assertThat(results).hasSize(2);
        assertThat(results).allMatch(Member::getIsDeleted);
        assertThat(results.get(0).getMemberNumber()).isEqualTo("M002");
        assertThat(results.get(1).getMemberNumber()).isEqualTo("M001");
    }

    @Test
    void countByBusinessPlaceId_shouldCountAllMembers() {
        memberRepository.save(createMember("M001", false));
        memberRepository.save(createMember("M002", false));
        memberRepository.save(createMember("M003", true));

        long count = memberRepository.countByBusinessPlaceId(testBusinessPlaceId);

        assertThat(count).isEqualTo(3);
    }
}
