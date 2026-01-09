#!/usr/bin/env bash
set -euo pipefail

# Script to download and install the latest master builds of Zig and ZLS
# Requires sudo privileges to install to /usr/local/bin

echo "=== Installing Zig and ZLS master builds ==="

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
    x86_64)
        ZIG_ARCH="x86_64"
        ;;
    aarch64|arm64)
        ZIG_ARCH="aarch64"
        ;;
    armv7l)
        ZIG_ARCH="armv7a"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected: $OS-$ZIG_ARCH"

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

cd "$TMP_DIR"

# Download and install Zig
echo ""
echo "=== Downloading Zig master build ==="
echo "Fetching latest build information..."

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install it:"
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    echo "  Fedora/RHEL: sudo dnf install jq"
    echo "  Arch: sudo pacman -S jq"
    exit 1
fi

INDEX_JSON=$(curl -fSL "https://ziglang.org/download/index.json")

# Extract the tarball URL for master build
PLATFORM_KEY="${ZIG_ARCH}-${OS}"
ZIG_URL=$(echo "$INDEX_JSON" | jq -r ".master.\"$PLATFORM_KEY\".tarball")

if [ -z "$ZIG_URL" ] || [ "$ZIG_URL" = "null" ]; then
    echo "Error: Could not find Zig master build for ${PLATFORM_KEY}"
    exit 1
fi

ZIG_TARBALL=$(basename "$ZIG_URL")
echo "Downloading from: $ZIG_URL"
curl -fSL "$ZIG_URL" -o "$ZIG_TARBALL"

echo "Extracting Zig..."
tar -xf "$ZIG_TARBALL"

# Find the extracted directory (it has a build number suffix)
# Directory name follows the pattern: zig-{arch}-{os}-{version}
ZIG_DIR=$(find . -maxdepth 1 -type d -name "zig-${ZIG_ARCH}-${OS}-*" | head -n1)

if [ -z "$ZIG_DIR" ]; then
    echo "Error: Could not find extracted Zig directory"
    exit 1
fi

echo "Installing Zig to /usr/local/bin..."
sudo cp -r "$ZIG_DIR" /usr/local/
sudo ln -sf "/usr/local/$(basename "$ZIG_DIR")/zig" /usr/local/bin/zig

echo "Zig installed successfully!"
zig version

# Build and install ZLS from source
echo ""
echo "=== Building ZLS from source ==="
echo "Note: ZLS master builds are not pre-compiled, building from source..."

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Error: git is required to build ZLS"
    echo "Skipping ZLS installation"
else
    echo "Cloning ZLS repository..."
    git clone --depth 1 https://github.com/zigtools/zls.git
    
    cd zls
    
    echo "Building ZLS with newly installed Zig..."
    /usr/local/bin/zig build -Doptimize=ReleaseSafe
    
    # Find the built binary
    ZLS_BIN=$(find zig-out/bin -name "zls" -type f 2>/dev/null | head -n1)
    
    if [ -n "$ZLS_BIN" ] && [ -f "$ZLS_BIN" ]; then
        echo "Installing ZLS to /usr/local/bin..."
        sudo cp "$ZLS_BIN" /usr/local/bin/zls
        sudo chmod +x /usr/local/bin/zls
        echo "ZLS built and installed successfully!"
        /usr/local/bin/zls --version || echo "ZLS installed (version info not available)"
    else
        echo "Warning: Could not find ZLS binary after build"
        echo "You may need to build ZLS manually from: https://github.com/zigtools/zls"
    fi
    
    cd ..
fi

# Cleanup happens automatically via trap

echo ""
echo "=== Installation complete! ==="
echo "Zig: $(zig version)"
echo "ZLS: $(which zls)"
echo ""
echo "Note: You may need to restart your editor/IDE to use the new ZLS."
