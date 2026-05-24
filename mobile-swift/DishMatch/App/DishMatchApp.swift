import SwiftUI

@main
struct DishdApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authStore = AuthStore.shared
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentCoordinator()
                .environmentObject(authStore)
                .environmentObject(themeStore)
        }
    }
}
