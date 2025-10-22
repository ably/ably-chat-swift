import SwiftUI

struct MenuButtonView: View {
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Menu {
            #if !os(tvOS)
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            #endif

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
