import SwiftUI

/// A section showing the storage error message, or nothing when there is none.
struct StorageErrorSection: View {
    let message: String?

    var body: some View {
        if let message {
            Section {
                Text(message)
            }
        }
    }
}

#Preview {
    List {
        StorageErrorSection(message: "Your last change couldn't be saved.")
    }
}
