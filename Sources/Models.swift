import Foundation

public struct IOSDevice: Identifiable, Codable, Hashable {
    public var id: String { udid }
    public let udid: String
    public let name: String
    public let state: String
    public let isAvailable: Bool
    public let deviceTypeIdentifier: String?
    public var runtime: String?

    public var isBooted: Bool {
        state.caseInsensitiveCompare("booted") == .orderedSame
    }

    public var iconName: String {
        let lower = name.lowercased()
        if lower.contains("ipad") { return "ipad" }
        if lower.contains("watch") { return "applewatch" }
        if lower.contains("tv") { return "appletv" }
        if lower.contains("vision") { return "visionpro" }
        return "iphone"
    }
}

public struct AndroidAVD: Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public var device: String
    public var target: String
    public var path: String
    public var isRunning: Bool

    public var displayName: String {
        name.replacingOccurrences(of: "_", with: " ")
    }
}

public enum DoctorStatus: String, Codable {
    case ok = "OK"
    case warning = "WARNING"
    case error = "ERROR"
    case loading = "LOADING"
}

public struct DoctorItem: Identifiable, Hashable {
    public let id: String
    public let category: String
    public let title: String
    public var status: DoctorStatus
    public var message: String
    public var detail: String
    public var fixCommand: String?
    public var canAutoFix: Bool
}

public struct CommandLogEntry: Identifiable, Hashable {
    public let id = UUID()
    public let timestamp = Date()
    public let command: String
    public let output: String
    public let isError: Bool
}
