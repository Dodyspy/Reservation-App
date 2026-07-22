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
        Logger.debug("🔔 Requesting notification permissions...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isPermissionGranted = granted
                Logger.debug("🔔 Notification permission granted: \(granted)")
                
                if granted {
                    Logger.debug("📱 Attempting to register for remote notifications...")
                    self.registerForRemoteNotifications()
                } else {
                    Logger.debug("❌ Notification permission denied - push notifications will not work")
                }
                
                if let error = error {
                    Logger.debug("❌ Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            #if targetEnvironment(simulator)
            Logger.debug("⚠️ Running on iOS Simulator - APNS tokens not available")
            Logger.debug("⚠️ Running on iOS Simulator - APNS tokens not available")
            Logger.debug("⚠️ Push notifications will not work on simulator")
            Logger.debug("⚠️ App will work in offline mode")
            return
            #else
            Logger.debug("📱 REAL DEVICE: Registering for remote notifications...")
            Logger.debug("📱 Calling UIApplication.shared.registerForRemoteNotifications()...")
            Logger.debug("📱 Current app state: \(UIApplication.shared.applicationState.rawValue)")
            Logger.debug("📱 Is registered for remote notifications: \(UIApplication.shared.isRegisteredForRemoteNotifications)")
            Logger.debug("📱 Device Model: \(UIDevice.current.model)")
            Logger.debug("📱 System Version: \(UIDevice.current.systemVersion)")
            Logger.debug("📱 Device Name: \(UIDevice.current.name)")
            
            // Always call registerForRemoteNotifications to ensure APNS token is refreshed
            // Even if already registered, this ensures the delegate method gets called
            UIApplication.shared.registerForRemoteNotifications()
            Logger.debug("📱 registerForRemoteNotifications() called - waiting for AppDelegate callbacks...")
            Logger.debug("📱 registerForRemoteNotifications() call completed - waiting for delegate callbacks...")
            Logger.debug("📱 Expected callbacks:")
            Logger.debug("   ✅ didRegisterForRemoteNotificationsWithDeviceToken (success)")
            Logger.debug("   ❌ didFailToRegisterForRemoteNotificationsWithError (failure)")
            #endif
            
            // Add a timeout check to see if delegate methods are called
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                Logger.debug("⚠️ 10 seconds passed - checking APNS token status...")
                
                // Check if Firebase has received the APNS token
                Messaging.messaging().token { token, error in
                    if let error = error {
                        Logger.debug("❌ FCM token fetch failed: \(error)")
                        Logger.debug("⚠️ This suggests APNS token was not properly set")
                        Logger.debug("⚠️ Possible causes:")
                        Logger.debug("   - Push Notifications capability not enabled in Xcode")
                        Logger.debug("   - Provisioning profile doesn't support push notifications")
                        Logger.debug("   - App ID not configured for push notifications in Apple Developer Portal")
                        Logger.debug("   - APNS delegate method not being called")
                    } else if let token = token {
                        Logger.debug("✅ FCM token available: \(String(token.prefix(20)))...")
                        Logger.debug("✅ APNS integration appears to be working")
                    }
                }
            }
        }
    }
    
    // MARK: - Multi-Tenant Topic Management
    
    func subscribeToRestaurantTopic() {
        guard let restaurant = restaurantManager.currentRestaurant else {
            Logger.debug("❌ No restaurant configured for topic subscription")
            return
        }
        
        let topic = restaurant.fcmTopic
        
        // Check if already subscribed to this topic
        if currentTopic == topic {
            Logger.debug("ℹ️ Already subscribed to topic: \(topic)")
            return
        }
        
        // CRITICAL: Always unsubscribe first to clear any duplicate subscriptions
        // This ensures we're not subscribed multiple times to the same topic
        Logger.debug("🔄 Unsubscribing from topic '\(topic)' to clear any duplicates...")
        Messaging.messaging().unsubscribe(fromTopic: topic) { [weak self] error in
            if let error = error {
                Logger.debug("⚠️ Unsubscribe error (might not have been subscribed): \(error.localizedDescription)")
            } else {
                Logger.debug("✅ Unsubscribed from topic: \(topic)")
            }
            
            // Now subscribe fresh
            Logger.debug("🔄 Subscribing to topic '\(topic)'...")
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error = error {
                    Logger.debug("❌ Failed to subscribe to topic '\(topic)': \(error.localizedDescription)")
                } else {
                    Logger.debug("✅ Successfully subscribed to restaurant topic: \(topic)")
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
                Logger.debug("❌ Failed to unsubscribe from topic '\(topic)': \(error.localizedDescription)")
            } else {
                Logger.debug("✅ Successfully unsubscribed from topic: \(topic)")
            }
        }
    }
    
    func subscribeToTopic(_ topic: String) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                Logger.debug("❌ Failed to subscribe to topic '\(topic)': \(error.localizedDescription)")
            } else {
                Logger.debug("✅ Successfully subscribed to topic: \(topic)")
            }
        }
    }
    
    // MARK: - Restaurant-Specific Device Token Management
    
    func registerDeviceTokenForRestaurant() {
        guard let restaurant = restaurantManager.currentRestaurant else {
            Logger.debug("❌ No restaurant configured for device token registration")
            return
        }
        
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                Logger.debug("❌ Error fetching FCM token: \(error)")
                return
            }
            
            guard let token = token else {
                Logger.debug("❌ No FCM token available")
                return
            }
            
            self?.saveDeviceTokenToRestaurant(token: token, restaurantCode: restaurant.code)
        }
    }
    
    private func saveDeviceTokenToRestaurant(token: String, restaurantCode: String) {
        // Get restaurant document ID from UserDefaults
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            Logger.debug("❌ No restaurant document ID found for saving device token")
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
                Logger.debug("❌ Failed to save device token for \(restaurantCode): \(error)")
            } else {
                Logger.debug("✅ Device token saved for restaurant \(restaurantCode)")
            }
        }
    }
    
    func removeDeviceTokenFromRestaurant() {
        // Must use the same document ID that was used when saving the token
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"),
              !restaurantId.isEmpty else {
            Logger.debug("❌ No restaurant document ID found for deactivating device token")
            return
        }
        
        let db = Firestore.firestore()
        let deviceTokenRef = db.collection("restaurants")
            .document(restaurantId)
            .collection("deviceTokens")
            .document(UIDevice.current.identifierForVendor?.uuidString ?? "unknown")
        
        deviceTokenRef.updateData(["isActive": false]) { error in
            if let error = error {
                Logger.debug("❌ Failed to deactivate device token: \(error)")
            } else {
                Logger.debug("✅ Device token deactivated for restaurant \(restaurantId)")
            }
        }
    }
}

// UNUserNotificationCenterDelegate is implemented in AppDelegate
// This avoids duplicate notification handling
