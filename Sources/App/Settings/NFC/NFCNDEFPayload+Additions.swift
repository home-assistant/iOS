import CoreNFC

extension NFCNDEFPayload {
    @available(iOS 13, *)
    class func androidPackage(payload: String) -> Self? {
        // NFC Record Type Definition (RTD) of 'external' states type must be ascii
        // android-specific payload looks to be utf8 from the android spec

        guard let type = "android.com:pkg".data(using: .ascii),
              let payload = payload.data(using: .utf8) else {
            return nil
        }

        return .init(
            format: .nfcExternal,
            type: type,
            // empty identifier will cause it to be ignored
            identifier: Data(),
            payload: payload
        )
    }
}
