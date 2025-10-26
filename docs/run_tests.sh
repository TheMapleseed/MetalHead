#!/bin/bash

# MetalHead Test Runner with Human-Readable Output

echo "🧪 MetalHead Test Suite"
echo "======================"
echo ""

# Check if xcpretty is installed
if command -v xcpretty &> /dev/null; then
    echo "📊 Using xcpretty for formatted output..."
    xcodebuild test \
        -project MetalHead.xcodeproj \
        -scheme MetalHead \
        -destination 'platform=macOS' \
        | xcpretty --test --color
else
    echo "⚠️  xcpretty not found. Installing..."
    echo "📥 To install: gem install xcpretty"
    echo "📊 Running tests with basic formatting..."
    echo ""
    
    # Run tests and parse output
    xcodebuild test \
        -project MetalHead.xcodeproj \
        -scheme MetalHead \
        -destination 'platform=macOS' \
        | grep -E "Test Case|PASS|FAIL|Executed|passed|failed" | while read line; do
        if [[ $line == *"Test Case"* ]]; then
            echo "🧪 $line"
        elif [[ $line == *"PASS"* ]]; then
            echo "✅ $line"
        elif [[ $line == *"FAIL"* ]]; then
            echo "❌ $line"
        elif [[ $line == *"Executed"* ]]; then
            echo ""
            echo "📊 $line"
        else
            echo "$line"
        fi
    done
    
    echo ""
    echo "💡 Tip: Install xcpretty for better output: gem install xcpretty"
fi

echo ""
echo "======================"
echo "✅ Tests completed!"
