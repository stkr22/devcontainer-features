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

# $UV_INSTALL_DIR is only honored by newer uv installer versions - older
# releases (predating that env var) default to $HOME/.cargo/bin instead and
# only add it to PATH via rc files meant for a *future* shell, which does
# nothing for the rest of this script. So don't trust `command -v uv` alone:
# search the known install locations directly.
uv_bin=""
for candidate in \
    "/usr/local/bin/uv" \
    "$HOME/.local/bin/uv" \
    "$HOME/.cargo/bin/uv" \
    "${XDG_BIN_HOME:-}/uv" \
    "${XDG_DATA_HOME:-}/../bin/uv"
do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        uv_bin="$candidate"
        break
    fi
done

if [ -z "$uv_bin" ]; then
    echo "ERROR: uv installation failed - binary not found in any known install location!" >&2
    exit 1
fi

# Normalize to /usr/local/bin regardless of where this uv version's installer
# defaulted to, so uv/uvx are on PATH for every shell and every user without
# depending on rc-file sourcing.
if [ "$uv_bin" != "/usr/local/bin/uv" ]; then
    uv_src_dir=$(dirname "$uv_bin")
    for bin_name in uv uvx; do
        if [ -x "$uv_src_dir/$bin_name" ] && [ ! -e "/usr/local/bin/$bin_name" ]; then
            cp "$uv_src_dir/$bin_name" "/usr/local/bin/$bin_name"
            chmod +x "/usr/local/bin/$bin_name"
        fi
    done
    uv_bin="/usr/local/bin/uv"
fi

"$uv_bin" --version
echo "uv feature installation complete!"
