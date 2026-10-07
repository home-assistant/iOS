import Shared
import SwiftUI

struct AcknowledgementsView: View {
    private let packages = AcknowledgementPackage.load()

    var body: some View {
        List {
            Section {
                ForEach(packages) { package in
                    NavigationLink(package.displayName) {
                        AcknowledgementLicenseView(package: package)
                    }
                }
            } footer: {
                Link(
                    "Generated from Swift Package Manager",
                    destination: URL(string: "https://swift.org/package-manager/")!
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(L10n.About.Acknowledgements.title)
    }
}

private struct AcknowledgementLicenseView: View {
    let package: AcknowledgementPackage
    @State private var licenseText: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(licenseText ?? package.repositoryURL.absoluteString)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .navigationTitle(package.displayName)
        .task {
            licenseText = await package.loadLicenseText()
            isLoading = false
        }
    }
}
