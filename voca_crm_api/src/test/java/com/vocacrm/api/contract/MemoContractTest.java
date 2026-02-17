package com.vocacrm.api.contract;

import io.restassured.RestAssured;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.testcontainers.junit.jupiter.Testcontainers;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Memo API Contract Tests
 *
 * Validates that Memo endpoints return expected schemas for Flutter client.
 * From Phase 1 audit: Memo endpoints use direct object response (not wrapped).
 *
 * Blocked by: Docker connectivity issue + authentication middleware
 * Enable after: Docker environment fixed AND TestSecurityConfig created
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@Disabled("Blocked by Docker connectivity + authentication middleware - see 02-04-SUMMARY.md")
class MemoContractTest {

    @LocalServerPort
    private int port;

    @BeforeEach
    void setUp() {
        RestAssured.port = port;
    }

    /**
     * Contract: GET /api/memos/{id} returns direct Memo object
     * Flutter expects: { id, memberId, content, createdAt, updatedAt }
     */
    @Test
    void getMemoById_shouldReturnDirectMemoObject() {
        String memoId = "test-memo-id";

        given()
            .header("Authorization", "Bearer test-token")
        .when()
            .get("/api/memos/{id}", memoId)
        .then()
            .statusCode(200)
            .contentType("application/json")
            .body("id", equalTo(memoId))
            .body("memberId", notNullValue())
            .body("content", notNullValue())
            .body("createdAt", notNullValue())
            .body("updatedAt", notNullValue())
            .body("$", not(hasKey("data")));
    }

    /**
     * Contract: GET /api/memos/member/{memberId} returns direct list (NOT wrapped)
     * Flutter expects: [Memo...]
     */
    @Test
    void getMemosByMemberId_shouldReturnDirectList() {
        String memberId = "test-member-id";

        given()
            .header("Authorization", "Bearer test-token")
        .when()
            .get("/api/memos/member/{memberId}", memberId)
        .then()
            .statusCode(200)
            .contentType("application/json")
            .body("$", isA(java.util.List.class))
            .body("[0].id", notNullValue())
            .body("[0].memberId", equalTo(memberId))
            .body("[0].content", notNullValue())
            .body("$", not(hasKey("data")));
    }

    /**
     * Contract: POST /api/memos returns created Memo object
     * Flutter expects: 201 status with direct Memo object
     */
    @Test
    void createMemo_shouldReturnCreatedMemo() {
        String requestBody = """
            {
                "memberId": "test-member-id",
                "content": "Test memo content"
            }
            """;

        given()
            .header("Authorization", "Bearer test-token")
            .contentType("application/json")
            .body(requestBody)
        .when()
            .post("/api/memos")
        .then()
            .statusCode(201)
            .contentType("application/json")
            .body("id", notNullValue())
            .body("memberId", equalTo("test-member-id"))
            .body("content", equalTo("Test memo content"))
            .body("createdAt", notNullValue());
    }

    /**
     * Contract: PUT /api/memos/{id} returns updated Memo object
     * Flutter expects: 200 status with updated Memo object
     */
    @Test
    void updateMemo_shouldReturnUpdatedMemo() {
        String memoId = "test-memo-id";
        String requestBody = """
            {
                "content": "Updated memo content"
            }
            """;

        given()
            .header("Authorization", "Bearer test-token")
            .contentType("application/json")
            .body(requestBody)
        .when()
            .put("/api/memos/{id}", memoId)
        .then()
            .statusCode(200)
            .contentType("application/json")
            .body("id", equalTo(memoId))
            .body("content", equalTo("Updated memo content"))
            .body("updatedAt", notNullValue());
    }

    /**
     * Contract: Error responses have status, message, and code fields
     * Flutter expects: { status: 404, message: "...", code: "MEMO_NOT_FOUND" }
     */
    @Test
    void getMemoById_notFound_shouldReturnStandardErrorFormat() {
        given()
            .header("Authorization", "Bearer test-token")
        .when()
            .get("/api/memos/{id}", "non-existent-id")
        .then()
            .statusCode(404)
            .contentType("application/json")
            .body("status", equalTo(404))
            .body("message", notNullValue())
            .body("code", anyOf(
                equalTo("RESOURCE_NOT_FOUND"),
                equalTo("MEMO_NOT_FOUND")
            ));
    }
}
