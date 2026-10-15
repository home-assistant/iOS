import Foundation
import HAKit
import Shared

/// Importing one or more Home Assistant servers from a document the user opened in the app
/// (AirDrop / Files / mail attachment / a shared link), as an alternative to typing each server's
/// URL and signing in individually.
///
/// The document is a JSON file (UTI `io.homeassistant.serverconfig`, extension `.hassconfig`) listing
/// servers. Only `.hassconfig` files are opened from outside the app (Files, Mail, AirDrop); the in-app
/// file picker also accepts the same content saved as plain `.json`. Each server is handled in one of
/// two ways, decided per-server by whether it carries a long-lived access token:
///
/// - **Token present** — the server is added without a login. The token is first checked against the
///   live REST API (`GET /api/` must answer 200 with Home Assistant's own JSON), then the server goes
///   through the same authenticated setup sign-in runs (mobile app registration, config, sensors) and
///   is persisted only if all of it succeeds.
/// - **Token absent** — the server's URL is handed to the normal onboarding flow so the user signs in
///   through the usual SSO/OAuth, with the URL pre-filled so they don't have to type it.
///
/// A server whose external URL already matches a configured one is skipped, as is a server the file
/// lists more than once, and the whole run reports what was added, skipped and failed so the caller
/// can summarize it to the user.
///
/// Decoding and validation (`decode(data:)`) are a pure, side-effect-free function so they can be
/// unit-tested without a running app; the persistence/validation path (`run(...)`) is injected with
/// its collaborators for the same reason.
enum ServerConfigurationImport {
    static let fileKind = "home-assistant-servers"
    static let schemaVersion = 1

    /// UTI + extensions the document is recognized by. Kept here so the type declaration and the
    /// file-open routing agree on one source of truth.
    static let contentIdentifier = "io.homeassistant.serverconfig"
    static let primaryFileExtension = "hassconfig"
    /// Extensions the in-app file picker accepts. Plain `.json` is picker-only: the app does not claim
    /// every JSON document on the device, so a file opened from elsewhere must be a `.hassconfig`.
    static let acceptedFileExtensions = ["hassconfig", "json"]
    /// Extensions a document opened from outside the app (Files, Mail, AirDrop) is routed to import by.
    static let externallyOpenableFileExtensions = ["hassconfig"]

    // MARK: - Decoded document

    /// The on-disk shape of a server-configuration document. Decode-only: the app reads these files,
    /// it does not write them.
    struct Document: Decodable, Equatable {
        let kind: String?
        let schemaVersion: Int
        let servers: [ServerEntry]

        enum CodingKeys: String, CodingKey {
            case kind
            case schemaVersion
            case servers
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
            // Absent schemaVersion is treated as v1 so a hand-written minimal file still imports.
            self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            self.servers = try container.decodeIfPresent([ServerEntry].self, forKey: .servers) ?? []
        }
    }

    /// One server as described by the file. `longLivedAccessToken` is optional — its presence is what
    /// selects the automatic vs. guided path.
    struct ServerEntry: Decodable, Equatable {
        let name: String
        let externalURL: URL
        let internalURL: URL?
        let longLivedAccessToken: String?

        enum CodingKeys: String, CodingKey {
            case name
            case externalURL
            case internalURL
            case longLivedAccessToken
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawName = try container.decode(String.self, forKey: .name)
            let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw ImportError.invalidServer(reason: .missingName)
            }
            self.name = trimmedName

            let rawExternal = try container.decode(String.self, forKey: .externalURL)
            guard let external = Self.validatedURL(from: rawExternal) else {
                throw ImportError.invalidServer(reason: .invalidExternalURL(rawExternal))
            }
            self.externalURL = external

            if let rawInternal = try container.decodeIfPresent(String.self, forKey: .internalURL),
               !rawInternal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let internalURL = Self.validatedURL(from: rawInternal) else {
                    throw ImportError.invalidServer(reason: .invalidInternalURL(rawInternal))
                }
                self.internalURL = internalURL
            } else {
                self.internalURL = nil
            }

            if let token = try container.decodeIfPresent(String.self, forKey: .longLivedAccessToken) {
                let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                self.longLivedAccessToken = trimmed.isEmpty ? nil : trimmed
            } else {
                self.longLivedAccessToken = nil
            }
        }

        /// Whether the server, as described, is added automatically (token present) rather than
        /// handed to the guided sign-in flow.
        var isAutomatic: Bool {
            longLivedAccessToken != nil
        }

        /// Parses a string into an http/https URL with a host, rejecting anything else (a relative
        /// path, a `file://` URL, a scheme-less string) so a malformed entry can't become a server
        /// the app then tries to talk to.
        private static func validatedURL(from raw: String) -> URL? {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  let host = url.host,
                  !host.isEmpty else {
                return nil
            }
            return url
        }
    }

    // MARK: - Errors

    enum ImportError: LocalizedError, Equatable {
        case notReadable
        case notAServerConfigurationFile(foundKind: String?)
        case unsupportedSchema(Int)
        case noServers
        case invalidServer(reason: InvalidServerReason)

        enum InvalidServerReason: Equatable {
            case missingName
            case invalidExternalURL(String)
            case invalidInternalURL(String)
        }

        var errorDescription: String? {
            switch self {
            case .notReadable:
                return L10n.ImportServers.Error.notReadable
            case let .notAServerConfigurationFile(foundKind):
                return L10n.ImportServers.Error.notAServerFile(
                    foundKind ?? L10n.ImportServers.Error.notAServerFileUnknownKind
                )
            case let .unsupportedSchema(version):
                return L10n.ImportServers.Error.unsupportedSchema(version)
            case .noServers:
                return L10n.ImportServers.Error.emptyServers
            case let .invalidServer(reason):
                switch reason {
                case .missingName:
                    return L10n.ImportServers.Error.missingName
                case let .invalidExternalURL(value):
                    return L10n.ImportServers.Error.invalidExternalUrl(value)
                case let .invalidInternalURL(value):
                    return L10n.ImportServers.Error.invalidInternalUrl(value)
                }
            }
        }
    }

    // MARK: - Per-server outcome

    /// What the import decided to do (or did) for a single server, surfaced in the confirmation screen
    /// and the end-of-run summary.
    struct ServerOutcome: Equatable {
        enum Classification: Equatable {
            /// Will be / was added with no sign-in, using the file's token.
            case automatic
            /// Will be / was handed to the guided sign-in flow.
            case guided
            /// Already configured on this device; nothing to do.
            case duplicate(existingName: String)
            /// The file lists this server's URL again further up, under `firstName`. It is only added
            /// once: it is skipped unless the earlier entry fails, in which case it gets its own attempt.
            case repeatedInFile(firstName: String)
        }

        enum Result: Equatable {
            case pending
            case added
            case skipped(reason: String)
            case failed(reason: String)
            /// Routed into onboarding; its success is observed by the onboarding flow, not here.
            case awaitingGuidedSignIn
        }

        let entry: ServerEntry
        let classification: Classification
        var result: Result
    }

    // MARK: - Decoding + validation (pure)

    /// Decodes and validates a document's bytes. Pure: no I/O, no app state — safe to unit-test and to
    /// run off the main thread. Throws `ImportError` for anything that makes the file unusable.
    static func decode(data: Data) throws -> Document {
        let decoder = JSONDecoder()
        let document: Document
        do {
            document = try decoder.decode(Document.self, from: data)
        } catch let error as ImportError {
            // A per-entry validation failure thrown from ServerEntry.init(from:) is already specific.
            throw error
        } catch {
            throw ImportError.notReadable
        }

        guard document.kind == fileKind else {
            throw ImportError.notAServerConfigurationFile(foundKind: document.kind)
        }
        guard document.schemaVersion <= schemaVersion else {
            throw ImportError.unsupportedSchema(document.schemaVersion)
        }
        guard !document.servers.isEmpty else {
            throw ImportError.noServers
        }
        return document
    }

    /// Reads a file URL and decodes it. Handles the security-scoped resource dance a document opened
    /// from outside the app sandbox requires (mirrors `AppConfigurationTransfer`).
    static func decode(fileURL url: URL) throws -> Document {
        let pathExtension = url.pathExtension.lowercased()
        guard pathExtension.isEmpty || acceptedFileExtensions.contains(pathExtension) else {
            throw ImportError.notAServerConfigurationFile(foundKind: nil)
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.notReadable
        }
        return try decode(data: data)
    }

    /// Whether `url` is the copy iOS placed in this app's `Documents/Inbox` when the file was opened
    /// from another app. The app reads it once, so that copy — which may hold access tokens — is
    /// removed afterwards; a file picked in-app lives outside the container and is never touched.
    static func isInboxCopy(_ url: URL, documentsDirectory: URL) -> Bool {
        let inbox = documentsDirectory
            .appendingPathComponent("Inbox", isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return path.hasPrefix(inbox + "/")
    }

    // MARK: - Classification (pure)

    /// Classifies every entry against the currently-configured servers and the entries before it,
    /// deciding automatic vs. guided vs. duplicate. Pure given the `existingServers` it is handed, so
    /// the confirmation screen can show exactly what the run will do before the user confirms.
    static func classify(
        _ document: Document,
        existingServers: [(name: String, externalURL: URL?)]
    ) -> [ServerOutcome] {
        var firstNameByKey: [String: String] = [:]
        return document.servers.map { entry in
            let key = normalizedKey(for: entry.externalURL)
            defer {
                if firstNameByKey[key] == nil {
                    firstNameByKey[key] = entry.name
                }
            }

            if let match = existingServers.first(where: { existing in
                guard let existingURL = existing.externalURL else { return false }
                return normalizedKey(for: existingURL) == key
            }) {
                return ServerOutcome(
                    entry: entry,
                    classification: .duplicate(existingName: match.name),
                    result: .pending
                )
            }
            if let firstName = firstNameByKey[key] {
                return ServerOutcome(
                    entry: entry,
                    classification: .repeatedInFile(firstName: firstName),
                    result: .pending
                )
            }
            return ServerOutcome(
                entry: entry,
                classification: entry.isAutomatic ? .automatic : .guided,
                result: .pending
            )
        }
    }

    /// The value two external URLs are considered the same server by: lowercased `host:port` plus the
    /// path, scheme-insensitively — `https://ha.example.com` and `https://ha.example.com/` match, and
    /// so do the http/https spellings of the same socket. Mirrors `hostAndPortIdentity`'s reasoning.
    static func normalizedKey(for url: URL) -> String {
        let base = url.serverBaseURL()
        let host = base.host?.lowercased() ?? ""
        let port: Int = base.port ?? (base.scheme?.lowercased() == "http" ? 80 : 443)
        var path = url.sanitized().path
        if path == "/" { path = "" }
        return "\(host):\(port)\(path)"
    }
}
