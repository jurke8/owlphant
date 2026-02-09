import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScreenBackground {
                VStack(spacing: 18) {
                    SectionCard {
                        Text("Settings")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundStyle(AppTheme.text)
                        Text("Security, AI consent, and imports live here.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.muted)
                    }

                    SectionCard {
                        Text("Security status")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text("Encryption enabled. Data stays local-first.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.muted)
                    }

                    SectionCard {
                        Text("AI consent")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text("You are in control of when decrypted data is shared with AI.")
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
