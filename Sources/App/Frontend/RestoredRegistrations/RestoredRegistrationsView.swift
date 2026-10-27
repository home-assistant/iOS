import SFSafeSymbols
import Shared
import SwiftUI

struct RestoredRegistrationsView: View {
    @StateObject private var viewModel: RestoredRegistrationsViewModel
    @State private var detent = PresentationDetent.medium

    init(viewModel: @autoclosure @escaping () -> RestoredRegistrationsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: DesignSystem.Spaces.three) {
                        Image(uiImage: MaterialDesignIcons.cellphoneArrowDownVariantIcon.image(
                            ofSize: .init(width: 64, height: 64),
                            color: .haPrimary
                        ))
                        .accessibilityHidden(true)
                        Text(L10n.RestoredRegistrations.title)
                            .font(DesignSystem.Font.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(L10n.RestoredRegistrations.explanation)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if viewModel.hasStarted, viewModel.servers.count > 1 {
                            Text(L10n.RestoredRegistrations.progress(viewModel.doneCount, viewModel.servers.count))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        VStack(spacing: DesignSystem.Spaces.one) {
                            ForEach(viewModel.servers, id: \.identifier) { server in
                                let state = viewModel.state(of: server)
                                HStack(spacing: DesignSystem.Spaces.one) {
                                    if state.isInProgress {
                                        ProgressView()
                                            .frame(width: DesignSystem.Spaces.three, height: DesignSystem.Spaces.three)
                                    } else {
                                        Image(systemSymbol: state.symbol)
                                            .foregroundStyle(state.symbolColor)
                                            .frame(width: DesignSystem.Spaces.three, height: DesignSystem.Spaces.three)
                                    }
                                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                                        Text(server.info.name)
                                            .font(.body)
                                        Text(state.title)
                                            .font(.footnote)
                                            .foregroundStyle(state.titleColor)
                                    }
                                    Spacer()
                                }
                                .padding(DesignSystem.Spaces.one)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )
                                .accessibilityElement(children: .combine)
                                .id(server.identifier)
                            }
                        }
                        Text(L10n.RestoredRegistrations.choices)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: viewModel.login?.server.identifier) { identifier in
                    guard let identifier else { return }
                    withAnimation {
                        proxy.scrollTo(identifier, anchor: .center)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.three)
            .ignoresSafeArea(.container, edges: detent == .large ? [] : .horizontal)
            VStack(spacing: DesignSystem.Spaces.one) {
                Button(action: viewModel.startSettingUpAsNewDevice) {
                    Text(viewModel.newDeviceTitle)
                }
                .buttonStyle(.primaryButton)
                .accessibilityIdentifier(AccessibilityIdentifier.restoredRegistrationsNewDevice.rawValue)
                Button(action: viewModel.confirmReplacingOldDevice) {
                    Text(L10n.RestoredRegistrations.replaceDevice)
                }
                .buttonStyle(.secondaryButton)
                .accessibilityIdentifier(AccessibilityIdentifier.restoredRegistrationsReplace.rawValue)
                .confirmationDialog(
                    L10n.RestoredRegistrations.Replace.title,
                    isPresented: $viewModel.isReplaceConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button(L10n.RestoredRegistrations.Replace.confirm, action: viewModel.replaceOldDevice)
                    Button(L10n.cancelLabel, role: .cancel) {}
                } message: {
                    Text(L10n.RestoredRegistrations.Replace.message)
                }
            }
            .disabled(viewModel.isRegistering)
            .padding(.horizontal, DesignSystem.Spaces.three)
            .ignoresSafeArea(.container, edges: .horizontal)
        }
        .padding(.top, DesignSystem.Spaces.four)
        .padding(.bottom, DesignSystem.Spaces.one)
        .presentationDetents([.medium, .large], selection: $detent)
        .interactiveDismissDisabled(viewModel.isRegistering)
        .sheet(isPresented: $viewModel.isSheetPresented) {
            switch viewModel.sheet {
            case let .login(login)?:
                OnboardingAuthLoginView(
                    viewModel: login.viewModel,
                    style: .modal,
                    title: L10n.RestoredRegistrations.Login.title(login.server.info.name),
                    banner: login.count > 1
                        ? L10n.RestoredRegistrations.Login.progress(login.position, login.count)
                        : nil
                )
                .id(login.id)
            case let .nextServer(next)?:
                RestoredRegistrationsNextServerView(next: next)
            case nil:
                EmptyView()
            }
        }
    }
}

private extension RestoredRegistrationsViewModel.SetupState {
    var symbol: SFSymbol {
        switch self {
        case .waiting, .signingIn, .registering: return .circle
        case .done: return .checkmarkCircleFill
        case .skipped: return .minusCircle
        case .failed: return .exclamationmarkCircleFill
        }
    }

    var symbolColor: Color {
        switch self {
        case .waiting, .signingIn, .registering: return .secondary
        case .done: return .green
        case .skipped: return .secondary
        case .failed: return .red
        }
    }

    var titleColor: Color {
        if case .failed = self { return .red }
        return .secondary
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RestoredRegistrationsView(viewModel: RestoredRegistrationsViewModel(
                servers: FakeServerManager(initial: 2).all,
                onFinished: {}
            ))
        }
}
