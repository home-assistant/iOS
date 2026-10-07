import Foundation

struct AcknowledgementPackage: Decodable, Identifiable {
    struct ResolvedFile: Decodable {
        struct Object: Decodable {
            let pins: [AcknowledgementPackage]
        }

        let object: Object
    }

    struct State: Decodable {
        let revision: String?
    }

    let name: String
    let repositoryURL: URL
    let state: State

    var id: URL { repositoryURL }

    var displayName: String {
        repositoryURL.lastPathComponent.replacingOccurrences(of: ".git", with: "")
    }

    var licenseURLs: [URL] {
        guard repositoryURL.host() == "github.com" else { return [] }

        let components = repositoryURL.pathComponents.filter { $0 != "/" }
        guard components.count >= 2, let revision = state.revision else { return [] }

        let owner = components[0]
        let repository = components[1].replacingOccurrences(of: ".git", with: "")
        return [
            "LICENSE",
            "LICENSE.md",
            "LICENSE.txt",
            "COPYING",
        ].compactMap { fileName in
            URL(string: "https://raw.githubusercontent.com/\(owner)/\(repository)/\(revision)/\(fileName)")
        }
    }

    enum CodingKeys: String, CodingKey {
        case name = "package"
        case repositoryURL
        case state
    }

    func loadLicenseText() async -> String? {
        for url in licenseURLs {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let response = response as? HTTPURLResponse,
                      (200 ..< 300).contains(response.statusCode),
                      let text = String(data: data, encoding: .utf8),
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<!DOCTYPE html>") else {
                    continue
                }
                return text
            } catch {
                continue
            }
        }
        return nil
    }

    static func load() -> [AcknowledgementPackage] {
        guard let url = Bundle.main.url(forResource: "Package", withExtension: "resolved"),
              let data = try? Data(contentsOf: url),
              let resolvedFile = try? JSONDecoder().decode(ResolvedFile.self, from: data) else {
            return []
        }

        return resolvedFile.object.pins
            .filter { $0.displayName != "SPM-Acknowledgments" }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
