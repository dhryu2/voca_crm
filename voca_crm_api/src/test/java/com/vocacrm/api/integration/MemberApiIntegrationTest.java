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
 * Member API integration tests (REST Assured + @SpringBootTest)
 *
 * Test scope:
 * - Real HTTP request/response verification
 * - Full stack operation (Controller → Service → Repository → PostgreSQL)
 * - Server startup and API endpoint accessibility
 * - CRUD operations with actual data persistence
 *
 * EXEC-01, EXEC-02 requirements verification
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
 *    - See MemberController.java lines 97, 133, 172, 200, etc.
 *
 * Resolution path:
 * - Option 1: Create TestSecurityConfig that bypasses JWT and sets test user attributes
 * - Option 2: Generate valid JWT tokens in tests and configure JWT filter for test profile
 * - Option 3: Use MockMvc instead of REST Assured (loses real HTTP verification)
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@Disabled("Blocked by: (1) Testcontainers Docker connectivity, (2) Authentication middleware not configured for integration tests")
class MemberApiIntegrationTest {

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
    void createMember_shouldPersistAndReturnMember() {
        // Given
        String businessPlaceId = UUID.randomUUID().toString();
        String memberJson = String.format("""
            {
                "memberNumber": "INT-001",
                "name": "통합테스트 회원",
                "phone": "010-9999-8888",
                "email": "integration@test.com",
                "businessPlaceId": "%s"
            }
            """, businessPlaceId);

        // When & Then
        // NOTE: This test shows intended usage once authentication middleware is configured
        // Currently blocked because:
        // - Controllers require request.getAttribute("userId") which is set by JWT interceptor
        // - REST Assured HTTP client cannot set request attributes (server-side only)
        // - Need TestSecurityConfig to inject test user attributes
        given()
            .contentType(ContentType.JSON)
            .body(memberJson)
            // TODO: Add authentication headers once test security config exists
            // .header("Authorization", "Bearer test-token")
        .when()
            .post("/members")
        .then()
            .statusCode(200)
            .body("memberNumber", equalTo("INT-001"))
            .body("name", equalTo("통합테스트 회원"))
            .body("phone", equalTo("010-9999-8888"))
            .body("email", equalTo("integration@test.com"))
            .body("id", notNullValue())
            .body("createdAt", notNullValue())
            .body("updatedAt", notNullValue())
            .body("isDeleted", equalTo(false));
    }

    @Test
    void createAndRetrieveMember_shouldWorkEndToEnd() {
        // Step 1: Create member
        String businessPlaceId = UUID.randomUUID().toString();
        String memberJson = String.format("""
            {
                "memberNumber": "E2E-001",
                "name": "E2E 테스트",
                "phone": "010-1111-2222",
                "email": "e2e@test.com",
                "businessPlaceId": "%s"
            }
            """, businessPlaceId);

        String memberId = given()
            .contentType(ContentType.JSON)
            .body(memberJson)
        .when()
            .post("/members")
        .then()
            .statusCode(200)
            .extract().path("id");

        // Step 2: Retrieve created member
        // NOTE: Requires userId attribute from authentication middleware
        given()
        .when()
            .get("/members/" + memberId)
        .then()
            .statusCode(200)
            .body("id", equalTo(memberId))
            .body("memberNumber", equalTo("E2E-001"))
            .body("name", equalTo("E2E 테스트"));
    }

    @Test
    void updateMember_shouldModifyAndPersist() {
        // Step 1: Create member
        String businessPlaceId = UUID.randomUUID().toString();
        String createJson = String.format("""
            {
                "memberNumber": "UPD-001",
                "name": "수정 전",
                "phone": "010-0000-0000",
                "businessPlaceId": "%s"
            }
            """, businessPlaceId);

        String memberId = given()
            .contentType(ContentType.JSON)
            .body(createJson)
        .when()
            .post("/members")
        .then()
            .statusCode(200)
            .extract().path("id");

        // Step 2: Update member
        // NOTE: PUT /members/{id} requires userId and defaultBusinessPlaceId attributes
        String updateJson = """
            {
                "name": "수정 후",
                "phone": "010-9999-9999",
                "email": "updated@test.com"
            }
            """;

        given()
            .contentType(ContentType.JSON)
            .body(updateJson)
        .when()
            .put("/members/" + memberId)
        .then()
            .statusCode(200)
            .body("name", equalTo("수정 후"))
            .body("phone", equalTo("010-9999-9999"))
            .body("email", equalTo("updated@test.com"));

        // Step 3: Verify persistence
        given()
        .when()
            .get("/members/" + memberId)
        .then()
            .statusCode(200)
            .body("name", equalTo("수정 후"));
    }

    @Test
    void deleteMember_shouldSoftDelete() {
        // Step 1: Create member
        String businessPlaceId = UUID.randomUUID().toString();
        String createJson = String.format("""
            {
                "memberNumber": "DEL-001",
                "name": "삭제될 회원",
                "businessPlaceId": "%s"
            }
            """, businessPlaceId);

        String memberId = given()
            .contentType(ContentType.JSON)
            .body(createJson)
        .when()
            .post("/members")
        .then()
            .statusCode(200)
            .extract().path("id");

        // Step 2: Soft delete member
        // NOTE: DELETE /members/{id} requires userId and defaultBusinessPlaceId attributes
        given()
        .when()
            .delete("/members/" + memberId)
        .then()
            .statusCode(204);
    }

    @Test
    void softDeleteWithHeader_shouldReturnDeletedMember() {
        // Test soft delete endpoint that uses X-User-Id and X-Business-Place-Id headers
        // This endpoint is more suitable for integration testing as it uses headers instead of request attributes

        String businessPlaceId = UUID.randomUUID().toString();
        String userId = UUID.randomUUID().toString();

        String createJson = String.format("""
            {
                "memberNumber": "SOFT-001",
                "name": "소프트 삭제 테스트",
                "businessPlaceId": "%s"
            }
            """, businessPlaceId);

        String memberId = given()
            .contentType(ContentType.JSON)
            .body(createJson)
        .when()
            .post("/members")
        .then()
            .statusCode(200)
            .extract().path("id");

        // Soft delete with headers
        given()
            .header("X-User-Id", userId)
            .header("X-Business-Place-Id", businessPlaceId)
        .when()
            .delete("/members/" + memberId + "/soft")
        .then()
            .statusCode(200)
            .body("isDeleted", equalTo(true))
            .body("deletedAt", notNullValue())
            .body("deletedBy", notNullValue());
    }

    @Test
    void searchMembers_shouldFilterResults() {
        // NOTE: GET /members/search requires defaultBusinessPlaceId attribute
        // Search functionality cannot be tested without authentication middleware

        String businessPlaceId = UUID.randomUUID().toString();

        // Create test members
        createMemberViaApi("SEARCH-001", "김철수", businessPlaceId);
        createMemberViaApi("SEARCH-002", "김영희", businessPlaceId);
        createMemberViaApi("SEARCH-003", "이철수", businessPlaceId);

        // Search by name
        given()
            .param("name", "철수")
        .when()
            .get("/members/search")
        .then()
            .statusCode(200)
            .body("data", hasSize(greaterThanOrEqualTo(2)));
    }

    @Test
    void getAllMembers_shouldReturnPagedResults() {
        // NOTE: GET /members requires userId attribute for business place filtering
        // Pagination cannot be tested without authentication middleware

        given()
            .param("skip", "0")
            .param("limit", "10")
        .when()
            .get("/members")
        .then()
            .statusCode(200)
            .body("content", isA(java.util.List.class))
            .body("totalElements", notNullValue())
            .body("totalPages", notNullValue());
    }

    private void createMemberViaApi(String memberNumber, String name, String businessPlaceId) {
        String json = String.format("""
            {
                "memberNumber": "%s",
                "name": "%s",
                "phone": "010-0000-0000",
                "businessPlaceId": "%s"
            }
            """, memberNumber, name, businessPlaceId);

        given()
            .contentType(ContentType.JSON)
            .body(json)
        .when()
            .post("/members")
        .then()
            .statusCode(200);
    }
}
