import SwiftUI
import UserNotifications
import PostHog

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
    @StateObject private var session = SessionManager.shared

    init() {
        let config = PostHogConfig(apiKey: "phc_CurIZV9XmtBqTKKge7QkXBDvJECYBzn2yIOAbKBrh3R", host: "https://us.i.posthog.com")
        config.flushAt = 1
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if updateChecker.updateRequired {
                    ForceUpdateView(updateUrl: updateChecker.updateUrl)
                } else if !session.isAuthenticated {
                    LoginView(session: session)
                } else if session.assignedSite == nil {
                    SiteSelectionView(session: session)
                } else {
                    MainScannerView(session: session)
                }
            }
            .id(languageManager.currentLanguage)
            .environment(\.layoutDirection, languageManager.layoutDirection)
            .preferredColorScheme(.light)
            .task {
                await updateChecker.checkForUpdate()
                // Defer push permission to avoid blocking first render
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                _ = await PushNotificationManager.shared.requestPermission()
            }
        }
    }
}

/// Main scanner view with tabs and guard info header
struct MainScannerView: View {
    @ObservedObject var session: SessionManager
    @State private var showLogout = false

    var body: some View {
        TabView {
            ScannerView()
                .tabItem {
                    Label("Scanner", systemImage: "qrcode.viewfinder")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            GuardProfileView(session: session)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .tint(AppTheme.primary)
    }
}

/// Guard profile tab with session info + logout
struct GuardProfileView: View {
    @ObservedObject var session: SessionManager
    @State private var showLogoutConfirm = false
    @State private var isRefreshingBundle = false
    @State private var bundleStatus: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Guard info card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primary.opacity(0.10))
                                .frame(width: 80, height: 80)

                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.primary)
                        }

                        Text(session.guardName)
                            .font(.title3.weight(.bold))
                            .foregroundColor(AppTheme.textPrimary)

                        if let site = session.assignedSite {
                            HStack(spacing: 8) {
                                Image(systemName: "building.2.fill")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.primary)
                                Text(site.siteName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                            Text("Site Code: \(site.siteCode)")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .fill(AppTheme.cardBackground)
                            .shadow(color: AppTheme.cardShadow, radius: 12, y: 4)
                    )

                    // Offline cache info
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(AppTheme.primary)
                            Text("Offline Cache")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                        }

                        HStack {
                            Text("Cached contractors:")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("\(OfflineValidationCache.shared.cachedContractorCount)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        if let status = bundleStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(AppTheme.success)
                        }

                        Button(action: refreshBundle) {
                            HStack(spacing: 8) {
                                if isRefreshingBundle {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(AppTheme.primary)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Refresh Offline Data")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(AppTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.primary.opacity(0.08))
                            )
                        }
                        .disabled(isRefreshingBundle)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .fill(AppTheme.cardBackground)
                            .shadow(color: AppTheme.cardShadow, radius: 12, y: 4)
                    )

                    // Logout button
                    Button(action: { showLogoutConfirm = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.square")
                            Text("Sign Out")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(AppTheme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.danger.opacity(0.08))
                        )
                    }
                }
                .padding(20)
            }
        }
        .alert("Sign Out", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { session.logout() }
        } message: {
            Text("This will clear your session and offline cache. You'll need to sign in again.")
        }
    }

    private func refreshBundle() {
        guard let token = session.token else { return }
        isRefreshingBundle = true
        bundleStatus = nil

        Task {
            do {
                let bundle = try await APIClient.shared.fetchOfflineBundle(token: token)
                OfflineValidationCache.shared.storeOfflineBundle(contractors: bundle.contractors)
                await MainActor.run {
                    bundleStatus = "Updated: \(bundle.contractors.count) contractors cached"
                    isRefreshingBundle = false
                }
            } catch {
                await MainActor.run {
                    bundleStatus = "Error: \(error.localizedDescription)"
                    isRefreshingBundle = false
                }
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
                            .foregroundColor(AppTheme.textOnPrimary)
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
