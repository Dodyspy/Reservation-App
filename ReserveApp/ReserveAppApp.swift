//
//  ReserveAppApp.swift
//  ReserveApp
//
//  Created by Stanciu Dragos on 17/07/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

@main
struct ReserveAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var restaurantManager = RestaurantManager.shared
    @StateObject private var notificationHandler = NotificationHandler.shared
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        NSLog("============================================================")
        NSLog("🚀 ReserveApp STARTING")
        NSLog("📱 Bundle ID: %@", Bundle.main.bundleIdentifier ?? "unknown")
        NSLog("📱 App Version: %@", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
        NSLog("📱 iOS Version: %@", UIDevice.current.systemVersion)
        NSLog("📱 Device: %@", UIDevice.current.model)
        NSLog("============================================================")
        
        print(String(repeating: "=", count: 60))
        print("🚀 ReserveApp STARTING")
        print("📱 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("📱 App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
        print("📱 iOS Version: \(UIDevice.current.systemVersion)")
        print("📱 Device: \(UIDevice.current.model)")
        print(String(repeating: "=", count: 60))
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.authenticationMode != .emailPassword {
                    // Step 1: Not logged in → show login
                    MandatoryLoginView()
                        .environmentObject(authService)
                } else if !restaurantManager.isConfigured {
                    // Step 2: Logged in but restaurant still loading → show loading
                    ZStack {
                        AppTheme.anthracite.ignoresSafeArea()
                        VStack(spacing: 20) {
                            if restaurantManager.loadingFailed {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.gold)
                                Text("Impossible de charger le restaurant")
                                    .foregroundColor(AppTheme.cream)
                                    .font(.headline)
                                Text("Vérifiez votre connexion internet et réessayez.")
                                    .foregroundColor(AppTheme.cream.opacity(0.7))
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                Button(action: {
                                    restaurantManager.loadingFailed = false
                                    if let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId") {
                                        RestaurantService.shared.getRestaurantById(restaurantId) { restaurant, error in
                                            DispatchQueue.main.async {
                                                if let restaurant = restaurant {
                                                    UserDefaults.standard.set(restaurant.code, forKey: "selectedRestaurantCode")
                                                    RestaurantManager.shared.setCurrentRestaurant(restaurant)
                                                } else {
                                                    RestaurantManager.shared.setLoadingFailed(true)
                                                }
                                            }
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Réessayer")
                                    }
                                    .foregroundColor(AppTheme.anthracite)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.gold)
                                    .cornerRadius(10)
                                }
                                .padding(.top, 10)
                                Button(action: {
                                    authService.signOut { _ in }
                                }) {
                                    Text("Se déconnecter")
                                        .foregroundColor(AppTheme.gold.opacity(0.8))
                                        .font(.subheadline)
                                }
                                .padding(.top, 5)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.gold))
                                    .scaleEffect(1.5)
                                Text("Chargement du restaurant...")
                                    .foregroundColor(AppTheme.cream)
                                    .font(.headline)
                            }
                        }
                    }
                    .onAppear {
                        // Safety timeout: if restaurant isn't loaded after 15 seconds, show error
                        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                            if !restaurantManager.isConfigured && !restaurantManager.loadingFailed {
                                print("⏰ Loading timeout - showing error state")
                                restaurantManager.loadingFailed = true
                            }
                        }
                    }
                } else {
                    // Step 3: Logged in + restaurant loaded → show main app
                    ReservationListView()
                        .withDynamicTheme()
                        .environmentObject(notificationHandler)
                        .environmentObject(authService)
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    // Clear badge and delivered notifications when app becomes active
                    clearBadgeAndNotifications()
                }
            }
        }
    }
    
    private func clearBadgeAndNotifications() {
        // Clear the OS badge
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("⚠️ Failed to clear badge: \(error.localizedDescription)")
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        // Remove all delivered notifications from Notification Center
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🔔 Badge cleared and delivered notifications removed")
    }
}

// MARK: - NotificationHandler
class NotificationHandler: ObservableObject {
    static let shared = NotificationHandler()
    
    @Published var selectedReservationId: String?
    @Published var shouldNavigateToReservation = false
    
    private init() {}
    
    func handleNotificationTap(reservationId: String) {
        DispatchQueue.main.async {
            self.selectedReservationId = reservationId
            self.shouldNavigateToReservation = true
            print("🎯 Navigation triggered for reservation: \(reservationId)")
        }
    }
    
    func resetNavigation() {
        DispatchQueue.main.async {
            self.shouldNavigateToReservation = false
            self.selectedReservationId = nil
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        NSLog("🚀 App launching - configuring Firebase and notifications...")
        print("🚀 App launching - configuring Firebase and notifications...")
        
        // Configure Firebase first (fast, synchronous)
        FirebaseApp.configure()
        
        // Set notification delegate immediately
        UNUserNotificationCenter.current().delegate = self
        
        // Configure Firestore settings (fast, synchronous)
        let settings = FirestoreSettings()
        if AppConfig.shared.enableOfflinePersistence {
            settings.cacheSettings = PersistentCacheSettings()
            print("✅ Firestore offline persistence enabled")
        } else {
            settings.cacheSettings = MemoryCacheSettings()
            print("⚠️ Firestore using memory cache only")
        }
        
        #if DEBUG
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        #endif
        
        Firestore.firestore().settings = settings
        
        // Set up Firebase Messaging delegate (fast, synchronous)
        Messaging.messaging().delegate = self
        
        // Always enable Firestore network — Firebase Auth persists in Keychain
        // across reinstalls, so auth listener may fire even without a saved restaurant code
        DispatchQueue.global(qos: .userInitiated).async {
            Firestore.firestore().enableNetwork { error in
                if let error = error {
                    print("⚠️ Firestore network enable error: \(error.localizedDescription)")
                } else {
                    print("✅ Firestore network enabled")
                }
            }
        }
        
        // Check if restaurant code exists for additional initialization
        let hasRestaurantCode = UserDefaults.standard.string(forKey: "selectedRestaurantCode") != nil
        
        if hasRestaurantCode {
            print("✅ Restaurant code found - initializing for this restaurant")
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Request notification permission
                DispatchQueue.main.async {
                    NotificationService.shared.requestPermission()
                }
                
                // Load saved restaurant (async, involves network call)
                RestaurantManager.shared.loadSavedRestaurantAfterFirebaseInit()
            }
        } else {
            print("ℹ️ No restaurant code in UserDefaults")
            print("ℹ️ Auth listener will handle restaurant loading if user is already authenticated via Keychain")
        }
        
        return true
    }
    
    // APNS and FCM methods for push notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Use NSLog to ensure this is visible
        NSLog("🎉🎉🎉 SUCCESS: APNS device token received!")
        NSLog("🔑 Token: %@", deviceToken.map { String(format: "%02.2hhx", $0) }.joined())
        
        print("🎉 APNS device token received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        print("📱 Token length: \(deviceToken.count) bytes")
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNS device token registered with Firebase Messaging")
        
        // Force refresh FCM token now that APNS token is available
        Messaging.messaging().token { token, error in
            if let error = error {
                print("❌ Error fetching FCM token: \(error)")
            } else if let token = token {
                print("🔑 FCM token refreshed after APNS registration: \(token)")
                
                // Try to subscribe to restaurant-specific topic again now that we have APNS token
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    NotificationService.shared.subscribeToRestaurantTopic()
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Use NSLog to ensure this is visible even if print() is suppressed
        NSLog("❌❌❌ CRITICAL: Failed to register for remote notifications")
        NSLog("❌ Error: %@", error.localizedDescription)
        NSLog("❌ Full error: %@", error as NSError)
        
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        print("❌ Error details: \(error)")
        print("❌ Error domain: \((error as NSError).domain)")
        print("❌ Error code: \((error as NSError).code)")
        print("❌ Error userInfo: \((error as NSError).userInfo)")
        
        // Common error meanings:
        // - "no valid 'aps-environment' entitlement" = Provisioning profile issue
        // - "Push notifications not enabled" = App ID configuration issue
        // - "Invalid provisioning profile" = Profile doesn't match bundle ID
        
        // Check specific error conditions
        let nsError = error as NSError
        if nsError.domain == "NSCocoaErrorDomain" && nsError.code == 3010 {
            print("🔧 SOLUTION: Enable Push Notifications capability in Xcode project")
        }
        
        // Additional diagnostic info
        print("📱 Device info for debugging:")
        print("   - Model: \(UIDevice.current.model)")
        print("   - System: \(UIDevice.current.systemVersion)")
        print("   - Name: \(UIDevice.current.name)")
        print("   - ID: \(UIDevice.current.identifierForVendor?.uuidString ?? "unknown")")
    }
    
    // REMOVED: didReceiveRemoteNotification handler
    // This was causing duplicate notifications
    // iOS handles notifications automatically with willPresent delegate
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear badge every time the app becomes active
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
        } else {
            application.applicationIconBadgeNumber = 0
        }
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🔔 AppDelegate: Badge cleared on become active")
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("🔑 Firebase registration token: \(token)")
        
        // Store the token in Firestore for direct device messaging
        storeDeviceToken(token)
        
        // You can send this token to your server to target this device for notifications
        let dataDict: [String: String] = ["token": token]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }
    
    private func storeDeviceToken(_ token: String) {
        // Store device token in Firestore for direct push notifications
        // Get restaurant document ID from UserDefaults
        guard let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else {
            print("❌ No restaurant document ID found for storing device token")
            return
        }
        
        let db = Firestore.firestore()
        let deviceData: [String: Any] = [
            "token": token,
            "platform": "ios",
            "lastUpdated": FieldValue.serverTimestamp(),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        // Use a unique device identifier
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // Use multi-tenant path structure
        db.collection("restaurants")
            .document(restaurantId)
            .collection("deviceTokens")
            .document(deviceId)
            .setData(deviceData) { error in
                if let error = error {
                    print("❌ Failed to store device token: \(error.localizedDescription)")
                } else {
                    print("✅ Device token stored successfully for direct push notifications")
                }
            }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Tracks recently seen notification IDs to suppress duplicates.
    // Capped at 50 to prevent unbounded growth and false-suppression of re-bookings.
    private static var processedNotificationIds = [String]()
    private static let maxProcessedIds = 50
    
    // Handle notification when app is in FOREGROUND
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let identifier = notification.request.identifier
        let title = notification.request.content.title
        let body = notification.request.content.body
        let userInfo = notification.request.content.userInfo
        
        NSLog("📬 ========== FOREGROUND NOTIFICATION ==========")
        NSLog("📬 Identifier: %@", identifier)
        NSLog("📬 Title: %@", title)
        NSLog("📬 Body: %@", body)
        NSLog("📬 UserInfo: %@", String(describing: userInfo))
        NSLog("📬 =============================================")
        
        print("📬 Notification received in foreground: \(title)")
        print("📬 Notification identifier: \(identifier)")
        print("📬 Notification body: \(body)")
        print("📬 FULL UserInfo dump:")
        for (key, value) in userInfo {
            print("   - \(key): \(value)")
        }
        
        // Check for duplicate based on reservationId + notification type (within the recent window)
        // This prevents a new_reservation and a reservation_updated for the same ID from suppressing each other.
        if let reservationId = userInfo["reservationId"] as? String {
            let notificationType = userInfo["type"] as? String ?? "unknown"
            let dedupKey = "\(notificationType)_\(reservationId)"
            if AppDelegate.processedNotificationIds.contains(dedupKey) {
                print("⚠️ DUPLICATE NOTIFICATION DETECTED - Suppressing: \(dedupKey)")
                completionHandler([]) // Don't show duplicate
                return
            }
            // Add to recent list and prune if over cap
            AppDelegate.processedNotificationIds.append(dedupKey)
            if AppDelegate.processedNotificationIds.count > AppDelegate.maxProcessedIds {
                AppDelegate.processedNotificationIds.removeFirst()
            }
            print("✅ New notification - will display: \(dedupKey)")
        }
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap (when user taps notification)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        NSLog("👆 User tapped notification")
        print("👆 User tapped notification: \(response.notification.request.content.title)")
        
        let userInfo = response.notification.request.content.userInfo
        print("📦 Notification data: \(userInfo)")
        
        // Handle the notification tap - navigate to specific reservation
        if let reservationId = userInfo["reservationId"] as? String {
            print("🎯 Opening reservation: \(reservationId)")
            NotificationHandler.shared.handleNotificationTap(reservationId: reservationId)
        }
        
        completionHandler()
    }
}
