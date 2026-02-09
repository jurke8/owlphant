//
//  ContentView.swift
//  Owlphant
//
//  Created by Ivan Juric on 08.02.2026..
//

import SwiftUI

struct ContentView: View {
    @StateObject private var contactsViewModel = ContactsViewModel()

    var body: some View {
        TabView {
            ContactsView(viewModel: contactsViewModel)
                .tabItem {
                    Label(L10n.tr("tab.contacts"), systemImage: "person.2.fill")
                }

            EventsView(viewModel: contactsViewModel)
                .tabItem {
                    Label(L10n.tr("tab.events"), systemImage: "bell.fill")
                }

            PeopleMapView()
                .tabItem {
                    Label(L10n.tr("tab.map"), systemImage: "map.fill")
                }

            SettingsView(viewModel: contactsViewModel)
                .tabItem {
                    Label(L10n.tr("tab.settings"), systemImage: "gearshape.fill")
                }
        }
        .tint(AppTheme.tint)
        .task {
            if !contactsViewModel.isReady {
                await contactsViewModel.bootstrap()
            }
        }
    }
}

#Preview {
    ContentView()
}
