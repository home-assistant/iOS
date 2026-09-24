import Foundation

/// What changed about a modal that is already up, as the frontend describes it in `modal/update`.
///
/// The header arrives whenever the page's own header would change; the size when a dialog opens over
/// the page, which a half-height modal would clip. Both are optional and at least one is present.
struct NativeModalUpdate: Equatable {
    let size: NativeModalSize?
    let header: NativeModalHeader?

    init?(payload: [String: Any]?) {
        guard let payload else { return nil }
        self.size = payload["size"].flatMap { NativeModalSize(payload: $0) }
        self.header = NativeModalHeader(payload: payload["header"] as? [String: Any])
        if size == nil, header == nil {
            return nil
        }
    }

    init(size: NativeModalSize? = nil, header: NativeModalHeader? = nil) {
        self.size = size
        self.header = header
    }
}
