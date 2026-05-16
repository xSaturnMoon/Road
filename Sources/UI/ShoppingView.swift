import SwiftUI

struct ShoppingView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Schermata Spesa vuota")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .padding(.top, 100)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Spesa")
        }
    }
}
