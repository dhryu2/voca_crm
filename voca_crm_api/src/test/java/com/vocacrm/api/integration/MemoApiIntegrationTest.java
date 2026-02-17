package com.vocacrm.api.integration;

import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Memo API integration tests (REST Assured + @SpringBootTest)
 *
 * Test scope:
 * - Memo CRUD full stack verification
 * - Member-specific memo retrieval APIs
 * - Latest memo retrieval API
 * - Soft delete operation
 *
 * NOTE: Tests currently disabled due to two blockers:
 *
 * 1. Testcontainers Docker connectivity issue (documented in 02-01-SUMMARY):
 *    - Docker Desktop 4.55.0 incompatible with Testcontainers 1.20.4
 *    - Error: "Could not find a valid Docker environment" with HTTP 400
 *    - Tests will run once Docker environment is updated
 *
 * 2. Authentication middleware not configured for integration tests:
 *    - Controllers expect request attributes (userId, defaultBusinessPlaceId) set by JWT interceptor
 *    - REST Assured makes real HTTP calls, cannot directly inject request attributes
 *    - Requires test-specific authentication middleware or mock JWT token handler
 *    - See MemoController.java lines 99, 134, 201, 263, etc.
 *
 * Resolution: Same as MemberApiIntegrationTest - needs TestSecurityConfig or JWT test setup
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@Disabled("Blocked by: (1) Testcontainers Docker connectivity, (2) Authentication middleware not configured for integration tests")
class MemoApiIntegrationTest {

    @LocalServerPort
    private int port;

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

    @BeforeEach
    void setUp() {
        RestAssured.port = port;
        RestAssured.basePath = "/api";
    }

    @Test
    void createMemo_shouldPersistAndReturn() {
        // Given
        UUID memberId = UUID.randomUUID();
        String businessPlaceId = UUID.randomUUID().toString();
        String memoJson = String.format("""
            {
                "memberId": "%s",
                "content": "통합테스트 메모 내용",
                "businessPlaceId": "%s"
            }
            """, memberId, businessPlaceId);

        // When & Then
        // NOTE: POST /memos requires userId attribute from JWT interceptor
        given()
            .contentType(ContentType.JSON)
            .body(memoJson)
        .when()
            .post("/memos")
        .then()
            .statusCode(200)
            .body("content", equalTo("통합테스트 메모 내용"))
            .body("memberId", equalTo(memberId.toString()))
            .body("id", notNullValue())
            .body("isDeleted", equalTo(false));
    }

    @Test
    void createAndRetrieveMemo_shouldWorkEndToEnd() {
        // Step 1: Create memo
        UUID memberId = UUID.randomUUID();
        String businessPlaceId = UUID.randomUUID().toString();
        String memoJson = String.format("""
            {
                "memberId": "%s",
                "content": "E2E 메모",
                "businessPlaceId": "%s"
            }
            """, memberId, businessPlaceId);

        String memoId = given()
            .contentType(ContentType.JSON)
            .body(memoJson)
        .when()
            .post("/memos")
        .then()
            .statusCode(200)
            .extract().path("id");

        // Step 2: Retrieve memo
        // NOTE: GET /memos/{id} requires defaultBusinessPlaceId attribute
        given()
        .when()
            .get("/memos/" + memoId)
        .then()
            .statusCode(200)
            .body("id", equalTo(memoId))
            .body("content", equalTo("E2E 메모"));
    }

    @Test
    void getMemosByMemberId_shouldReturnMemberMemos() {
        // NOTE: GET /memos/member/{memberId} requires userId attribute for access control
        // This test shows intended usage once authentication middleware is configured

        UUID memberId = UUID.randomUUID();
        String businessPlaceId = UUID.randomUUID().toString();

        // Create multiple memos for same member
        createMemoViaApi(memberId, "첫 번째 메모", businessPlaceId);
        createMemoViaApi(memberId, "두 번째 메모", businessPlaceId);
        createMemoViaApi(memberId, "세 번째 메모", businessPlaceId);

        // Get all memos for member
        given()
        .when()
            .get("/memos/member/" + memberId)
        .then()
            .statusCode(200)
            .body("data", hasSize(greaterThanOrEqualTo(3)))
            .body("data.content", hasItems("첫 번째 메모", "두 번째 메모", "세 번째 메모"));
    }

    @Test
    void getLatestMemoByMemberId_shouldReturnNewestMemo() throws Exception {
        // NOTE: GET /memos/member/{memberId}/latest requires userId attribute

        UUID memberId = UUID.randomUUID();
        String businessPlaceId = UUID.randomUUID().toString();

        // Create multiple memos
        createMemoViaApi(memberId, "오래된 메모", businessPlaceId);
        Thread.sleep(100);  // Ensure different timestamps
        createMemoViaApi(memberId, "최신 메모", businessPlaceId);

        // Get latest memo
        given()
        .when()
            .get("/memos/member/" + memberId + "/latest")
        .then()
            .statusCode(200)
            .body("content", equalTo("최신 메모"));
    }

    @Test
    void updateMemo_shouldModifyContent() {
        // Step 1: Create memo
        UUID memberId = UUID.randomUUID();
        String businessPlaceId = UUID.randomUUID().toString();
        String memoId = createMemoViaApi(memberId, "수정 전 내용", businessPlaceId);

        // Step 2: Update memo
        // NOTE: PUT /memos/{id} requires userId and defaultBusinessPlaceId attributes
        String updateJson = """
            {
                "content": "수정 후 내용"
            }
            """;

        given()
            .contentType(ContentType.JSON)
            .body(updateJson)
        .when()
            .put("/memos/" + memoId)
        .then()
            .statusCode(200)
            .body("content", equalTo("수정 후 내용"));
    }

    @Test
    void deleteMemo_shouldRemoveMemo() {
        // Step 1: Create memo
        UUID memberId = UUID.randomUUID();
        String businessPlaceId = UUID.randomUUID().toString();
        String memoId = createMemoViaApi(memberId, "삭제될 메모", businessPlaceId);

        // Step 2: Delete memo
        // NOTE: DELETE /memos/{id} requires userId and defaultBusinessPlaceId attributes
        given()
        .when()
            .delete("/memos/" + memoId)
        .then()
            .statusCode(204);
    }

    @Test
    void softDeleteMemo_shouldMarkAsDeleted() {
        // Test soft delete endpoint that uses X-User-Id and X-Business-Place-Id headers
        // This is more suitable for integration testing

        UUID memberId = UUID.randomUUID();
        String businessPlaceId = UUID.randomUUID().toString();
        String userId = UUID.randomUUID().toString();

        String memoJson = String.format("""
            {
                "memberId": "%s",
                "content": "소프트 삭제 테스트",
                "businessPlaceId": "%s"
            }
            """, memberId, businessPlaceId);

        String memoId = given()
            .contentType(ContentType.JSON)
            .body(memoJson)
        .when()
            .post("/memos")
        .then()
            .statusCode(200)
            .extract().path("id");

        // Soft delete with headers
        given()
            .header("X-User-Id", userId)
            .header("X-Business-Place-Id", businessPlaceId)
        .when()
            .delete("/memos/" + memoId + "/soft")
        .then()
            .statusCode(200)
            .body("isDeleted", equalTo(true))
            .body("deletedAt", notNullValue());
    }

    @Test
    void getMemosByBusinessPlace_shouldReturnBusinessPlaceMemos() {
        // NOTE: GET /memos/by-business-place/{businessPlaceId} requires userId attribute

        String businessPlaceId = UUID.randomUUID().toString();
        UUID memberId1 = UUID.randomUUID();
        UUID memberId2 = UUID.randomUUID();

        // Create memos for different members in same business place
        createMemoViaApi(memberId1, "회원1 메모", businessPlaceId);
        createMemoViaApi(memberId2, "회원2 메모", businessPlaceId);

        given()
        .when()
            .get("/memos/by-business-place/" + businessPlaceId)
        .then()
            .statusCode(200)
            .body("$", hasSize(greaterThanOrEqualTo(2)));
    }

    @Test
    void createMemoWithDeletion_shouldDeleteOldestWhenLimitExceeded() {
        // Test memo creation with automatic oldest deletion
        // NOTE: POST /memos/with-deletion requires userId attribute

        UUID memberId = UUID.randomUUID();
        String businessPlaceId = UUID.randomUUID().toString();

        String memoJson = String.format("""
            {
                "memberId": "%s",
                "content": "자동 삭제 테스트 메모",
                "businessPlaceId": "%s"
            }
            """, memberId, businessPlaceId);

        given()
            .contentType(ContentType.JSON)
            .body(memoJson)
        .when()
            .post("/memos/with-deletion")
        .then()
            .statusCode(200)
            .body("content", equalTo("자동 삭제 테스트 메모"))
            .body("id", notNullValue());
    }

    @Test
    void toggleImportant_shouldUpdateImportanceFlag() {
        // Step 1: Create memo
        UUID memberId = UUID.randomUUID();
        String businessPlaceId = UUID.randomUUID().toString();

        String memoJson = String.format("""
            {
                "memberId": "%s",
                "content": "중요도 토글 테스트",
                "businessPlaceId": "%s",
                "isImportant": false
            }
            """, memberId, businessPlaceId);

        String memoId = given()
            .contentType(ContentType.JSON)
            .body(memoJson)
        .when()
            .post("/memos")
        .then()
            .statusCode(200)
            .extract().path("id");

        // Step 2: Toggle importance
        // NOTE: PATCH /memos/{id}/toggle-important requires userId and defaultBusinessPlaceId
        given()
        .when()
            .patch("/memos/" + memoId + "/toggle-important")
        .then()
            .statusCode(200)
            .body("isImportant", equalTo(true));
    }

    private String createMemoViaApi(UUID memberId, String content, String businessPlaceId) {
        String json = String.format("""
            {
                "memberId": "%s",
                "content": "%s",
                "businessPlaceId": "%s"
            }
            """, memberId, content, businessPlaceId);

        return given()
            .contentType(ContentType.JSON)
            .body(json)
        .when()
            .post("/memos")
        .then()
            .statusCode(200)
            .extract().path("id");
    }
}
