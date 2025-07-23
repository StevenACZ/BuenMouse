#!/bin/bash

# BuenMouse Build and Run Script
# Optimized version 2.0

echo "🚀 Building BuenMouse v2.0..."

# Clean previous build
xcodebuild -project BuenMouse.xcodeproj -scheme BuenMouse -configuration Debug clean

# Build the project
xcodebuild -project BuenMouse.xcodeproj -scheme BuenMouse -configuration Debug build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "🎯 Launching BuenMouse..."
    
    # Find the built app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "BuenMouse.app" -type d | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "📱 App found at: $APP_PATH"
        open "$APP_PATH"
        echo "🎉 BuenMouse launched successfully!"
        echo ""
        echo "📋 Features enabled in v2.0:"
        echo "   ✅ Ultra-optimized performance"
        echo "   ✅ Hidden from dock (menu bar only)"
        echo "   ✅ Launch at login working"
        echo "   ✅ Dark mode support"
        echo "   ✅ Grid shortcuts layout"
        echo "   ✅ Master gesture monitoring control"
        echo ""
        echo "🔍 Check the menu bar for the cursor icon!"
    else
        echo "❌ Could not find built app"
    fi
else
    echo "❌ Build failed!"
    exit 1
fi