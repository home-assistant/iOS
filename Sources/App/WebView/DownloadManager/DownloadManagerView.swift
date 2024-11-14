import Shared
import SwiftUI

@available(iOS 17.0, *)
struct DownloadManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject var viewModel: DownloadManagerViewModel

    init(viewModel: DownloadManagerViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: .zero) {
            HStack {
                Button(action: {
                    viewModel.cancelDownload()
                    viewModel.deleteFile()
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
            Spacer()
        }
        .onChange(of: viewModel.finished) { _, newValue in
            if newValue, Current.isCatalyst {
                UIApplication.shared.open(AppConstants.DownloadsDirectory)
            }
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
