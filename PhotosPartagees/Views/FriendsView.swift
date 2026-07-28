import SwiftUI

/// Liste des amis. Sélectionner un ami lance le scan de la pellicule et ouvre
/// la revue « façon Tinder ». Un bouton + permet d'ajouter un ami depuis une photo.
struct FriendsView: View {
    @StateObject private var store = FriendStore()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if store.friends.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Amis")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Ajouter un ami")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddFriendView(store: store)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(store.friends) { friend in
                NavigationLink {
                    FriendReviewView(friend: friend, store: store)
                } label: {
                    row(friend)
                }
            }
            .onDelete { indexSet in
                indexSet.map { store.friends[$0] }.forEach(store.remove)
            }
        }
        .listStyle(.plain)
    }

    private func row(_ friend: Friend) -> some View {
        HStack(spacing: 14) {
            Group {
                if let thumb = friend.thumbnail {
                    Image(uiImage: thumb).resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().scaledToFit().foregroundStyle(.secondary)
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name).font(.body.weight(.semibold))
                Text("Scanner mes photos").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 56)).foregroundStyle(.secondary)
            Text("Ajoute tes amis").font(.title3.bold())
            Text("Choisis une photo d'un ami. L'app retrouvera ensuite toutes\ntes photos de lui, à trier d'un swipe.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showAdd = true } label: {
                Label("Ajouter un ami", systemImage: "plus")
                    .font(.headline).padding(.horizontal, 22).padding(.vertical, 12)
                    .background(LinearGradient(
                        colors: [Color(red: 0.49, green: 0.36, blue: 1),
                                 Color(red: 0.13, green: 0.83, blue: 0.93)],
                        startPoint: .leading, endPoint: .trailing),
                        in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)
        }
        .padding()
    }
}
