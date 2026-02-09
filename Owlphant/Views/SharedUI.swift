import SwiftUI

struct ScreenBackground<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.accent.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 16)
                .offset(x: 150, y: -220)

            Circle()
                .fill(AppTheme.tint.opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 14)
                .offset(x: -140, y: 280)

            content
        }
    }
}

struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 6)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.tint.opacity(configuration.isPressed ? 0.84 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct PillView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(.caption, design: .rounded).weight(.medium))
            .foregroundStyle(AppTheme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.surfaceAlt)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.stroke, lineWidth: 1))
    }
}

private struct AppInputChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.body, design: .rounded))
            .foregroundStyle(AppTheme.text)
            .tint(AppTheme.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func appInputChrome() -> some View {
        modifier(AppInputChromeModifier())
    }
}
