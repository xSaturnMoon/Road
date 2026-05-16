import SwiftUI

struct AppsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Schermata Apps vuota")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .padding(.top, 100)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Le mie App")
        }
    }
}
