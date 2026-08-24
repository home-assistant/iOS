import Foundation

/// Turns an `AppMigrationPayload` into the chunks it travels in between the two apps, and back.
///
/// The payload is compressed before it is base64url-encoded: it is JSON with a lot of repetition
/// (server settings, widget items), which typically cuts it to a fraction of its size. That matters
/// because everything that fits in one link is handed over without the user ever seeing a round
/// trip — the slicing below only kicks in for the configurations that genuinely cannot.
public enum AppMigrationPayloadCoder {
    public static func data(for payload: AppMigrationPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    public static func payload(from data: Data) throws -> AppMigrationPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload: AppMigrationPayload
        do {
            payload = try decoder.decode(AppMigrationPayload.self, from: data)
        } catch {
            Current.Log.error("Failed to decode app migration payload: \(error.localizedDescription)")
            throw AppMigrationCodingError.malformedPayload
        }

        guard payload.kind == AppMigrationPayload.currentKind else {
            Current.Log.error("Rejected app migration payload with kind \(payload.kind)")
            throw AppMigrationCodingError.notAMigrationPayload
        }
        guard payload.schemaVersion <= AppMigrationPayload.currentSchemaVersion else {
            Current.Log.error("Rejected app migration payload with schema \(payload.schemaVersion)")
            throw AppMigrationCodingError.unsupportedSchema
        }
        return payload
    }

    /// The payload encoded and sliced into the chunks that travel between the apps. Usually one.
    public static func chunks(for payload: AppMigrationPayload, sessionID: String) throws -> [AppMigrationChunk] {
        let raw = try data(for: payload)
        let compressed = try (raw as NSData).compressed(using: .zlib) as Data
        let encoded = compressed.base64URLEncodedString()

        let slices = encoded.slices(ofLength: AppMigrationConstants.maximumChunkLength)
        guard slices.count <= AppMigrationConstants.maximumChunkCount else {
            Current.Log.error("App migration payload needs \(slices.count) chunks; refusing")
            throw AppMigrationCodingError.payloadTooLarge
        }

        Current.Log
            .info("Encoded app migration payload: \(raw.count) byte(s) → \(slices.count) chunk(s)")
        return slices.enumerated().map { index, slice in
            AppMigrationChunk(sessionID: sessionID, index: index, total: slices.count, data: slice)
        }
    }

    /// The inverse: the concatenated chunk data back into a payload.
    public static func payload(fromAssembled assembled: String) throws -> AppMigrationPayload {
        guard let compressed = Data(base64URLEncoded: assembled) else {
            throw AppMigrationCodingError.malformedPayload
        }
        guard let raw = try? (compressed as NSData).decompressed(using: .zlib) as Data else {
            throw AppMigrationCodingError.malformedPayload
        }
        return try self.payload(from: raw)
    }
}

private extension String {
    /// Splits into consecutive slices of at most `length` characters. Operates on unicode scalars via
    /// the string's own index arithmetic, so a slice boundary can never land inside a character.
    func slices(ofLength length: Int) -> [String] {
        guard !isEmpty else { return [] }
        var result: [String] = []
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: length, limitedBy: endIndex) ?? endIndex
            result.append(String(self[start ..< end]))
            start = end
        }
        return result
    }
}
