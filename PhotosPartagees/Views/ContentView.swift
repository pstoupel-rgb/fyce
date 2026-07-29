import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var scanViewModel = ScanViewModel()
    @StateObject private var friendStore = FriendStore()
    @State private var showSettings = false

    var body: some View {
        TabView {
            // Onglet « Accueil » : la vitrine — groupes, events et amis configurables.
            HomeView()
                .environmentObject(friendStore)
                .tabItem { Label("Accueil", systemImage: "square.grid.2x2") }

            // Onglet « Moi » : le flux historique (mon visage → mes photos).
            NavigationStack {
                ScanView(viewModel: scanViewModel)
                    .navigationTitle("Moi")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsView(viewModel: scanViewModel, auth: auth)
                    }
            }
            .tabItem { Label("Moi", systemImage: "person.crop.circle") }
        }
        .tint(Theme.txt)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView().environmentObject(AuthService())
}
