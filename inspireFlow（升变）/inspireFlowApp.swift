//
//  inspireFlowApp.swift
//  inspireFlow
//
//  Created by 叶文峰 on 2026/7/23.
//

import SwiftUI

@main
struct inspireFlowApp: App {
    @StateObject private var appStore = AppStore()
    @StateObject private var session = AppSession()
    @StateObject private var ringManager = RingManager()

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootView(hasCompletedOnboarding: $hasCompletedOnboarding)
            .environmentObject(appStore)
            .environmentObject(session)
            .environmentObject(ringManager)
            .task {
                if ringManager.hasSavedRing {
                    ringManager.reconnectSaved()
                }
                await session.restoreSession()
                await session.loadCreatorProfile()
                await appStore.syncRemoteData(accessToken: session.accessToken)
            }
            .onChange(of: session.userID) { _, userID in
                guard userID != nil, !session.isDemoMode else { return }
                Task {
                    await session.loadCreatorProfile()
                    await appStore.syncRemoteData(accessToken: session.accessToken)
                }
            }
        }
    }
}

#Preview("Main Content") {
    StartView(
        hasCompletedOnboarding: .constant(true)
    )
    .environmentObject(AppStore())
    .environmentObject(AppSession())
}
