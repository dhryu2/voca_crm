package com.vocacrm.api.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vocacrm.api.dto.request.MemoCreateRequest;
import com.vocacrm.api.dto.request.MemoUpdateRequest;
import com.vocacrm.api.model.Member;
import com.vocacrm.api.model.Memo;
import com.vocacrm.api.repository.MemberRepository;
import com.vocacrm.api.repository.MemoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.LocalDateTime;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * MemoController integration tests using @SpringBootTest
 *
 * Test scope:
 * - Memo CRUD endpoint HTTP layer verification
 * - Member-specific memo query API verification
 * - Latest memo query API verification
 *
 * NOTE: Tests are currently disabled due to Testcontainers Docker connectivity issue
 * documented in 02-01-SUMMARY. Docker Desktop 4.55.0 incompatible with Testcontainers 1.20.4.
 * Error: "Could not find a valid Docker environment" with HTTP 400 BadRequestException.
 * Tests will run once Docker environment is updated or Testcontainers version is upgraded.
 *
 * Spring Boot 4.0.0 compatibility note:
 * Uses manual MockMvc setup via MockMvcBuilders.webAppContextSetup() because
 * @AutoConfigureMockMvc annotation is not available in Spring Boot 4.0.0.
 */
@SpringBootTest
@Testcontainers
@Transactional
@Disabled("Testcontainers Docker connectivity issue - see .planning/phases/02-api-testing-infrastructure/02-01-SUMMARY.md")
class MemoControllerTest {

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
    private WebApplicationContext webApplicationContext;

    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private MemoRepository memoRepository;

    @Autowired
    private MemberRepository memberRepository;

    private String testBusinessPlaceId;
    private String testUserId;
    private Member testMember;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext).build();
        testBusinessPlaceId = "BIZ" + String.format("%04d", (int)(Math.random() * 10000));
        testUserId = "USER" + String.format("%04d", (int)(Math.random() * 10000));
        memoRepository.deleteAll();
        memberRepository.deleteAll();

        testMember = new Member();
        testMember.setMemberNumber("TEST-001");
        testMember.setName("Test Member");
        testMember.setPhone("010-1234-5678");
        testMember.setBusinessPlaceId(testBusinessPlaceId);
        testMember.setCreatedAt(LocalDateTime.now());
        testMember.setUpdatedAt(LocalDateTime.now());
        testMember.setIsDeleted(false);
        testMember = memberRepository.save(testMember);
    }

    private Memo createTestMemo() {
        Memo memo = new Memo();
        memo.setMemberId(testMember.getId());
        memo.setContent("Test memo content");
        memo.setCreatedAt(LocalDateTime.now());
        memo.setUpdatedAt(LocalDateTime.now());
        memo.setIsDeleted(false);
        memo.setIsImportant(false);
        return memoRepository.save(memo);
    }

    @Test
    void getMemoById_shouldReturnMemo() throws Exception {
        Memo memo = createTestMemo();

        mockMvc.perform(get("/api/memos/{id}", memo.getId())
                .requestAttr("defaultBusinessPlaceId", testBusinessPlaceId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(memo.getId().toString()))
            .andExpect(jsonPath("$.content").value("Test memo content"));
    }

    @Test
    void getMemosByBusinessPlace_shouldReturnMemoList() throws Exception {
        createTestMemo();
        createTestMemo();

        mockMvc.perform(get("/api/memos/by-business-place/{businessPlaceId}", testBusinessPlaceId)
                .requestAttr("userId", testUserId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$").isArray());
    }

    @Test
    void getMemosByMemberId_shouldReturnMemoList() throws Exception {
        createTestMemo();
        createTestMemo();

        mockMvc.perform(get("/api/memos/member/{memberId}", testMember.getId())
                .requestAttr("userId", testUserId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data").isArray());
    }

    @Test
    void getLatestMemo_shouldReturnLatestMemo() throws Exception {
        createTestMemo();
        Memo latest = createTestMemo();

        mockMvc.perform(get("/api/memos/member/{memberId}/latest", testMember.getId())
                .requestAttr("userId", testUserId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content").value("Test memo content"));
    }

    @Test
    void getLatestMemo_whenNoMemos_shouldReturn404() throws Exception {
        mockMvc.perform(get("/api/memos/member/{memberId}/latest", testMember.getId())
                .requestAttr("userId", testUserId))
            .andExpect(status().isNotFound());
    }

    @Test
    void createMemo_withValidData_shouldReturn200() throws Exception {
        MemoCreateRequest request = new MemoCreateRequest();
        request.setMemberId(testMember.getId().toString());
        request.setContent("New memo content");

        mockMvc.perform(post("/api/memos")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
                .requestAttr("userId", testUserId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content").value("New memo content"));
    }

    @Test
    void createMemoWithDeletion_shouldReturn200() throws Exception {
        MemoCreateRequest request = new MemoCreateRequest();
        request.setMemberId(testMember.getId().toString());
        request.setContent("New memo with deletion");

        mockMvc.perform(post("/api/memos/with-deletion")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
                .requestAttr("userId", testUserId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content").exists());
    }

    @Test
    void updateMemo_withValidData_shouldReturn200() throws Exception {
        Memo memo = createTestMemo();

        MemoUpdateRequest request = new MemoUpdateRequest();
        request.setContent("Updated memo content");

        mockMvc.perform(put("/api/memos/{id}", memo.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
                .requestAttr("userId", testUserId)
                .requestAttr("defaultBusinessPlaceId", testBusinessPlaceId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content").value("Updated memo content"));
    }

    @Test
    void deleteMemo_shouldReturn204() throws Exception {
        Memo memo = createTestMemo();

        mockMvc.perform(delete("/api/memos/{id}", memo.getId())
                .requestAttr("userId", testUserId)
                .requestAttr("defaultBusinessPlaceId", testBusinessPlaceId))
            .andExpect(status().isNoContent());
    }

    @Test
    void softDeleteMemo_shouldReturn200() throws Exception {
        Memo memo = createTestMemo();

        mockMvc.perform(delete("/api/memos/{id}/soft", memo.getId())
                .header("X-User-Id", testUserId)
                .header("X-Business-Place-Id", testBusinessPlaceId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.isDeleted").value(true))
            .andExpect(jsonPath("$.deletedAt").exists());
    }

    @Test
    void getDeletedMemos_shouldReturnDeletedMemoList() throws Exception {
        mockMvc.perform(get("/api/memos/deleted")
                .param("businessPlaceId", testBusinessPlaceId)
                .requestAttr("userId", testUserId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data").isArray());
    }

    @Test
    void getDeletedMemosByMember_shouldReturnDeletedMemoList() throws Exception {
        mockMvc.perform(get("/api/memos/member/{memberId}/deleted", testMember.getId())
                .requestAttr("userId", testUserId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data").isArray());
    }

    @Test
    void restoreMemo_shouldReturn200() throws Exception {
        Memo memo = createTestMemo();
        memo.setIsDeleted(true);
        memo.setDeletedAt(LocalDateTime.now());
        memo.setDeletedBy(UUID.randomUUID());
        memoRepository.save(memo);

        mockMvc.perform(post("/api/memos/{id}/restore", memo.getId())
                .header("X-User-Id", testUserId)
                .header("X-Business-Place-Id", testBusinessPlaceId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.isDeleted").value(false));
    }

    @Test
    void permanentDeleteMemo_shouldReturn204() throws Exception {
        Memo memo = createTestMemo();
        memo.setIsDeleted(true);
        memo.setDeletedAt(LocalDateTime.now());
        memo.setDeletedBy(UUID.randomUUID());
        memoRepository.save(memo);

        mockMvc.perform(delete("/api/memos/{id}/permanent", memo.getId())
                .header("X-User-Id", testUserId)
                .header("X-Business-Place-Id", testBusinessPlaceId))
            .andExpect(status().isNoContent());
    }

    @Test
    void toggleImportant_shouldReturn200() throws Exception {
        Memo memo = createTestMemo();

        mockMvc.perform(patch("/api/memos/{id}/toggle-important", memo.getId())
                .requestAttr("userId", testUserId)
                .requestAttr("defaultBusinessPlaceId", testBusinessPlaceId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.isImportant").value(true));
    }
}
