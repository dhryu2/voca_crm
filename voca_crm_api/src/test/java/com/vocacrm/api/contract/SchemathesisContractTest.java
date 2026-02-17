package com.vocacrm.api.contract;

import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * OpenAPI Contract Validation using Schemathesis
 *
 * Validates API endpoints match OpenAPI spec using property-based testing.
 * From research: Schemathesis detects 1.4x-4.5x more defects than manual tests.
 *
 * Requirements:
 * - Schemathesis installed (pip install schemathesis)
 * - API server running on localhost:8080
 *
 * @see <a href="https://schemathesis.io/">Schemathesis Documentation</a>
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.DEFINED_PORT)
@Disabled("Requires Schemathesis installation and running API server - enable when ready")
class SchemathesisContractTest {

    /**
     * Run Schemathesis contract validation via shell script
     *
     * Blocker: Requires Python environment with Schemathesis installed
     * Resolution options:
     * 1. Install Schemathesis: pip install schemathesis
     * 2. Use Docker: docker run schemathesis/schemathesis:stable run http://localhost:8080/v3/api-docs
     * 3. Run script manually: ./scripts/run_schemathesis.sh
     *
     * Enable this test after Schemathesis setup.
     */
    @Test
    void shouldValidateApiAgainstOpenAPIContract() throws Exception {
        File scriptFile = new File("scripts/run_schemathesis.sh");
        if (!scriptFile.exists()) {
            throw new IllegalStateException("Schemathesis script not found: " + scriptFile.getAbsolutePath());
        }

        ProcessBuilder processBuilder = new ProcessBuilder(
                "bash",
                scriptFile.getAbsolutePath()
        );
        processBuilder.directory(new File(System.getProperty("user.dir")));
        processBuilder.redirectErrorStream(true);

        Process process = processBuilder.start();

        // Capture output for debugging
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
                System.out.println(line);
            }
        }

        int exitCode = process.waitFor();

        // Schemathesis returns 0 on success, non-zero on contract violations
        assertEquals(0, exitCode,
                "Contract validation failed. Schemathesis detected OpenAPI violations.\n" + output);
    }
}
