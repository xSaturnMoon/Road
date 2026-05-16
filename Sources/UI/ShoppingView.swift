import SwiftUI

struct ShoppingView: View {
    @StateObject var manager = ShoppingManager.shared
    @State private var showingAddItem = false
    @State private var showingShare = false
    @State private var newItemName = ""
    @State private var newItemQty = ""
    @State private var newItemImageURL = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background (Automatic solid color based on theme)
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Quick Stats Header
                        HStack(spacing: 15) {
                            statCard(title: "Prodotti", value: "\(manager.items.count)", icon: "bag.fill", color: .blue)
                            statCard(title: "Completati", value: "\(manager.items.filter({$0.isChecked}).count)", icon: "checkmark.circle.fill", color: .green)
                        }
                        .padding(.horizontal)
                        
                        if manager.items.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "cart.badge.plus")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 50)
                                Text("La tua lista è vuota")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(manager.items) { item in
                                    ShoppingItemCard(item: item)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Spesa")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            showingShare.toggle()
                        } label: {
                            Image(systemName: "person.2.fill")
                        }
                        
                        Button {
                            showingAddItem.toggle()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(isPresented: $showingAddItem)
            }
            .sheet(isPresented: $showingShare) {
                ShareView(isPresented: $showingShare)
            }
        }
    }
    
    func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ShoppingItemCard: View {
    var item: ShoppingItem
    @ObservedObject var manager = ShoppingManager.shared
    
    var body: some View {
        HStack(spacing: 15) {
            // Product Image
            if let urlString = item.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "cart.fill")
                        .foregroundStyle(.blue.opacity(0.5))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                
                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    manager.toggleItem(item)
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isChecked ? .green : .secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    manager.deleteItem(item)
                }
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }
}

struct AddItemView: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var qty = ""
    @State private var imageURL = ""
    @ObservedObject var manager = ShoppingManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli Prodotto") {
                    TextField("Nome prodotto", text: $name)
                    TextField("Quantità (es. 2kg, 1 pacco)", text: $qty)
                }
            }
            .navigationTitle("Aggiungi Prodotto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        manager.addItem(name: name, quantity: qty)
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct ShareView: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = ShoppingManager.shared
    @State private var friendCode = ""
    @State private var friendName = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Il tuo codice") {
                    HStack {
                        Text(manager.myCode)
                            .font(.title2.monospaced().bold())
                            .foregroundColor(.blue)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = manager.myCode
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    Text("Condividi questo codice con un amico per permettergli di vedere la tua spesa.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Aggiungi Amico") {
                    TextField("Codice Amico", text: $friendCode)
                        .autocapitalization(.allCharacters)
                    TextField("Nome Amico", text: $friendName)
                    Button("Aggiungi") {
                        manager.addFriend(code: friendCode, name: friendName)
                        friendCode = ""
                        friendName = ""
                    }
                    .disabled(friendCode.isEmpty || friendName.isEmpty)
                }
                
                Section("Amici") {
                    ForEach(manager.friends) { friend in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(friend.name)
                                    .font(.headline)
                                Text(friend.code)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if manager.observingFriend?.id == friend.id {
                                Text("In visione")
                                    .font(.caption)
                                    .padding(6)
                                    .background(.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            manager.observingFriend = friend
                        }
                    }
                }
                
                if let friend = manager.observingFriend {
                    Section("Spesa di \(friend.name)") {
                        if manager.observingItems.isEmpty {
                            Text("Nessun dato o caricamento...")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(manager.observingItems) { item in
                                HStack {
                                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(item.isChecked ? .green : .secondary)
                                    Text(item.name)
                                    Spacer()
                                    Text(item.quantity)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Button("Smetti di osservare", role: .destructive) {
                            manager.observingFriend = nil
                            manager.observingItems = []
                        }
                    }
                }
            }
            .navigationTitle("Condivisione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { isPresented = false }
                }
            }
        }
    }
}
