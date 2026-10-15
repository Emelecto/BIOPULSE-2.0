import SwiftUI

@main
struct BioPulseApp: App {
    @StateObject private var auth = AuthSessionStore()

    var body: some Scene {
        WindowGroup {
            AuthGateView(auth: auth)
        }
    }
}
