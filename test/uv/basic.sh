#!/bin/bash

set -e

# Basic validation tests for uv feature

# Check uv is installed
if ! command -v uv &> /dev/null; then
    echo "uv command not found"
    exit 1
fi

# Check uv version works
uv --version

# Check uvx is installed
if ! command -v uvx &> /dev/null; then
    echo "uvx command not found"
    exit 1
fi

echo "Basic tests passed!"
exit 0
