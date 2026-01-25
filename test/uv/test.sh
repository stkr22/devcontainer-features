#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Feature-specific tests
check "uv cli installed" command -v uv
check "uv version" uv --version

# Check environment variables are set
check "VIRTUAL_ENV is set" test -n "$VIRTUAL_ENV"
check "UV_PROJECT_ENVIRONMENT is set" test -n "$UV_PROJECT_ENVIRONMENT"

# Report results
reportResults
