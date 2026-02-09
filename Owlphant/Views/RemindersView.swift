import SwiftUI

struct RemindersView: View {
    var body: some View {
        NavigationStack {
            ScreenBackground {
                VStack(spacing: 18) {
                    SectionCard {
                        Text("Reminders")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundStyle(AppTheme.text)
                        Text("Never miss birthdays, anniversaries, or the small moments.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.muted)
                    }

                    SectionCard {
                        Text("Coming soon")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text("We will add local notification scheduling, custom reminder types, and a timeline view.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
