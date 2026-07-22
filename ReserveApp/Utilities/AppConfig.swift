import Foundation

enum DataSource {
    case firebase
    case api
    case both // Try Firebase first, then fall back to API if needed
}

class AppConfig {
    static let shared = AppConfig()
    
    // Configuration properties
    var dataSource: DataSource
    var apiBaseURL: String
    var enableOfflinePersistence: Bool
    var enablePushNotifications: Bool
    
    // Secrets loaded from Config.plist (not committed to Git)
    let cloudFunctionBaseURL: String
    let emailJSServiceID: String
    let emailJSTemplateID: String
    let emailJSUserID: String
    
    private init() {
        // Load configuration from UserDefaults
        let defaults = UserDefaults.standard
        
        // Data source
        let dataSourceValue = defaults.integer(forKey: "dataSource")
        switch dataSourceValue {
        case 0:
            dataSource = .firebase
        case 1:
            dataSource = .api
        default:
            dataSource = .both
        }
        
        // API URL - Points to centralized Restaurant Manager Pro API
        apiBaseURL = defaults.string(forKey: "apiBaseURL") ?? "https://api.restaurantmanagerpro.fr/api"
        
        // Feature flags
        enableOfflinePersistence = defaults.object(forKey: "enableOfflinePersistence") as? Bool ?? true
        enablePushNotifications = defaults.object(forKey: "enablePushNotifications") as? Bool ?? true
        
        // Load secrets from Config.plist
        let config = AppConfig.loadConfigPlist()
        cloudFunctionBaseURL = config["CloudFunctionBaseURL"] as? String ?? ""
        emailJSServiceID = config["EmailJSServiceID"] as? String ?? ""
        emailJSTemplateID = config["EmailJSTemplateID"] as? String ?? ""
        emailJSUserID = config["EmailJSUserID"] as? String ?? ""
    }
    
    private static func loadConfigPlist() -> [String: Any] {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            Logger.debug("⚠️ Config.plist not found or invalid. Secrets will be empty.")
            return [:]
        }
        return plist
    }
    
    // Check if Firebase is properly configured
    func isFirebaseConfigured() -> Bool {
        // This is a simple check to see if the GoogleService-Info.plist exists
        // In a real app, you might want to do more thorough validation
        let bundle = Bundle.main
        return bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }
}
