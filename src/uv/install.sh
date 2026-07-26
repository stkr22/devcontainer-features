#!/bin/sh
set -eu

echo "Activating feature 'uv'"

# Feature option (see devcontainer-feature.json): "latest" or a specific
# version string like "0.4.18". Injected by the devcontainer CLI as $VERSION.
UV_FEATURE_VERSION="${VERSION:-latest}"

# Install to a system-wide location so uv is on PATH without shell rc
# modifications, and skip the self-updater / PATH edits inside a container.
export UV_INSTALL_DIR="${UV_INSTALL_DIR:-/usr/local/bin}"
export UV_NO_MODIFY_PATH=1
export UV_DISABLE_UPDATE=1

if ! command -v curl >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        apt-get install -y --no-install-recommends curl ca-certificates
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache curl ca-certificates
    else
        echo "ERROR: 'curl' not found and cannot install it automatically" >&2
        exit 1
    fi
fi

if [ "$UV_FEATURE_VERSION" = "latest" ]; then
    installer_url="https://astral.sh/uv/install.sh"
else
    installer_url="https://astral.sh/uv/${UV_FEATURE_VERSION}/install.sh"
fi

echo "Installing uv (${UV_FEATURE_VERSION}) from ${installer_url}..."
curl -LsSf "$installer_url" | sh

if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: uv installation failed - binary not found on PATH!" >&2
    exit 1
fi

uv --version
echo "uv feature installation complete!"
