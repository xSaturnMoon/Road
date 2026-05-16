import SwiftUI

struct InstallView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Schermata Installazione vuota")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .padding(.top, 100)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Installa")
        }
    }
}
