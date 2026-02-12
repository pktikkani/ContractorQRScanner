import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleRegistrationError(error)
        }
    }
}

@main
struct ContractorQRScannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updateChecker = AppUpdateChecker.shared
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if updateChecker.updateRequired {
                    ForceUpdateView(updateUrl: updateChecker.updateUrl)
                } else {
                    TabView {
                        ScannerView()
                            .tabItem {
                                Label("Scanner", systemImage: "qrcode.viewfinder")
                            }

                        HistoryView()
                            .tabItem {
                                Label("History", systemImage: "clock.arrow.circlepath")
                            }
                    }
                    .tint(AppTheme.primary)
                }
            }
            .id(languageManager.currentLanguage)
            .environment(\.layoutDirection, languageManager.layoutDirection)
            .preferredColorScheme(.dark)
            .task {
                await updateChecker.checkForUpdate()
                _ = await PushNotificationManager.shared.requestPermission()
            }
        }
    }
}

struct ForceUpdateView: View {
    let updateUrl: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(AppTheme.warning.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.warning)
                }

                VStack(spacing: 12) {
                    Text("Update Required")
                        .font(.title2.weight(.bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("A newer version of this app is required to continue. Please update to the latest version.")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let urlString = updateUrl, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Text("Update Now")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.primaryGradient)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
    }
}
