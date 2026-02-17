#!/bin/bash
# Schemathesis OpenAPI Contract Validation Script
#
# Validates Spring Boot API against OpenAPI spec using property-based testing.
# From RESEARCH.md: Schemathesis detects 1.4x-4.5x more defects than manual tests.

set -e

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
OPENAPI_SPEC_URL="${OPENAPI_SPEC_URL:-${API_BASE_URL}/v3/api-docs}"
MAX_EXAMPLES="${MAX_EXAMPLES:-50}"
OUTPUT_FILE="${OUTPUT_FILE:-build/reports/contract-test-results.xml}"

echo "=== Schemathesis Contract Testing ==="
echo "API Base URL: ${API_BASE_URL}"
echo "OpenAPI Spec: ${OPENAPI_SPEC_URL}"
echo "Max Examples: ${MAX_EXAMPLES}"

# Check if Schemathesis is installed
if ! command -v schemathesis &> /dev/null; then
    echo "ERROR: Schemathesis not installed."
    echo "Install with: pip install schemathesis"
    echo "Or use Docker: docker pull schemathesis/schemathesis:stable"
    exit 1
fi

# Check if API server is running
if ! curl -f -s "${OPENAPI_SPEC_URL}" > /dev/null; then
    echo "ERROR: API server not responding at ${OPENAPI_SPEC_URL}"
    echo "Start server with: ./gradlew bootRun"
    exit 1
fi

echo "Starting contract validation..."

# Run Schemathesis
# --checks all: Enable all available checks (status code, schema, content-type, etc.)
# --validate-schema: Validate OpenAPI spec itself
# --hypothesis-max-examples: Number of test cases per endpoint
# --junit-xml: Generate JUnit-compatible report
schemathesis run "${OPENAPI_SPEC_URL}" \
    --base-url "${API_BASE_URL}" \
    --checks all \
    --validate-schema=true \
    --hypothesis-max-examples="${MAX_EXAMPLES}" \
    --junit-xml="${OUTPUT_FILE}" \
    --exitfirst=false

echo "Contract validation complete!"
echo "Report saved to: ${OUTPUT_FILE}"
