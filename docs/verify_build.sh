#!/bin/bash

# MetalHead Build Verification Script
echo "🔍 Verifying MetalHead Build System..."
echo ""

# Check if we're in the right directory
if [ ! -f "MetalHead.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Not in MetalHead project directory"
    exit 1
fi

echo "✅ Project directory found"
echo ""

# Check Xcode version
echo "📱 Checking Xcode..."
xcodebuild -version
echo ""

# List all test files
echo "🧪 Test Files:"
find MetalHeadTests -name "*.swift" -type f 2>/dev/null | wc -l | xargs echo "Found test files:"
echo ""

# Check if project builds
echo "🔨 Building project..."
xcodebuild -project MetalHead.xcodeproj \
    -scheme MetalHead \
    -destination 'platform=macOS' \
    -configuration Debug \
    -quiet \
    clean build 2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" | tail -5

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed"
    exit 1
fi
echo ""

# Count code lines
echo "📊 Project Statistics:"
echo "Source files: $(find MetalHead -name "*.swift" -type f 2>/dev/null | wc -l | xargs)"
echo "Test files: $(find MetalHeadTests -name "*.swift" -type f 2>/dev/null | wc -l | xargs)"
echo "Lines of code: $(find MetalHead MetalHeadTests -name "*.swift" -type f 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')"
echo ""

echo "✅ Verification complete! The MetalHead project is ready."
echo ""
echo "To run the app:"
echo "  open MetalHead.xcodeproj"
echo ""
echo "Or use the build system:"
echo "  make build"
echo "  make test"
echo ""
