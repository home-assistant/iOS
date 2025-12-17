import Foundation
import GRDB

// MARK: - Configuration Export/Import Infrastructure

/// Version of the configuration export format
public enum ConfigurationExportVersion: Int, Codable {
    case v1 = 1

    public static var current: ConfigurationExportVersion { .v1 }
}

/// Types of configurations that can be exported/imported
public enum ConfigurationType: String, Codable {
    case carPlay = "carplay"
    case watch = "watch"
    case widgets = "widgets"

    public var displayName: String {
        switch self {
        case .carPlay:
            return "CarPlay"
        case .watch:
            return "Apple Watch"
        case .widgets:
            return "Widgets"
        }
    }

    public var fileExtension: String {
        "homeassistant"
    }

    public func fileName(version: ConfigurationExportVersion = .current) -> String {
        "HomeAssistant-\(displayName)-v\(version.rawValue).\(fileExtension)"
    }
}

/// Container for exported configuration data
public struct ConfigurationExport: Codable {
    public let version: ConfigurationExportVersion
    public let type: ConfigurationType
    public let exportDate: Date
    public let data: Data

    public init(version: ConfigurationExportVersion, type: ConfigurationType, data: Data) {
        self.version = version
        self.type = type
        self.exportDate = Date()
        self.data = data
    }
}

/// Protocol for configurations that can be exported/imported
public protocol ConfigurationExportable: Codable, FetchableRecord, PersistableRecord {
    /// The type of configuration
    static var configurationType: ConfigurationType { get }

    /// Export the configuration to a file URL
    func exportToFile() throws -> URL

    /// Import configuration from file URL
    static func importFromFile(url: URL) throws -> Self
}

public extension ConfigurationExportable {
    func exportToFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Encode the actual configuration
        let configData = try encoder.encode(self)

        // Create export container
        let exportContainer = ConfigurationExport(
            version: .current,
            type: Self.configurationType,
            data: configData
        )

        // Encode the container
        let containerData = try encoder.encode(exportContainer)

        // Write to temporary file
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = Self.configurationType.fileName()
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        try containerData.write(to: fileURL)
        Current.Log.info("Configuration exported to \(fileURL.path)")

        return fileURL
    }

    static func importFromFile(url: URL) throws -> Self {
        guard url.startAccessingSecurityScopedResource() else {
            throw ConfigurationImportError.securityScopedResourceAccessFailed
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        // Decode the container
        let container = try decoder.decode(ConfigurationExport.self, from: data)

        // Validate type
        guard container.type == Self.configurationType else {
            throw ConfigurationImportError.incorrectConfigurationType(
                expected: Self.configurationType,
                found: container.type
            )
        }

        // Validate version
        guard container.version == .current else {
            throw ConfigurationImportError.unsupportedVersion(container.version)
        }

        // Decode the actual configuration
        let configuration = try decoder.decode(Self.self, from: container.data)

        Current.Log.info("Configuration imported from \(url.path)")

        return configuration
    }
}

/// Errors that can occur during configuration import
public enum ConfigurationImportError: LocalizedError {
    case securityScopedResourceAccessFailed
    case incorrectConfigurationType(expected: ConfigurationType, found: ConfigurationType)
    case unsupportedVersion(ConfigurationExportVersion)
    case invalidFileFormat

    public var errorDescription: String? {
        switch self {
        case .securityScopedResourceAccessFailed:
            return "Failed to access file"
        case let .incorrectConfigurationType(expected, found):
            return "Incorrect configuration type. Expected \(expected.displayName), found \(found.displayName)"
        case let .unsupportedVersion(version):
            return "Unsupported configuration version: v\(version.rawValue)"
        case .invalidFileFormat:
            return "Invalid configuration file format"
        }
    }
}
