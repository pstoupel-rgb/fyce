import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScanViewModel()

    var body: some View {
        NavigationStack {
            ScanView(viewModel: viewModel)
                .navigationTitle("PhotosPartagees")
        }
    }
}

#Preview {
    ContentView()
}
