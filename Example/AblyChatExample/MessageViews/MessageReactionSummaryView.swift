import AblyChat
import SwiftUI

struct MessageReactionSummaryView: View {
    let summary: MessageReactionSummary
    let currentClientID: String

    let onPickReaction: () -> Void
    let onAddReaction: (String) -> Void
    let onDeleteReaction: (String) -> Void

    @State private var selectedEmoji: String?
    @State private var showReactionMenu = false
    @State private var showAllReactionsSheet = false

    private let maxReactionsCount = 5

    var reactions: [String: MessageReactionSummary.ClientIdList] {
        summary.distinct
    }

    var body: some View {
        HStack {
            let reactions = reactions
            if !reactions.isEmpty {
                Button(action: onPickReaction) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.gray.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            ForEach(reactions.keys.sorted().prefix(maxReactionsCount), id: \.self) { emoji in
                if let item = reactions[emoji] {
                    Text("\(emoji) \(item.total)")
                        .frame(minWidth: 40, minHeight: 24)
                        .font(.system(size: 12, weight: .regular))
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(left: -2)
                        .onTapGesture {
                            selectedEmoji = emoji
                            showReactionMenu = true
                        }
                }
            }
            if !reactions.isEmpty {
                Button("•••") {
                    showAllReactionsSheet = true
                }
                .padding(left: 2)
                .lineLimit(1)
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .confirmationDialog(
            "Reaction Options",
            isPresented: $showReactionMenu,
            titleVisibility: .visible
        ) {
            Button("Show who reacted") {
                showAllReactionsSheet = true
            }
            if let emoji = selectedEmoji {
                if reactions[emoji]?.clientIds.contains(currentClientID) ?? false {
                    Button("Remove my \(emoji)", role: .destructive) {
                        onDeleteReaction(emoji)
                    }
                } else {
                    Button("React with \(emoji)") {
                        onAddReaction(emoji)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showAllReactionsSheet) {
            MessageReactionsSheet(uniqueOrDistinct: reactions)
        }
    }
}
