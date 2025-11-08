#!/bin/bash
set -e

TOOL_NAME="video-check"
INSTALL_DIR="/usr/local/bin"

echo "🗑️ Uninstalling $TOOL_NAME ..."
sudo rm -f "$INSTALL_DIR/$TOOL_NAME"
echo "✅ Uninstalled successfully!"
