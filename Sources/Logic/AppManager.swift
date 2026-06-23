import Foundation
import SwiftUI

class AppManager: ObservableObject {
    static let shared = AppManager()
    @Published var selectedTab: Int = 0
    /// Hides the tab bar while a route preview or active navigation session is shown.
    @Published var isRouteActive = false
    @Published var isNavigating = false
    private init() {}
}
