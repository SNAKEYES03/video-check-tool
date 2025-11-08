#!/bin/bash
set -e

TOOL_NAME="video-check"
INSTALL_DIR="/usr/local/bin"

echo "📦 Installing $TOOL_NAME ..."

# Make sure script is executable
chmod +x video-check.sh

# Copy to /usr/local/bin
sudo cp video-check.sh "$INSTALL_DIR/$TOOL_NAME"

# Verify
if command -v $TOOL_NAME &>/dev/null; then
  echo "✅ $TOOL_NAME installed successfully!"
  echo "You can now run it anywhere using: $TOOL_NAME"
else
  echo "❌ Installation failed. Please check permissions."
fi
