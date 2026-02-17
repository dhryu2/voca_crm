#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/openapi"
OUTPUT_FILE="$OUTPUT_DIR/openapi.json"

echo "=== OpenAPI Spec Generation ==="

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if API is already running
if curl -s http://localhost:8080/actuator/health >/dev/null 2>&1; then
    echo "API server already running"
else
    echo "Starting API server..."
    cd "$PROJECT_ROOT"

    # Set environment variables for OpenAPI generation
    export ENABLE_API_DOCS=true
    export ENABLE_SWAGGER_UI=true

    # Start server in background
    ./gradlew bootRun > /dev/null 2>&1 &
    SERVER_PID=$!

    # Wait for server to start (max 60 seconds)
    echo "Waiting for server to start..."
    for i in {1..60}; do
        if curl -s http://localhost:8080/actuator/health >/dev/null 2>&1; then
            echo "Server started successfully"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "ERROR: Server failed to start within 60 seconds"
            kill $SERVER_PID 2>/dev/null || true
            exit 1
        fi
        sleep 1
    done
fi

# Extract OpenAPI spec
echo "Extracting OpenAPI spec from /v3/api-docs..."
if curl -s http://localhost:8080/v3/api-docs > "$OUTPUT_FILE"; then
    echo "SUCCESS: OpenAPI spec saved to $OUTPUT_FILE"

    # Validate JSON
    if command -v jq >/dev/null 2>&1; then
        if jq empty "$OUTPUT_FILE" 2>/dev/null; then
            echo "Validation: Valid JSON"

            # Show summary
            echo ""
            echo "=== Spec Summary ==="
            echo "OpenAPI Version: $(jq -r '.openapi' "$OUTPUT_FILE")"
            echo "API Title: $(jq -r '.info.title' "$OUTPUT_FILE")"
            echo "API Version: $(jq -r '.info.version' "$OUTPUT_FILE")"
            echo "Total paths: $(jq '.paths | length' "$OUTPUT_FILE")"
            echo "Total schemas: $(jq '.components.schemas | length' "$OUTPUT_FILE")"
        else
            echo "WARNING: Generated file is not valid JSON"
            exit 1
        fi
    fi
else
    echo "ERROR: Failed to extract OpenAPI spec"
    exit 1
fi

# Cleanup: Stop server if we started it
if [ -n "$SERVER_PID" ]; then
    echo "Stopping API server..."
    kill $SERVER_PID 2>/dev/null || true
fi

echo "=== Generation Complete ==="
