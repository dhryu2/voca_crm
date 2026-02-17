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
 * Member API Contract Tests
 *
 * Validates that Member endpoints return expected schemas for Flutter client.
 * From Phase 1 audit: Member endpoints use direct object response (not wrapped).
 *
 * Blocked by: Docker connectivity issue + authentication middleware
 * Enable after: Docker environment fixed AND TestSecurityConfig created
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@Disabled("Blocked by Docker connectivity + authentication middleware - see 02-04-SUMMARY.md")
class MemberContractTest {

    @LocalServerPort
    private int port;

    @BeforeEach
    void setUp() {
        RestAssured.port = port;
    }

    /**
     * Contract: GET /api/members/{id} returns direct Member object
     * Flutter expects: { id, memberNumber, name, phone?, email?, createdAt, updatedAt }
     */
    @Test
    void getMemberById_shouldReturnDirectMemberObject() {
        String memberId = "test-member-id";

        given()
            .header("Authorization", "Bearer test-token")
        .when()
            .get("/api/members/{id}", memberId)
        .then()
            .statusCode(200)
            .contentType("application/json")
            .body("id", equalTo(memberId))
            .body("memberNumber", notNullValue())
            .body("name", notNullValue())
            .body("phone", anything())
            .body("email", anything())
            .body("createdAt", notNullValue())
            .body("updatedAt", notNullValue())
            .body("$", not(hasKey("data")));
    }

    /**
     * Contract: GET /api/members/search returns wrapped list {"data": [...]}
     * Flutter expects: { data: [Member...] }
     */
    @Test
    void searchMembers_shouldReturnWrappedList() {
        given()
            .header("Authorization", "Bearer test-token")
            .queryParam("memberNumber", "123")
        .when()
            .get("/api/members/search")
        .then()
            .statusCode(200)
            .contentType("application/json")
            .body("data", isA(java.util.List.class))
            .body("data[0].id", notNullValue())
            .body("data[0].memberNumber", notNullValue())
            .body("data[0].name", notNullValue());
    }

    /**
     * Contract: POST /api/members returns created Member object
     * Flutter expects: 201 status with direct Member object
     */
    @Test
    void createMember_shouldReturnCreatedMember() {
        String requestBody = """
            {
                "memberNumber": "123456",
                "name": "Test Member",
                "phone": "010-1234-5678",
                "email": "test@example.com"
            }
            """;

        given()
            .header("Authorization", "Bearer test-token")
            .contentType("application/json")
            .body(requestBody)
        .when()
            .post("/api/members")
        .then()
            .statusCode(201)
            .contentType("application/json")
            .body("id", notNullValue())
            .body("memberNumber", equalTo("123456"))
            .body("name", equalTo("Test Member"))
            .body("createdAt", notNullValue());
    }

    /**
     * Contract: Error responses have status, message, and code fields
     * Flutter expects: { status: 404, message: "...", code: "RESOURCE_NOT_FOUND" }
     */
    @Test
    void getMemberById_notFound_shouldReturnStandardErrorFormat() {
        given()
            .header("Authorization", "Bearer test-token")
        .when()
            .get("/api/members/{id}", "non-existent-id")
        .then()
            .statusCode(404)
            .contentType("application/json")
            .body("status", equalTo(404))
            .body("message", notNullValue())
            .body("code", equalTo("RESOURCE_NOT_FOUND"));
    }

    /**
     * Contract: Validation errors return fieldErrors map
     * Flutter expects: { status: 400, message: "...", code: "VALIDATION_ERROR", fieldErrors: {...} }
     */
    @Test
    void createMember_validationError_shouldReturnFieldErrors() {
        String invalidRequest = """
            {
                "memberNumber": "",
                "name": ""
            }
            """;

        given()
            .header("Authorization", "Bearer test-token")
            .contentType("application/json")
            .body(invalidRequest)
        .when()
            .post("/api/members")
        .then()
            .statusCode(400)
            .contentType("application/json")
            .body("status", equalTo(400))
            .body("error", equalTo("VALIDATION_ERROR"))
            .body("fieldErrors", notNullValue())
            .body("errorCount", greaterThan(0));
    }
}
