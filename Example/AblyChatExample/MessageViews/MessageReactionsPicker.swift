import AblyChat
import SwiftUI

struct MessageReactionsPicker: View {
    let onReactionSelected: (String) -> Void
    private let emojies = Emoji.all()

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .frame(width: 40, height: 6)
                    .foregroundColor(Color.secondary.opacity(0.3))
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                Text("Emoji Picker")
                    .font(.headline)
                    .padding(.bottom, 12)

                ScrollView {
                    let columns = [
                        GridItem(.adaptive(minimum: 60, maximum: 120), spacing: 5),
                    ]
                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(emojies, id: \.self) { emoji in
                            VStack(spacing: 4) {
                                Text(emoji)
                                    .font(.system(size: 32))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .onTapGesture {
                                onReactionSelected(emoji)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
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
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)),
                )
            #elseif os(macOS)
                .background(
                    BlurView(material: .hudWindow, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)),
                )
            #endif
                .padding(.horizontal, 0)
                .padding(.bottom, 0)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .presentationBackground(.clear)
        .presentationDetents([.fraction(0.5)])
        .padding(10)
        .transition(.move(edge: .bottom))
    }
}
