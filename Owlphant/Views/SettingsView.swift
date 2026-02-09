import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScreenBackground {
                VStack(spacing: 18) {
                    SectionCard {
                        Text("Encryption enabled. Data stays local-first.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
