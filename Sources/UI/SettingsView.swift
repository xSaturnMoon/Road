import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Schermata Impostazioni vuota")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .padding(.top, 100)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Impostazioni")
        }
    }
}
