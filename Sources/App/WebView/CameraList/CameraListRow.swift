import SFSafeSymbols
import Shared
import SwiftUI

struct CameraListRow: View {
    let camera: HAAppEntity

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .videoFill)
                .font(.title2)
                .foregroundStyle(.haPrimary)
            Text(camera.name)
                .font(.body)
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spaces.half)
    }
}
