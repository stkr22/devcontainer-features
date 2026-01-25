#!/bin/sh
set -eu

echo "Activating feature 'uv'"

# Get version from options (defaults to latest)
UV_VERSION="${VERSION:-latest}"

GITHUB_BASE_URL="https://github.com/astral-sh/uv/releases"
DOWNLOAD_DIR="/tmp/uv-install"

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
            apt-get install -y curl ca-certificates tar
            ;;
        apk)
            apk add --no-cache curl ca-certificates tar
            ;;
        dnf)
            dnf install -y curl ca-certificates tar
            ;;
        yum)
            yum install -y curl ca-certificates tar
            ;;
        *)
            echo "WARNING: Unknown package manager. Assuming curl and tar are available."
            ;;
    esac
}

# Function to get the latest uv version
get_latest_version() {
    curl -fsSL "https://api.github.com/repos/astral-sh/uv/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Function to install uv
install_uv() {
    echo "Installing uv..."

    # Detect platform
    case "$(uname -s)" in
        Darwin) os="apple-darwin" ;;
        Linux) os="unknown-linux" ;;
        *) echo "Unsupported OS: $(uname -s)" >&2; return 1 ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        arm64|aarch64) arch="aarch64" ;;
        armv7l) arch="armv7" ;;
        i686|i386) arch="i686" ;;
        *) echo "Unsupported architecture: $(uname -m)" >&2; return 1 ;;
    esac

    # Determine libc type on Linux
    if [ "$os" = "unknown-linux" ]; then
        if [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ] || (ldd --version 2>&1 | grep -q musl); then
            libc="musl"
        else
            libc="gnu"
        fi
        platform="${arch}-${os}-${libc}"
    else
        platform="${arch}-${os}"
    fi

    echo "Detected platform: $platform"

    # Determine version to install
    if [ "$UV_VERSION" = "latest" ]; then
        echo "Fetching latest version..."
        version=$(get_latest_version)
        if [ -z "$version" ]; then
            echo "ERROR: Failed to fetch latest version"
            return 1
        fi
    else
        version="$UV_VERSION"
        # Add 'v' prefix if not present (GitHub releases use v-prefixed tags)
        case "$version" in
            v*) ;;
            *) version="v$version" ;;
        esac
    fi

    echo "Installing uv version: $version"

    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"

    # Construct download URL
    archive_name="uv-${platform}.tar.gz"
    download_url="${GITHUB_BASE_URL}/download/${version}/${archive_name}"

    echo "Downloading from: $download_url"

    # Download the archive
    if ! curl -fsSL -o "$DOWNLOAD_DIR/$archive_name" "$download_url"; then
        echo "ERROR: Failed to download uv archive" >&2
        rm -rf "$DOWNLOAD_DIR"
        return 1
    fi

    # Extract the archive
    echo "Extracting archive..."
    tar -xzf "$DOWNLOAD_DIR/$archive_name" -C "$DOWNLOAD_DIR"

    # Find and install binaries
    # The archive extracts to a directory like uv-x86_64-unknown-linux-gnu/
    local extracted_dir="$DOWNLOAD_DIR/uv-${platform}"
    if [ ! -d "$extracted_dir" ]; then
        # Try without the directory wrapper (some versions extract flat)
        extracted_dir="$DOWNLOAD_DIR"
    fi

    # Install uv and uvx binaries
    echo "Installing binaries to /usr/local/bin..."
    for binary in uv uvx; do
        if [ -f "$extracted_dir/$binary" ]; then
            cp "$extracted_dir/$binary" /usr/local/bin/
            chmod +x "/usr/local/bin/$binary"
            echo "  Installed $binary"
        fi
    done

    # Clean up
    rm -rf "$DOWNLOAD_DIR"

    # Verify installation
    if command -v uv >/dev/null 2>&1; then
        echo "uv installed successfully!"
        uv --version
    elif [ -x "/usr/local/bin/uv" ]; then
        echo "uv installed successfully at /usr/local/bin/uv"
        /usr/local/bin/uv --version
    else
        echo "ERROR: uv installation failed - binary not found!"
        return 1
    fi

    return 0
}

# Main script
main() {
    # Detect and use appropriate package manager
    PKG_MANAGER=$(detect_package_manager)
    echo "Detected package manager: $PKG_MANAGER"

    # Ensure curl and tar are available
    if ! command -v curl >/dev/null || ! command -v tar >/dev/null; then
        install_dependencies "$PKG_MANAGER"
    fi

    # Install uv
    install_uv || exit 1

    echo "uv feature installation complete!"
}

# Execute main function
main
