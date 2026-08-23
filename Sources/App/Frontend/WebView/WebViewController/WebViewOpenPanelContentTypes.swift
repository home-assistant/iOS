import UniformTypeIdentifiers

/// Resolves the content types used by the Mac Catalyst file-open panel.
///
/// WebKit's `WKOpenPanelParameters.allowedContentTypes` is often empty or a tight audio subset
/// that omits FLAC even when the frontend `accept` list (and Safari) would allow it. Empty and
/// audio-related type lists are widened to `public.audio`, `public.item`, and `.flac`.
enum WebViewOpenPanelContentTypes {
    static let audioFallbackTypes: [UTType] = [.audio, .item, .flac]

    static func contentTypes(requested: [UTType]) -> [UTType] {
        if requested.isEmpty {
            return audioFallbackTypes
        }
        if allowsSelectingFlac(requested) {
            return requested
        }
        guard isAudioRelated(requested) else {
            return requested
        }
        var types = requested
        for extra in audioFallbackTypes where !types.contains(extra) {
            types.append(extra)
        }
        return types
    }

    /// Types advertised by `WKOpenPanelParameters`, when the property exists.
    static func requestedTypes(from parameters: AnyObject) -> [UTType] {
        guard parameters.responds(to: Selector(("allowedContentTypes"))) else {
            return []
        }
        guard let value = parameters.value(forKey: "allowedContentTypes") else {
            return []
        }
        if let types = value as? [UTType] {
            return types
        }
        guard let items = value as? [Any] else {
            return []
        }
        return items.compactMap { item in
            if let type = item as? UTType {
                return type
            }
            if let identifier = item as? String {
                return UTType(identifier)
            }
            return nil
        }
    }

    static func allowsSelectingFlac(_ types: [UTType]) -> Bool {
        types.contains { UTType.flac.conforms(to: $0) }
    }

    static func isAudioRelated(_ types: [UTType]) -> Bool {
        types.contains { type in
            type.conforms(to: .audio) || type.identifier.contains("audio")
        }
    }
}
