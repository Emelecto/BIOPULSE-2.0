import SwiftUI
import Combine
import UIKit
import UserNotifications

@MainActor
final class SleepNotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = SleepNotificationRouter()
    @Published var requestedAccountID: UUID?

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.content.userInfo["destination"] as? String == "sleep-check-in",
              let identifier = response.notification.request.content.userInfo["accountID"] as? String,
              let accountID = UUID(uuidString: identifier) else { return }
        await MainActor.run { self.requestedAccountID = accountID }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

@MainActor
final class BioPulseAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = SleepNotificationRouter.shared
        return true
    }
}

@main
struct BioPulseApp: App {
    @UIApplicationDelegateAdaptor(BioPulseAppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthSessionStore()

    var body: some Scene {
        WindowGroup {
            AuthGateView(auth: auth)
                .environmentObject(SleepNotificationRouter.shared)
        }
    }
}
