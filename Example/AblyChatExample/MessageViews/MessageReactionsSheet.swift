import AblyChat
import SwiftUI

struct MessageReactionsSheet: View {
    struct ReactionItem: Identifiable, Equatable {
        let emoji: String
        let author: String
        var count: Int = 1

        var id: String {
            "\(author)-\(emoji)"
        }
    }

    private var reactions: [String: ReactionItem] = [:]

    @Environment(\.dismiss)
    private var dismiss

    init(uniqueOrDistinct: [String: MessageReactionSummary.ClientIdList]) {
        for (emoji, clientList) in uniqueOrDistinct {
            for clientId in clientList.clientIds {
                let key = "\(clientId)-\(emoji)"
                reactions[key] = ReactionItem(
                    emoji: emoji,
                    author: clientId,
                    count: 1
                )
            }
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .frame(width: 40, height: 6)
                    .foregroundColor(Color.secondary.opacity(0.3))
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                Text("All Reactions")
                    .font(.headline)
                    .padding(.bottom, 12)

                ScrollView {
                    let columns = [
                        GridItem(.adaptive(minimum: 60, maximum: 120), spacing: 5),
                    ]
                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(reactions.values.sorted { r1, r2 in
                            if r1.author == r2.author {
                                r1.emoji < r2.emoji
                            } else {
                                r1.author < r2.author
                            }
                        }, id: \.id) { item in
                            VStack(spacing: 4) {
                                Text(item.emoji)
                                    .font(.system(size: 24))
                                if item.count > 1 {
                                    Text("\(item.author) (\(item.count))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                } else {
                                    Text(item.author)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            #if os(iOS)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemBackground).opacity(0.7))
                                )
                            #elseif os(macOS)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.7))
                                )
                            #endif
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button("Dismiss", role: .cancel) {
                    dismiss()
                }
                .font(.title3)
                .padding(24)
            }
            .frame(maxWidth: .infinity)
            #if os(iOS)
                .background(
                    BlurView(style: .systemUltraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
            #elseif os(macOS)
                .background(
                    BlurView(material: .hudWindow, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
            #endif
                .padding(.horizontal, 0)
                .padding(.bottom, 0)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .presentationBackground(.clear)
        .transition(.move(edge: .bottom))
    }
}
