#!/bin/sh
set -eu

echo "Activating feature 'claude-code'"

# Get the remote user from options (defaults to vscode)
REMOTE_USER="${REMOTEUSER:-vscode}"

GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
DOWNLOAD_DIR="/tmp/claude-install"

# Function to detect the package manager
detect_package_manager() {
    for pm in apt-get apk dnf yum; do
        if command -v $pm >/dev/null; then
            case $pm in
                apt-get) echo "apt" ;;
                *) echo "$pm" ;;
            esac
            return 0
        fi
    done
    echo "unknown"
    return 1
}

# Function to install required dependencies
install_dependencies() {
    local pkg_manager="$1"

    echo "Installing dependencies using $pkg_manager..."

    case "$pkg_manager" in
        apt)
            apt-get update
            apt-get install -y curl ca-certificates
            ;;
        apk)
            apk add --no-cache curl ca-certificates
            ;;
        dnf)
            dnf install -y curl ca-certificates
            ;;
        yum)
            yum install -y curl ca-certificates
            ;;
        *)
            echo "WARNING: Unknown package manager. Assuming curl is available."
            ;;
    esac
}

# Download function
download_file() {
    local url="$1"
    local output="$2"

    if [ -n "$output" ]; then
        curl -fsSL -o "$output" "$url"
    else
        curl -fsSL "$url"
    fi
}

# Simple JSON parser for extracting checksum when jq is not available
get_checksum_from_manifest() {
    local json="$1"
    local platform="$2"

    # Normalize JSON to single line and extract checksum
    json=$(echo "$json" | tr -d '\n\r\t' | sed 's/ \+/ /g')

    # Extract checksum for platform - look for the platform key and its checksum
    echo "$json" | sed -n "s/.*\"$platform\"[^}]*\"checksum\"[[:space:]]*:[[:space:]]*\"\([a-f0-9]\{64\}\)\".*/\1/p"
}

# Function to install Claude Code CLI
install_claude_code() {
    echo "Installing Claude Code CLI..."

    # Detect platform
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux) os="linux" ;;
        *) echo "Unsupported OS: $(uname -s)" >&2; return 1 ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) arch="x64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) echo "Unsupported architecture: $(uname -m)" >&2; return 1 ;;
    esac

    # Check for musl on Linux
    if [ "$os" = "linux" ]; then
        if [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ] || (ldd /bin/ls 2>&1 | grep -q musl); then
            platform="linux-${arch}-musl"
        else
            platform="linux-${arch}"
        fi
    else
        platform="${os}-${arch}"
    fi

    echo "Detected platform: $platform"

    mkdir -p "$DOWNLOAD_DIR"

    # Get latest version
    echo "Fetching latest version..."
    version=$(download_file "$GCS_BUCKET/latest" "")

    if [ -z "$version" ]; then
        echo "ERROR: Failed to fetch latest version"
        return 1
    fi

    echo "Latest version: $version"

    # Download manifest and extract checksum
    echo "Downloading manifest..."
    manifest_json=$(download_file "$GCS_BUCKET/$version/manifest.json" "")

    # Use jq if available, otherwise fall back to sed parsing
    if command -v jq >/dev/null 2>&1; then
        checksum=$(echo "$manifest_json" | jq -r ".platforms[\"$platform\"].checksum // empty")
    else
        checksum=$(get_checksum_from_manifest "$manifest_json" "$platform")
    fi

    # Validate checksum format (SHA256 = 64 hex characters)
    if [ -z "$checksum" ]; then
        echo "ERROR: Platform $platform not found in manifest" >&2
        return 1
    fi

    echo "Expected checksum: $checksum"

    # Download binary
    binary_path="$DOWNLOAD_DIR/claude-$version-$platform"
    echo "Downloading Claude Code binary..."
    if ! download_file "$GCS_BUCKET/$version/$platform/claude" "$binary_path"; then
        echo "ERROR: Download failed" >&2
        rm -f "$binary_path"
        return 1
    fi

    # Verify checksum
    echo "Verifying checksum..."
    if [ "$os" = "darwin" ]; then
        actual=$(shasum -a 256 "$binary_path" | cut -d' ' -f1)
    else
        actual=$(sha256sum "$binary_path" | cut -d' ' -f1)
    fi

    if [ "$actual" != "$checksum" ]; then
        echo "ERROR: Checksum verification failed" >&2
        echo "Expected: $checksum"
        echo "Actual:   $actual"
        rm -f "$binary_path"
        return 1
    fi

    echo "Checksum verified successfully"

    # Make executable and run installer
    chmod +x "$binary_path"
    echo "Running Claude Code installer..."
    "$binary_path" install

    # Clean up
    rm -f "$binary_path"

    # Verify installation - check known install locations
    # The installer puts the binary in ~/.local/bin/claude (for current user, likely root during build)
    local claude_bin=""
    if [ -x "$HOME/.local/bin/claude" ]; then
        claude_bin="$HOME/.local/bin/claude"
    elif [ -x "/root/.local/bin/claude" ]; then
        claude_bin="/root/.local/bin/claude"
    elif [ -x "/usr/local/bin/claude" ]; then
        claude_bin="/usr/local/bin/claude"
    elif command -v claude >/dev/null 2>&1; then
        claude_bin="claude"
    fi

    if [ -n "$claude_bin" ]; then
        echo "Claude Code CLI installed successfully at: $claude_bin"
        "$claude_bin" --version

        # Create symlink in /usr/local/bin for system-wide availability
        if [ "$claude_bin" != "/usr/local/bin/claude" ] && [ ! -e "/usr/local/bin/claude" ]; then
            echo "Creating symlink at /usr/local/bin/claude..."
            ln -s "$claude_bin" /usr/local/bin/claude || true
        fi

        return 0
    else
        echo "ERROR: Claude Code CLI installation failed - binary not found!"
        return 1
    fi
}

# Function to setup config directory symlink and fix permissions
setup_config_directory() {
    local user="$1"
    local home_dir="/home/$user"
    local claude_dir="$home_dir/.claude"

    # If /claude-config volume is mounted, symlink ~/.claude to it
    if [ -d "/claude-config" ]; then
        echo "Setting up config directory symlink..."

        # Ensure home directory exists (may not exist during container build)
        mkdir -p "$home_dir"

        # Remove existing .claude if it's a regular directory (not a symlink)
        if [ -d "$claude_dir" ] && [ ! -L "$claude_dir" ]; then
            # Move any existing content to the volume
            cp -a "$claude_dir/." /claude-config/ 2>/dev/null || true
            rm -rf "$claude_dir"
        fi

        # Create symlink if it doesn't exist
        if [ ! -L "$claude_dir" ]; then
            ln -s /claude-config "$claude_dir"
        fi

        # Fix permissions on the volume
        chown -R "$user:$user" /claude-config 2>/dev/null || true
    fi

    # Fix permissions for command history directory if it exists
    if [ -d "/commandhistory" ]; then
        echo "Fixing permissions for /commandhistory..."
        chown -R "$user:$user" "/commandhistory" 2>/dev/null || true
    fi
}

# Main script
main() {
    # Detect and use appropriate package manager
    PKG_MANAGER=$(detect_package_manager)
    echo "Detected package manager: $PKG_MANAGER"

    # Ensure curl is available
    if ! command -v curl >/dev/null; then
        install_dependencies "$PKG_MANAGER"
    fi

    # Install Claude Code
    install_claude_code || exit 1

    # Setup config directory and fix permissions for mounted volumes
    setup_config_directory "$REMOTE_USER"

    echo "Claude Code feature installation complete!"
}

# Execute main function
main
