import AVFoundation
import Foundation

extension AVMetadataObject.ObjectType {
    var haString: String {
        if #available(iOS 15.4, *), self == .codabar {
            return "codabar"
        }

        switch self {
        case .qr: return "qr_code"
        case .aztec: return "aztec"
        case .code128: return "code_128"
        case .code39: return "code_39"
        case .code93: return "code_93"
        case .dataMatrix: return "data_matrix"
        case .ean13: return "ean_13"
        case .ean8: return "ean_8"
        case .itf14: return "itf"
        case .pdf417: return "pdf417"
        case .upce: return "upc_e"
        default: return "unknown"
        }
    }
}
