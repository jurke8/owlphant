import SwiftUI

struct LockScreenView: View {
    @ObservedObject var appLockService: AppLockService

    var body: some View {
        ScreenBackground {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: appLockService.biometryIconName)
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(AppTheme.tint)

                VStack(spacing: 6) {
                    Text(L10n.tr("lock.title"))
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.text)

                    Text(L10n.tr("lock.subtitle"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Button {
                    Task {
                        await appLockService.authenticate()
                    }
                } label: {
                    Label(L10n.tr("lock.button"), systemImage: appLockService.biometryIconName)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 60)
            }
            .padding(20)
        }
        .task {
            await appLockService.authenticate()
        }
    }
}
