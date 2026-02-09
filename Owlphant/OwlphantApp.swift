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
            ContentView()
                .preferredColorScheme(appearanceMode.colorScheme)
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
                .onChange(of: appLanguageRawValue) { _, newValue in
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                }
        }
    }
}
