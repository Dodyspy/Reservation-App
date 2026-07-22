#!/bin/bash

echo "🔔 Push Notification Diagnostic Tool"
echo "===================================="
echo ""

echo "📋 Checking project configuration..."
echo ""

# Check if entitlements file exists
if [ -f "ReserveApp/ReserveApp.entitlements" ]; then
    echo "✅ Entitlements file exists: ReserveApp/ReserveApp.entitlements"
    echo "📄 Contents:"
    cat ReserveApp/ReserveApp.entitlements
    echo ""
else
    echo "❌ Entitlements file missing: ReserveApp/ReserveApp.entitlements"
    echo ""
fi

# Check bundle identifier
echo "📱 Bundle Identifier in GoogleService-Info.plist:"
grep -A1 "BUNDLE_ID" ReserveApp/GoogleService-Info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/'
echo ""

# Check project bundle identifier
echo "📱 Bundle Identifier in Xcode project:"
grep "PRODUCT_BUNDLE_IDENTIFIER" ReserveApp.xcodeproj/project.pbxproj | head -1 | sed 's/.*= \(.*\);/\1/'
echo ""

echo "🔧 Next Steps:"
echo "1. Build and run the app on a real device"
echo "2. Check the console logs for the new diagnostic messages"
echo "3. Look for:"
echo "   ✅ '🔔 Notification permission granted: true'"
echo "   ✅ '📱 Calling UIApplication.shared.registerForRemoteNotifications()...'"
echo "   ✅ '✅ APNS device token registered successfully'"
echo "   ❌ '❌ Failed to register for remote notifications: [error]'"
echo ""

echo "🍎 If you see APNS registration failures:"
echo "1. Go to https://developer.apple.com/account/"
echo "2. Navigate to Certificates, Identifiers & Profiles → Identifiers"
echo "3. Find your App ID: fr.casanova.ReserveApp"
echo "4. Enable 'Push Notifications' capability"
echo "5. Regenerate your provisioning profile"
echo ""

echo "📱 Test push notification API:"
echo "curl -X POST https://www.casanovadissy.fr/api/send-push-notification \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{"
echo "    \"customerName\": \"Test Client\","
echo "    \"customerEmail\": \"test@example.com\","
echo "    \"customerPhone\": \"01 23 45 67 89\","
echo "    \"partySize\": 2,"
echo "    \"date\": \"2025-01-25\","
echo "    \"time\": \"19:30\","
echo "    \"specialRequests\": \"Test notification\""
echo "  }'"
echo ""
