//
//  OwlphantApp.swift
//  Owlphant
//
//  Created by Ivan Juric on 08.02.2026..
//

import SwiftUI

@main
struct OwlphantApp: App {
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue: String = AppLanguage.defaultValue.rawValue
    @StateObject private var appLockService = AppLockService()
    @Environment(\.scenePhase) private var scenePhase

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .defaultValue
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.defaultValue.rawValue
        UserDefaults.standard.set([stored], forKey: "AppleLanguages")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .preferredColorScheme(appearanceMode.colorScheme)
                    .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
                    .onChange(of: appLanguageRawValue) { _, newValue in
                        UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    }

                if appLockService.isLocked {
                    LockScreenView(appLockService: appLockService)
                        .preferredColorScheme(appearanceMode.colorScheme)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appLockService.isLocked)
            .environmentObject(appLockService)
            .onChange(of: scenePhase) {
                if scenePhase == .background {
                    appLockService.lock()
                }
            }
        }
    }
}
