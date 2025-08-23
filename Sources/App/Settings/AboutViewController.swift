import CPDAcknowledgements
import Shared
import SwiftUI

struct AboutView: View {
    @State private var showVersionAlert = false

    var shouldHideSocialsNotAvailableInChina: Bool {
        if let lang = Locale.current.languageCode, lang.hasPrefix("zh") {
            return true
        }
        return false
    }

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: nil,
                headerImageAlternativeView: AnyView(
                    Image(uiImage: Asset.logo.image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                ),
                title: L10n.About.Logo.appTitle,
                subtitle: HomeAssistantAPI.clientVersionDescription
            )
            .onTapGesture {
                showVersionAlert = true
            }

            Section {
                if Current.appConfiguration != .beta {
                    Link(
                        L10n.About.Beta.title,
                        destination: Current.isCatalyst ? AppConstants.WebURLs.betaMac : AppConstants.WebURLs.beta
                    )
                }

                NavigationLink(destination: AcknowledgementsView()) {
                    Text(L10n.About.Acknowledgements.title)
                }

                Link(
                    L10n.About.Review.title,
                    destination: Current.isCatalyst ? AppConstants.WebURLs.reviewMac : AppConstants.WebURLs.review
                )

                Link(L10n.About.HelpLocalize.title, destination: AppConstants.WebURLs.translate)
            }

            Section {
                Link(L10n.About.Website.title, destination: AppConstants.WebURLs.homeAssistant)

                Link(L10n.About.Forums.title, destination: AppConstants.WebURLs.forums)

                Link(L10n.About.Chat.title, destination: AppConstants.WebURLs.chat)

                Link(L10n.About.Documentation.title, destination: AppConstants.WebURLs.companionAppDocs)
            }

            if !shouldHideSocialsNotAvailableInChina {
                Section {
                    Link(L10n.About.HomeAssistantOnTwitter.title, destination: AppConstants.WebURLs.twitter)

                    Link(L10n.About.HomeAssistantOnFacebook.title, destination: AppConstants.WebURLs.facebook)
                }
            }

            Section {
                Link(L10n.About.Github.title, destination: AppConstants.WebURLs.repo)

                Link(L10n.About.GithubIssueTracker.title, destination: AppConstants.WebURLs.issues)
            }
        }
        .navigationTitle(L10n.About.title)
        .alert(isPresented: $showVersionAlert) {
            Alert(
                title: Text(""),
                message: Text(HomeAssistantAPI.clientVersionDescription),
                primaryButton: .default(Text(L10n.copyLabel), action: {
                    UIPasteboard.general.string = HomeAssistantAPI.clientVersionDescription
                }),
                secondaryButton: .cancel(Text(L10n.cancelLabel))
            )
        }
    }
}

struct AcknowledgementsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CPDAcknowledgementsViewController {
        var licenses = [CPDLibrary]()

        for fileName in [
            "Pods-iOS-App-metadata",
            "ManualPodLicenses",
        ] {
            if let file = Bundle.main.url(forResource: fileName, withExtension: "plist"),
               let dictionary = NSDictionary(contentsOf: file),
               let license = dictionary["specs"] as? [[String: Any]] {
                licenses += license.map { CPDLibrary(cocoaPodsMetadataPlistDictionary: $0) }
            }
        }

        licenses.sort(by: { $0.title < $1.title })

        return CPDAcknowledgementsViewController(style: nil, acknowledgements: licenses, contributions: nil)
    }

    func updateUIViewController(_ uiViewController: CPDAcknowledgementsViewController, context: Context) {}
}
