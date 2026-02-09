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
                    Label("Contacts", systemImage: "person.2.fill")
                }

            BirthdaysView(viewModel: contactsViewModel)
                .tabItem {
                    Label("Birthdays", systemImage: "bell.fill")
                }

            PeopleMapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

            SettingsView(viewModel: contactsViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
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
