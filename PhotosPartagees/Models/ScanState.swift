import Foundation

/// État global du flux scan → match → upload, piloté par le ViewModel.
enum ScanState: Equatable {
    case idle
    case needsReferenceFace
    case scanning(processed: Int, total: Int)
    case finished(matches: Int)
    case error(String)
}
