import Foundation
import UserNotifications
import UIKit

final class PushNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted {
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
        return granted
    }

    func registerDeviceToken(_ tokenData: Data, token: String?) async {
        guard let token else { return }
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        let body = PushTokenBody(token: tokenString, platform: "apns")
        let _: EmptyResponse? = try? await APIClient.shared.post(
            "/users/me/push-token",
            body: body,
            token: token
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

private struct PushTokenBody: Encodable {
    let token: String
    let platform: String
}

private struct EmptyResponse: Decodable {}
