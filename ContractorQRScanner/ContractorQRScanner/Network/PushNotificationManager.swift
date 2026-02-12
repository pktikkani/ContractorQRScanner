import Combine
import Foundation
import UserNotifications
import UIKit

@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published var isRegistered = false
    @Published var deviceToken: String?

    private let baseURL = AppConfig.apiBaseURL

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await registerForRemoteNotifications()
            }
            return granted
        } catch {
            #if DEBUG
            print("Notification permission error: \(error)")
            #endif
            return false
        }
    }

    func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = tokenString
        isRegistered = true

        #if DEBUG
        print("APNs device token: \(tokenString)")
        #endif

        Task {
            await registerTokenWithServer(tokenString)
        }
    }

    func handleRegistrationError(_ error: Error) {
        #if DEBUG
        print("APNs registration failed: \(error)")
        #endif
        isRegistered = false
    }

    private func registerTokenWithServer(_ token: String) async {
        guard let url = URL(string: "\(baseURL)/api/v1/notifications/register") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: String] = [
            "device_token": token,
            "platform": "ios"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)

            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("Token registration status: \(httpResponse.statusCode)")
            }
            #endif
        } catch {
            #if DEBUG
            print("Token registration failed: \(error)")
            #endif
        }
    }

    func unregisterToken() async {
        guard let token = deviceToken else { return }

        guard let url = URL(string: "\(baseURL)/api/v1/notifications/unregister") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "device_token": token,
            "platform": "ios"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("Token unregistration failed: \(error)")
            #endif
        }

        deviceToken = nil
        isRegistered = false
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String {
            Task { @MainActor in
                handleNotificationAction(type: type, userInfo: userInfo)
            }
        }

        completionHandler()
    }

    @MainActor
    private func handleNotificationAction(type: String, userInfo: [AnyHashable: Any]) {
        switch type {
        case "site_assignment":
            NotificationCenter.default.post(name: .siteAssignmentChanged, object: nil)
        case "scanner_alert":
            NotificationCenter.default.post(name: .scannerAlert, object: nil, userInfo: userInfo as? [String: Any])
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let siteAssignmentChanged = Notification.Name("siteAssignmentChanged")
    static let scannerAlert = Notification.Name("scannerAlert")
}
