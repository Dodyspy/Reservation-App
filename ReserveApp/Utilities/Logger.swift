import Foundation
import OSLog

struct Logger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "fr.casanova.RestaurantManager"

    static func debug(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(level: "DEBUG", items: items, separator: separator, terminator: terminator, file: file, line: line)
        #endif
    }

    static func info(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(level: "INFO", items: items, separator: separator, terminator: terminator, file: file, line: line)
        #endif
    }

    static func error(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, function: String = #function, line: Int = #line) {
        log(level: "ERROR", items: items, separator: separator, terminator: terminator, file: file, line: line)
    }

    private static func log(level: String, items: [Any], separator: String, terminator: String, file: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let message = items.map { String(describing: $0) }.joined(separator: separator)
        Swift.print("[\(level)] \(fileName):\(line) \(message)", terminator: terminator)

        if #available(iOS 14.0, *), level == "ERROR" {
            os_log("%@", log: OSLog(subsystem: subsystem, category: "default"), type: .error, message)
        }
    }
}
