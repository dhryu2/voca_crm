package com.vocacrm.api.config;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.containers.PostgreSQLContainer;

/**
 * Testcontainers configuration for integration tests
 *
 * Provides a reusable PostgreSQL container using @ServiceConnection
 * for automatic datasource configuration in Spring Boot 3.1+
 *
 * Usage in test classes:
 * @Import(TestcontainersConfiguration.class)
 * or
 * @Testcontainers with static @Container field
 */
@TestConfiguration
public class TestcontainersConfiguration {

    /**
     * PostgreSQL container for testing
     *
     * @ServiceConnection auto-configures:
     * - spring.datasource.url
     * - spring.datasource.username
     * - spring.datasource.password
     *
     * Container is reused across tests when possible to improve speed
     */
    @Bean
    @ServiceConnection
    PostgreSQLContainer<?> postgresContainer() {
        return new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("voca_crm_test")
            .withUsername("test")
            .withPassword("test");
    }
}
