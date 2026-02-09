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

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}
