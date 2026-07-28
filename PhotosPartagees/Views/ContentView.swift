import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScanViewModel()
    @State private var showSettings = false

    var body: some View {
        TabView {
            // Onglet « Moi » : le flux historique (mon visage → mes photos).
            NavigationStack {
                ScanView(viewModel: viewModel)
                    .navigationTitle("Poze")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsView(viewModel: viewModel)
                    }
            }
            .tabItem { Label("Moi", systemImage: "person.crop.square") }

            // Onglet « Amis » : scan de la pellicule par ami + revue façon Tinder.
            FriendsView()
                .tabItem { Label("Amis", systemImage: "person.2.fill") }
        }
    }
}

#Preview {
    ContentView()
}
