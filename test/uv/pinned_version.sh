#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Verifies the "version" option is actually honored (see src/uv/install.sh),
# not silently ignored in favor of whatever's vendored.
check "uv cli installed" command -v uv
check "uv version is pinned to 0.4.0" bash -c 'uv --version | grep -q "0.4.0"'

# Report results
reportResults
