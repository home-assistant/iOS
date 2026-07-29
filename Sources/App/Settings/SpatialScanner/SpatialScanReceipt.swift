#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

struct SpatialScanReceipt: Equatable {
    let scanID: String
    let storedAt: String
    let bytes: Int
}
#endif
