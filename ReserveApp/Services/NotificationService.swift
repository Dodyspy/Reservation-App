import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseFirestore

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isPermissionGranted = false
    private var currentTopic: String?
    private let restaurantManager = RestaurantManager.shared
    
    private override init() {
        super.init()
        // Delegate is set in AppDelegate - don't set it here to avoid conflicts
    }
    
    func requestPermission() {
        print("🔔 Requesting notification permissions...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isPermissionGranted = granted
                print("🔔 Notification permission granted: \(granted)")
                
                if granted {
                    print("📱 Attempting to register for remote notifications...")
                    self.registerForRemoteNotifications()
                } else {
                    print("❌ Notification permission denied - push notifications will not work")
                }
                
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            #if targetEnvironment(simulator)
            NSLog("⚠️ Running on iOS Simulator - APNS tokens not available")
            print("⚠️ Running on iOS Simulator - APNS tokens not available")
            print("⚠️ Push notifications will not work on simulator")
            print("⚠️ App will work in offline mode")
            return
            #else
            NSLog("📱 REAL DEVICE: Registering for remote notifications...")
            print("📱 Calling UIApplication.shared.registerForRemoteNotifications()...")
            print("📱 Current app state: \(UIApplication.shared.applicationState.rawValue)")
            print("📱 Is registered for remote notifications: \(UIApplication.shared.isRegisteredForRemoteNotifications)")
            print("📱 Device Model: \(UIDevice.current.model)")
            print("📱 System Version: \(UIDevice.current.systemVersion)")
            print("📱 Device Name: \(UIDevice.current.name)")
            
            // Always call registerForRemoteNotifications to ensure APNS token is refreshed
            // Even if already registered, this ensures the delegate method gets called
            UIApplication.shared.registerForRemoteNotifications()
            NSLog("📱 registerForRemoteNotifications() called - waiting for AppDelegate callbacks...")
            print("📱 registerForRemoteNotifications() call completed - waiting for delegate callbacks...")
            print("📱 Expected callbacks:")
            print("   ✅ didRegisterForRemoteNotificationsWithDeviceToken (success)")
            print("   ❌ didFailToRegisterForRemoteNotificationsWithError (failure)")
            #endif
            
            // Add a timeout check to see if delegate methods are called
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                print("⚠️ 10 seconds passed - checking APNS token status...")
                
                // Check if Firebase has received the APNS token
                Messaging.messaging().token { token, error in
                    if let error = error {
                        print("❌ FCM token fetch failed: \(error)")
                        print("⚠️ This suggests APNS token was not properly set")
                        print("⚠️ Possible causes:")
                        print("   - Push Notifications capability not enabled in Xcode")
                        print("   - Provisioning profile doesn't support push notifications")
                        print("   - App ID not configured for push notifications in Apple Developer Portal")
                        print("   - APNS delegate method not being called")
                    } else if let token = token {
                        print("✅ FCM token available: \(String(token.prefix(20)))...")
                        print("✅ APNS integration appears to be working")
                    }
                }
            }
        }
    }
    
    // MARK: - Multi-Tenant Topic Management
    
    func subscribeToRestaurantTopic() {
        guard let restaurant = restaurantManager.currentRestaurant else {
            print("❌ No restaurant configured for topic subscription")
            return
        }
        
        let topic = restaurant.fcmTopic
        
        // Check if already subscribed to this topic
        if currentTopic == topic {
            print("ℹ️ Already subscribed to topic: \(topic)")
            return
        }
        
        // CRITICAL: Always unsubscribe first to clear any duplicate subscriptions
        // This ensures we're not subscribed multiple times to the same topic
        print("🔄 Unsubscribing from topic '\(topic)' to clear any duplicates...")
        Messaging.messaging().unsubscribe(fromTopic: topic) { [weak self] error in
            if let error = error {
                print("⚠️ Unsubscribe error (might not have been subscribed): \(error.localizedDescription)")
            } else {
                print("✅ Unsubscribed from topic: \(topic)")
            }
            
            // Now subscribe fresh
            print("🔄 Subscribing to topic '\(topic)'...")
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error = error {
                    print("❌ Failed to subscribe to topic '\(topic)': \(error.localizedDescription)")
                } else {
                    print("✅ Successfully subscribed to restaurant topic: \(topic)")
                    self?.currentTopic = topic
                }
            }
        }
    }
    
    func unsubscribeFromCurrentTopic() {
        guard let currentTopic = currentTopic else { return }
        unsubscribeFromTopic(currentTopic)
        self.currentTopic = nil
    }
    
    func unsubscribeFromTopic(_ topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            if let error = error {
                print("❌ Failed to unsubscribe from topic '\(topic)': \(error.localizedDescription)")
            } else {
                print("✅ Successfully unsubscribed from topic: \(topic)")
            }
        }
    }
    
    func subscribeToTopic(_ topic: String) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("❌ Failed to subscribe to topic '\(topic)': \(error.localizedDescription)")
            } else {
                print("✅ Successfully subscribed to topic: \(topic)")
            }
        }
    }
    
    // MARK: - Restaurant-Specific Device Token Management
    
    func registerDeviceTokenForRestaurant() {
        guard let restaurant = restaurantManager.currentRestaurant else {
            print("❌ No restaurant configured for device token registration")
            return
        }
        
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ Error fetching FCM token: \(error)")
                return
            }
            
            guard let token = token else {
                print("❌ No FCM token available")
                return
            }
            
            self?.saveDeviceTokenToRestaurant(token: token, restaurantCode: restaurant.code)
        }
    }
    
    private func saveDeviceTokenToRestaurant(token: String, restaurantCode: String) {
        // Get restaurant document ID from UserDefaults
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            print("❌ No restaurant document ID found for saving device token")
            return
        }
        
        let db = Firestore.firestore()
        let deviceTokenRef = db.collection("restaurants")
            .document(restaurantId)
            .collection("deviceTokens")
            .document(UIDevice.current.identifierForVendor?.uuidString ?? "unknown")
        
        let deviceData: [String: Any] = [
            "token": token,
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "deviceModel": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion,
            "lastUpdated": FieldValue.serverTimestamp(),
            "isActive": true
        ]
        
        deviceTokenRef.setData(deviceData) { error in
            if let error = error {
                print("❌ Failed to save device token for \(restaurantCode): \(error)")
            } else {
                print("✅ Device token saved for restaurant \(restaurantCode)")
            }
        }
    }
    
    func removeDeviceTokenFromRestaurant() {
        // Must use the same document ID that was used when saving the token
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"),
              !restaurantId.isEmpty else {
            print("❌ No restaurant document ID found for deactivating device token")
            return
        }
        
        let db = Firestore.firestore()
        let deviceTokenRef = db.collection("restaurants")
            .document(restaurantId)
            .collection("deviceTokens")
            .document(UIDevice.current.identifierForVendor?.uuidString ?? "unknown")
        
        deviceTokenRef.updateData(["isActive": false]) { error in
            if let error = error {
                print("❌ Failed to deactivate device token: \(error)")
            } else {
                print("✅ Device token deactivated for restaurant \(restaurantId)")
            }
        }
    }
}

// UNUserNotificationCenterDelegate is implemented in AppDelegate
// This avoids duplicate notification handling
