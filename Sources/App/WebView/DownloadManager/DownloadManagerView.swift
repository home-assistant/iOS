import Shared
import SwiftUI

@available(iOS 17.0, *)
struct DownloadManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject var viewModel: DownloadManagerViewModel
    @State private var shareWrapper: ShareWrapper?

    init(viewModel: DownloadManagerViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: .zero) {
            closeButton
            content
            Spacer()
        }
        .onDisappear {
            viewModel.cancelDownload()
            viewModel.deleteFile()
        }
        .onChange(of: viewModel.finished) { _, newValue in
            if newValue, Current.isCatalyst {
                UIApplication.shared.open(AppConstants.DownloadsDirectory)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.finished {
            successView
        } else if viewModel.failed {
            fileCard
            failedCard
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(2)
                .padding(Spaces.four)
            Text(L10n.DownloadManager.Downloading.title)
                .font(.title.bold())
            fileCard
            Text(viewModel.progress)
                .animation(.easeInOut(duration: 1), value: viewModel.progress)
        }
    }

    private var closeButton: some View {
        HStack {
            Button(action: {
                dismiss()
            }, label: {
                Image(systemSymbol: .xmarkCircleFill)
                    .font(.title)
                    .foregroundStyle(
                        Color(uiColor: .systemBackground),
                        .gray.opacity(0.5)
                    )
            })
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
        }
    }

    private var successView: some View {
        VStack(spacing: Spaces.three) {
            Image(systemSymbol: .checkmark)
                .foregroundStyle(.green)
                .font(.system(size: 100))
                .symbolEffect(
                    .bounce,
                    options: .nonRepeating
                )
            Text(L10n.DownloadManager.Finished.title)
                .font(.title.bold())
            if let url = viewModel.lastURLCreated {
                if Current.isCatalyst {
                    Button {
                        UIApplication.shared.open(AppConstants.DownloadsDirectory)
                    } label: {
                        Label(viewModel.fileName, systemSymbol: .folder)
                    }
                } else {
                    ShareLink(viewModel.fileName, item: url)
                        .padding()
                        .foregroundStyle(.white)
                        .background(Color.asset(Asset.Colors.haPrimary))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                        .onAppear(perform: {
                            shareWrapper = .init(url: url)
                        })
                        .sheet(item: $shareWrapper, onDismiss: {}, content: { data in
                            ActivityViewController(shareWrapper: data)
                        })
                }
            }
        }
    }

    private var fileCard: some View {
        HStack {
            Image(systemSymbol: .docZipper)
            Text(viewModel.fileName)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.gray.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private var failedCard: some View {
        Text(viewModel.errorMessage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding()
            .background(.red.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        DownloadManagerView(viewModel: .init())
    } else {
        Text("Hey there")
    }
}

struct ShareWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityViewController: UIViewControllerRepresentable {
    let shareWrapper: ShareWrapper
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [shareWrapper.url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
