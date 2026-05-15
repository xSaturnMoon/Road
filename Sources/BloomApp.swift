import SwiftUI

@main
struct BloomApp: App {
    @StateObject private var appManager = AppManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appManager)
        }
    }
}
