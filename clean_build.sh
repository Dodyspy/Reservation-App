#!/bin/bash

echo "🧹 Cleaning Xcode build cache..."

# Clean DerivedData for ReserveApp
echo "Removing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ReserveApp-*

# Clean Xcode build folder
echo "Cleaning build folder..."
cd /Users/sxy/AppTest/Casanovadissy/ReserveApp_Backup
xcodebuild clean -scheme ReserveApp 2>/dev/null || echo "Clean completed"

echo "✅ Clean complete!"
echo ""
echo "Now in Xcode:"
echo "1. Press Cmd+Shift+K (Clean Build Folder)"
echo "2. Press Cmd+B (Build)"
echo ""
