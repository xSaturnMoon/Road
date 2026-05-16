import Foundation
import SwiftUI

class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var isUpdateAvailable = false
    @Published var latestVersion = ""
    @Published var releaseNotes = ""
    @Published var downloadURL = "https://github.com/xSaturnMoon/Bloom/releases"
    
    private let currentVersion = "1.0.0" // This should match the version in the project
    
    func checkForUpdates() {
        // Point to a raw JSON file on your GitHub
        guard let url = URL(string: "https://raw.githubusercontent.com/xSaturnMoon/Bloom/main/version.json") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = json["version"] as? String,
                  let notes = json["notes"] as? String else { return }
            
            DispatchQueue.main.async {
                if version != self.currentVersion {
                    self.latestVersion = version
                    self.releaseNotes = notes
                    self.isUpdateAvailable = true
                }
            }
        }.resume()
    }
}
