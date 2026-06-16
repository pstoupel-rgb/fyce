import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScanViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScanView(viewModel: viewModel)
                .navigationTitle("PhotosPartagees")
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
    }
}

#Preview {
    ContentView()
}
