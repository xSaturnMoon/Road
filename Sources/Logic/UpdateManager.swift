import Foundation
import SwiftUI

class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var isUpdateAvailable = false
    @Published var latestVersion = ""
    @Published var releaseNotes = ""
    @Published var isChecking = false
    @Published var showUpToDateAlert = false
    @Published var downloadURL = "itms-services://?action=download-manifest&url=https://raw.githubusercontent.com/xSaturnMoon/Bloom/main/manifest.plist"
    
    @Published var currentVersion = "1.0.9"
    
    func checkForUpdates(manual: Bool = false) {
        if isChecking { return }
        isChecking = true
        
        let cacheBuster = UUID().uuidString
        guard let url = URL(string: "https://raw.githubusercontent.com/xSaturnMoon/Bloom/main/version.json?v=\(cacheBuster)") else { 
            isChecking = false
            return 
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.isChecking = false
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let version = json["version"] as? String,
                      let notes = json["notes"] as? String else { return }
                
                if version != self.currentVersion {
                    self.latestVersion = version
                    self.releaseNotes = notes
                    self.isUpdateAvailable = true
                } else if manual {
                    self.showUpToDateAlert = true
                }
            }
        }.resume()
    }
}
