import SwiftUI

struct ShoppingView: View {
    @StateObject var manager = ShoppingManager.shared
    @State private var showingAddItem = false
    @State private var showingShare = false
    @State private var showingFriendsLists = false
    @State private var newItemName = ""
    @State private var newItemQty = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background (Automatic solid color based on theme)
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                List {
                    Section {
                        // Quick Stats Header
                        HStack(spacing: 15) {
                            statCard(title: "Prodotti", value: "\(manager.items.count)", icon: "bag.fill", color: .blue)
                            statCard(title: "Completati", value: "\(manager.items.filter({$0.isChecked}).count)", icon: "checkmark.circle.fill", color: .green)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal)

                    if manager.items.isEmpty {
                        Section {
                            VStack(spacing: 20) {
                                Image(systemName: "cart.badge.plus")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 50)
                                Text("La tua lista è vuota")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(manager.items) { item in
                            ShoppingItemCard(item: item)
                                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing) {
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
                    
                    // Spacer at the bottom
                    Section {
                        Spacer(minLength: 120)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Spesa")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        Button {
                            showingFriendsLists.toggle()
                        } label: {
                            Image(systemName: "folder.badge.person.crop")
                        }
                        
                        Button {
                            showingShare.toggle()
                        } label: {
                            Image(systemName: "person.badge.plus")
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
            .sheet(isPresented: $showingFriendsLists) {
                FriendsListView(isPresented: $showingFriendsLists)
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
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct AddItemView: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var qty = ""
    @ObservedObject var manager = ShoppingManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli Prodotto") {
                    TextField("Nome prodotto", text: $name)
                    TextField("Quantità", text: $qty)
                        .keyboardType(.decimalPad)
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

struct FriendsListView: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = ShoppingManager.shared
    @State private var editingFriend: Friend?
    @State private var newName = ""
    
    var body: some View {
        NavigationStack {
            List {
                if manager.friends.isEmpty {
                    Section {
                        Text("Non hai ancora aggiunto amici.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(manager.friends) { friend in
                        NavigationLink {
                            FriendDetailView(friend: friend)
                        } label: {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text(friend.name)
                                        .font(.headline)
                                    Text(friend.code)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                manager.friends.removeAll(where: { $0.id == friend.id })
                                manager.saveFriends()
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            
                            Button {
                                editingFriend = friend
                                newName = friend.name
                            } label: {
                                Label("Rinomina", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Liste Amici")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { isPresented = false }
                }
            }
            .alert("Rinomina Amico", isPresented: Binding(get: { editingFriend != nil }, set: { if !$0 { editingFriend = nil } })) {
                TextField("Nuovo nome", text: $newName)
                Button("Annulla", role: .cancel) { editingFriend = nil }
                Button("Salva") {
                    if let friend = editingFriend, !newName.isEmpty {
                        if let index = manager.friends.firstIndex(where: { $0.id == friend.id }) {
                            manager.friends[index].name = newName
                            manager.saveFriends()
                        }
                    }
                    editingFriend = nil
                }
            }
        }
    }
}

struct FriendDetailView: View {
    let friend: Friend
    @ObservedObject var manager = ShoppingManager.shared
    
    var body: some View {
        List {
            if manager.observingItems.isEmpty {
                Text("In caricamento o lista vuota...")
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
        }
        .navigationTitle(friend.name)
        .onAppear {
            manager.observingFriend = friend
        }
        .onDisappear {
            manager.observingFriend = nil
            manager.observingItems = []
        }
    }
}
