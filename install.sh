#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# 1. DETERMINE THE PLATFORM AND ARCHITECTURE
if [[ "$RUNNER_OS" == "Linux" ]]; then
  PLATFORM="linux"
elif [[ "$RUNNER_OS" == "macOS" ]]; then
  PLATFORM="macOS"
elif [[ "$RUNNER_OS" == "Windows" ]]; then
  PLATFORM="windows"
else
  echo "Unsupported operating system: $RUNNER_OS"
  exit 1
fi

ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# 2. RESOLVE THE GH CLI VERSION
echo "Resolving gh version for input: $INPUT_VERSION"
if [[ "$INPUT_VERSION" == "latest" ]]; then
  # Use GitHub API to find the latest release version
  GH_VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
else
  GH_VERSION=$INPUT_VERSION
fi
echo "Using gh version: $GH_VERSION"

# 3. CONSTRUCT DOWNLOAD URL
FILE_EXT="tar.gz"
if [[ "$PLATFORM" == "windows" ]]; then
  FILE_EXT="zip"
fi
DOWNLOAD_URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_${PLATFORM}_${ARCH}.${FILE_EXT}"
echo "Download URL: $DOWNLOAD_URL"

# 4. DOWNLOAD AND EXTRACT
INSTALL_DIR="$RUNNER_TEMP/gh_cli"
mkdir -p "$INSTALL_DIR"

echo "Downloading gh CLI from $DOWNLOAD_URL"
curl -sL "$DOWNLOAD_URL" -o "$INSTALL_DIR/gh.${FILE_EXT}"

echo "Extracting gh CLI..."
if [[ "$PLATFORM" == "windows" ]]; then
  unzip -q "$INSTALL_DIR/gh.zip" -d "$INSTALL_DIR"
else
  tar -xzf "$INSTALL_DIR/gh.tar.gz" -C "$INSTALL_DIR"
fi

# 5. CONSTRUCT PATHS AND SET PERMISSIONS
# REMOVED the fragile 'find' command.
# Construct the path directly from variables we already know.
GH_DIR="$INSTALL_DIR/gh_${GH_VERSION}_${PLATFORM}_${ARCH}"
GH_BIN_DIR="$GH_DIR/bin"
GH_EXECUTABLE_PATH="$GH_BIN_DIR/gh"

# Crucial step: Ensure the binary is executable.
echo "Setting execute permissions on $GH_EXECUTABLE_PATH"
chmod +x "$GH_EXECUTABLE_PATH"

# 6. ADD TO PATH
echo "Adding newly installed gh CLI to the system PATH..."
echo "$GH_BIN_DIR" >> "$GITHUB_PATH"

# 7. AUTHENTICATE (if token is provided)
if [[ -n "$INPUT_TOKEN" ]]; then
  echo "Authenticating the new gh CLI..."
  echo "$INPUT_TOKEN" | "$GH_EXECUTABLE_PATH" auth login --with-token
  echo "Authentication successful."
else
  echo "Skipping authentication as no token was provided."
fi

# 8. VERIFY INSTALLATION
echo "Verifying the newly installed gh CLI..."
"$GH_EXECUTABLE_PATH" --version
"$GH_EXECUTABLE_PATH" auth status

# 9. SET THE ACTION OUTPUTS
echo "Setting action outputs..."
cat <<EOF >> "$GITHUB_OUTPUT"
gh-path=${GH_EXECUTABLE_PATH}
version=${GH_VERSION}
EOF

echo "✅ gh CLI setup complete."
