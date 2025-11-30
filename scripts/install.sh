#!/bin/bash

# MetalHead Installation Script
# Installs the built MetalHead.app to /Applications

set -e

PROJECT_NAME="MetalHead"
APP_NAME="MetalHead.app"
BUILD_DIR="${HOME}/Library/Developer/Xcode/DerivedData/MetalHead-*/Build/Products/Debug"
INSTALL_DIR="/Applications"

echo "🔧 MetalHead Installation Script"
echo "=================================="
echo ""

# Find the built app
echo "📦 Searching for built application..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "${APP_NAME}" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: ${APP_NAME} not found in build directory"
    echo "   Please build the project first: xcodebuild -scheme ${PROJECT_NAME} build"
    exit 1
fi

echo "✅ Found: ${APP_PATH}"
echo ""

# Check if app is already installed
INSTALLED_PATH="${INSTALL_DIR}/${APP_NAME}"
if [ -d "$INSTALLED_PATH" ]; then
    echo "⚠️  ${APP_NAME} already exists in ${INSTALL_DIR}"
    read -p "   Do you want to replace it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 1
    fi
    echo "🗑️  Removing existing installation..."
    rm -rf "$INSTALLED_PATH"
fi

# Install the app
echo "📥 Installing ${APP_NAME} to ${INSTALL_DIR}..."
cp -R "$APP_PATH" "$INSTALL_DIR/"

# Verify installation
if [ -d "$INSTALLED_PATH" ]; then
    echo "✅ Installation successful!"
    echo "   Location: ${INSTALLED_PATH}"
    echo ""
    echo "🚀 You can now run: open ${INSTALLED_PATH}"
    echo "   Or use: ./scripts/test_engine.sh"
else
    echo "❌ Installation failed"
    exit 1
fi


