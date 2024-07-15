//
//  ImprovDiscoverView.swift
//  App
//
//  Created by Bruno Pantaleão on 15/07/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import SwiftUI
import Improv_iOS
import Shared

struct ImprovDiscoverView<Manager>: View where Manager: ImprovManagerProtocol {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var improvManager: Manager
    @State private var fullScreen = false
    @State private var animationHappened = false
    @State private var shadowRadius: CGFloat = 10

    private let bottomSheetHeight: CGFloat = 400

    // swiftlint: disable force_cast
    init(improvManager: any ImprovManagerProtocol) {
        self._improvManager = .init(wrappedValue: improvManager as! Manager)
    }

    var body: some View {
        VStack {
            if !fullScreen {
                Spacer()
            }
            VStack {
                if fullScreen {
                    fullScreenContent
                } else {
                    bottomSheetContent
                }
            }
            .padding(.horizontal)
            .frame(height: fullScreen ? nil : bottomSheetHeight)
            .frame(maxHeight: fullScreen ? .infinity : nil)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: fullScreen ? 0 : 50))
            .shadow(radius: fullScreen ? 0 : 20)
            .padding(fullScreen ? 0 : Spaces.one)
            .offset(y: animationHappened ? 0 : bottomSheetHeight)
            .onAppear {
                withAnimation(.bouncy) {
                    animationHappened = true
                }
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background((animationHappened && !fullScreen ) ? .black.opacity(0.3) : .clear)
        .animation(.default, value: fullScreen)
        .modify {
            if #available(iOS 16, *) {
                $0.persistentSystemOverlays(fullScreen ? .automatic : .hidden)
            } else {
                $0
            }
        }
        .onAppear {
            if improvManager.bluetoothState == .poweredOn {
                improvManager.scan()
            }
        }
        .onChange(of: improvManager.bluetoothState) { newValue in
            if newValue == .poweredOn {
                improvManager.scan()
            }
        }
    }

    @ViewBuilder
    private var bottomSheetContent: some View {
        closeButton
        bottomSheetHeader
        Spacer()
        deviceIcon
        Spacer()
        continueButton
    }

    private var deviceIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundStyle(.regularMaterial)
                    .font(.system(size: 80))
                    .shadow(color: .blue, radius: shadowRadius)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            self.shadowRadius = 40
                        }
                    }
            }
            .frame(width: 100, height: 100)
            VStack {
                Text("\(improvManager.foundDevices.count)")
                    .padding(Spaces.one)
                    .fixedSize()
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .animation(nil)
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var fullScreenContent: some View {
        List {
            ForEach(improvManager.foundDevices.keys.sorted(), id: \.self) { peripheralKey in
                if let peripheral = improvManager.foundDevices[peripheralKey] {
                    NavigationLink {
//                        DeviceView<ImprovManager>(peripheral: peripheral)
//                            .environmentObject(improvManager)
                        EmptyView()
                    } label: {
                        Text(peripheral.name ?? peripheral.identifier.uuidString)
                    }
                }
            }           
            Button {
                fullScreen = false
            } label: {
                Text("return")
            }
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
        .modify {
            if #available(iOS 16, *) {
                $0.scrollContentBackground(.hidden)
            } else {
                $0
            }
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: {
                dismiss()
            }, label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.black, .gray)
            })
        }
        .padding(.top, Spaces.three)
        .padding([.trailing, .bottom], Spaces.one)
    }

    @ViewBuilder
    private var bottomSheetHeader: some View {
        Text("Setup Improv devices")
            .font(.title.bold())
    }

    @ViewBuilder
    private var continueButton: some View {
        Button {
            fullScreen = true
        } label: {
            Text("Continue")
//                .foregroundStyle(Color(uiColor: .label))
                .padding()
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
}

#Preview {
    ZStack {
        VStack {

        }
        .background(.blue)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        ImprovDiscoverView<ImprovManager>(improvManager: ImprovManager.shared)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
