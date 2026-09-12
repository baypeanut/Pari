import SwiftUI

/// Authenticated Storage download; never render a historical public URL directly.
struct MomentPhoto: View {
    @Environment(\.colorScheme) private var colorScheme
    let reference: String
    @State private var photo: UIImage?

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().aspectRatio(contentMode: .fill)
            } else {
                Circle().fill(PariTheme.placeholderBackground(for: colorScheme))
                    .overlay(Image(systemName: "photo").foregroundStyle(PariTheme.secondaryText))
            }
        }
        .task(id: reference) {
            photo = nil
            let session = AuthStore.shared.sessionGeneration
            guard let data = try? await MomentStorageService.downloadMoment(reference: reference),
                  !Task.isCancelled, session == AuthStore.shared.sessionGeneration else { return }
            photo = UIImage(data: data)
        }
        .accessibilityLabel("Tasting photo")
    }
}
