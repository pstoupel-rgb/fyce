import Foundation
import os

/// Loggers structurés de l'application (Console.app / Instruments).
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.photospartagees.app"

    static let scan = Logger(subsystem: subsystem, category: "scan")
    static let upload = Logger(subsystem: subsystem, category: "upload")
    static let vision = Logger(subsystem: subsystem, category: "vision")
}
