#!/bin/bash

# Update project.pbxproj to add execution time allowance and restore TEST_AFTER_BUILD

PROJECT_FILE="MetalHead.xcodeproj/project.pbxproj"

# Add execution time allowance for tests (30 seconds per test)
# This prevents tests from hanging indefinitely
# Using sed to add the setting to the test target configurations

echo "Updating test configuration..."

# Add execution time allowance for Debug config (if not already present)
if ! grep -q "TEST_EXECUTION_TIME_ALLOWANCE" "$PROJECT_FILE"; then
    # We'll add this manually as it requires careful XML manipulation
    echo "Note: Execute time allowance should be configured in Xcode:"
    echo "  1. Open project in Xcode"
    echo "  2. Select MetalHeadTests target"
    echo "  3. Build Settings > Test Execution Time Allowance = 30"
fi

# Re-enable TEST_AFTER_BUILD now that we have timeouts
sed -i '' 's/TEST_AFTER_BUILD = NO;/TEST_AFTER_BUILD = YES;/g' "$PROJECT_FILE"

echo "Updated TEST_AFTER_BUILD to YES"
echo "Please configure Execution Time Allowance in Xcode Build Settings"

