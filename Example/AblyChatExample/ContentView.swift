import Ably
import AblyChat
import SwiftUI

private enum Environment: Equatable {
    // Set ``current`` to `.live` if you wish to connect to actual instances of the Chat client in either Prod or Sandbox environments. Setting the mode to `.mock` will use the `MockChatClient`, and therefore simulate all features of the Chat app.
    static let current: Self = .mock

    case mock
    /// - Parameters:
    ///   - key: Your Ably API key.
    ///   - clientId: A string that identifies this client.
    case live(key: String, clientId: String)

    func createChatClient() -> ChatClient {
        switch self {
        case .mock:
            return MockChatClient(
                realtime: MockRealtime(),
                clientOptions: ChatClientOptions()
            )
        case let .live(key: key, clientId: clientId):
            let realtimeOptions = ARTClientOptions()
            realtimeOptions.key = key
            realtimeOptions.clientId = clientId
            let realtime = ARTRealtime(options: realtimeOptions)

            return DefaultChatClient(realtime: realtime, clientOptions: .init())
        }
    }
}

@MainActor
struct ContentView: View {
    #if os(macOS)
        let screenWidth = NSScreen.main?.frame.width ?? 500
        let screenHeight = NSScreen.main?.frame.height ?? 500
    #else
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
    #endif

    // Can be replaced with your own room ID
    private let roomID = "DemoRoomID"

    @State private var chatClient = Environment.current.createChatClient()

    @State private var title = "Room"
    @State private var reactions: [Reaction] = []
    @State private var newMessage = ""
    @State private var typingInfo = ""
    @State private var occupancyInfo = "Connections: 0"
    @State private var statusInfo = ""

    @State private var listItems = [ListItem]()
    @State private var editingItemID: String?

    enum ListItem: Identifiable {
        case message(MessageListItem)
        case presence(PresenceListItem)

        var id: String {
            switch self {
            case let .message(item):
                item.message.id
            case let .presence(item):
                item.presence.timestamp.description
            }
        }
    }

    private func room() async throws -> Room {
        try await chatClient.rooms.get(
            roomID: roomID,
            options: .allFeaturesEnabled
        )
    }

    private var sendTitle: String {
        if newMessage.isEmpty {
            ReactionType.like.emoji
        } else if editingItemID != nil {
            "Update"
        } else {
            "Send"
        }
    }

    var body: some View {
        ZStack {
            VStack {
                Text(title)
                    .font(.headline)
                    .padding(5)
                HStack {
                    Text("")
                    Text(occupancyInfo)
                    Text(statusInfo)
                }
                .font(.footnote)
                .frame(height: 12)
                .padding(.horizontal, 8)
                List(listItems, id: \.id) { item in
                    switch item {
                    case let .message(messageItem):
                        if messageItem.message.action == .delete {
                            DeletedMessageView(item: messageItem)
                                .flip()
                        } else {
                            MessageView(
                                item: messageItem,
                                isEditing: Binding(get: {
                                    editingItemID == messageItem.message.id
                                }, set: { editing in
                                    editingItemID = editing ? messageItem.message.id : nil
                                    newMessage = editing ? messageItem.message.text : ""
                                })
                            ) {
                                Task {
                                    try await onMessageDelete(message: messageItem.message)
                                }
                            }.id(item.id)
                                .flip()
                        }
                    case let .presence(item):
                        PresenceMessageView(item: item)
                            .flip()
                    }
                }
                .flip()
                .listStyle(PlainListStyle())
                HStack {
                    TextField("Type a message...", text: $newMessage)
                        .onChange(of: newMessage) {
                            // this ensures that typing events are sent only when the message is actually changed whilst editing
                            if let index = listItems.firstIndex(where: { $0.id == editingItemID }) {
                                if case let .message(messageItem) = listItems[index] {
                                    if newMessage != messageItem.message.text {
                                        Task {
                                            try await startTyping()
                                        }
                                    }
                                }
                            } else {
                                Task {
                                    try await startTyping()
                                }
                            }
                        }
                    #if !os(tvOS)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    #endif
                    Button(action: sendButtonAction) {
                        #if os(iOS)
                            Text(sendTitle)
                                .foregroundColor(.white)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.blue)
                                .cornerRadius(15)
                        #else
                            Text(sendTitle)
                        #endif
                    }
                    if editingItemID != nil {
                        Button("", systemImage: "xmark.circle.fill") {
                            editingItemID = nil
                            newMessage = ""
                        }
                        .foregroundStyle(.red.opacity(0.8))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut, value: editingItemID)
                .padding(.horizontal, 12)
                HStack {
                    Text(typingInfo)
                        .font(.footnote)
                    Spacer()
                }
                .frame(height: 12)
                .padding(.horizontal, 14)
                .padding(.bottom, 5)
            }
            ForEach(reactions) { reaction in
                Text(reaction.emoji)
                    .font(.largeTitle)
                    .position(x: reaction.xPosition, y: reaction.yPosition)
                    .scaleEffect(reaction.scale)
                    .opacity(reaction.opacity)
                    .rotationEffect(.degrees(reaction.rotationAngle))
                    .onAppear {
                        withAnimation(.easeOut(duration: reaction.duration)) {
                            moveReactionUp(reaction: reaction)
                        }
                        // Start rotation animation
                        withAnimation(Animation.linear(duration: reaction.duration).repeatForever(autoreverses: false)) {
                            startRotation(reaction: reaction)
                        }
                    }
            }
        }
        .tryTask {
            try await setDefaultTitle()
            try await attachRoom()
            try await showMessages()
            try await showReactions()
            try await showPresence()
            try await showOccupancy()
            try await showTypings()
            try await showRoomStatus()
            await printConnectionStatusChange()
        }
    }

    func sendButtonAction() {
        if newMessage.isEmpty {
            Task {
                try await sendReaction(type: ReactionType.like.emoji)
            }
        } else if editingItemID != nil {
            Task {
                try await sendEditedMessage()
                editingItemID = nil
            }
        } else {
            Task {
                try await sendMessage()
            }
        }
    }

    func setDefaultTitle() async throws {
        title = try await "\(room().roomID)"
    }

    func attachRoom() async throws {
        try await room().attach()
    }

    func showMessages() async throws {
        let messagesSubscription = try await room().messages.subscribe()
        let previousMessages = try await messagesSubscription.getPreviousMessages(params: .init())

        for message in previousMessages.items {
            switch message.action {
            case .create, .update, .delete:
                withAnimation {
                    listItems.append(.message(.init(message: message, isSender: message.clientID == chatClient.realtime.clientId)))
                }
            }
        }

        // Continue listening for messages on a background task so this function can return
        Task {
            for await message in messagesSubscription {
                switch message.action {
                case .create:
                    withAnimation {
                        listItems.insert(
                            .message(
                                .init(
                                    message: message,
                                    isSender: message.clientID == chatClient.realtime.clientId
                                )
                            ),
                            at: 0
                        )
                    }
                case .update, .delete:
                    if let index = listItems.firstIndex(where: { $0.id == message.id }) {
                        listItems[index] = .message(
                            .init(
                                message: message,
                                isSender: message.clientID == chatClient.realtime.clientId
                            )
                        )
                    }
                }
            }
        }
    }

    func showReactions() async throws {
        let reactionSubscription = try await room().reactions.subscribe()

        // Continue listening for reactions on a background task so this function can return
        Task {
            for await reaction in reactionSubscription {
                withAnimation {
                    showReaction(reaction.displayedText)
                }
            }
        }
    }

    func showPresence() async throws {
        try await room().presence.enter(data: ["status": "📱 Online"])

        // Continue listening for new presence events on a background task so this function can return
        Task {
            for await event in try await room().presence.subscribe(events: [.enter, .leave, .update]) {
                withAnimation {
                    listItems.insert(
                        .presence(
                            .init(
                                presence: event
                            )
                        ),
                        at: 0
                    )
                }
            }
        }
    }

    func showTypings() async throws {
        let typingSubscription = try await room().typing.subscribe()
        // Continue listening for typing events on a background task so this function can return
        Task {
            for await typing in typingSubscription {
                withAnimation {
                    // Set the typing info to the list of users currently typing
                    typingInfo = typing.currentlyTyping.isEmpty ?
                        "" :
                        "Typing: \(typing.currentlyTyping.joined(separator: ", "))..."
                }
            }
        }
    }

    func showOccupancy() async throws {
        // Continue listening for occupancy events on a background task so this function can return
        let currentOccupancy = try await room().occupancy.get()
        withAnimation {
            occupancyInfo = "Connections: \(currentOccupancy.presenceMembers) (\(currentOccupancy.connections))"
        }

        Task {
            for await event in try await room().occupancy.subscribe() {
                withAnimation {
                    occupancyInfo = "Connections: \(event.presenceMembers) (\(event.connections))"
                }
            }
        }
    }

    func printConnectionStatusChange() async {
        let connectionSubsciption = chatClient.connection.onStatusChange()

        // Continue listening for connection status change on a background task so this function can return
        Task {
            for await status in connectionSubsciption {
                print("Connection status changed to: \(status.current)")
            }
        }
    }

    func showRoomStatus() async throws {
        // Continue listening for status change events on a background task so this function can return
        Task {
            for await status in try await room().onStatusChange() {
                withAnimation {
                    if status.current.isAttaching {
                        statusInfo = "\(status.current)...".capitalized
                    } else {
                        statusInfo = "\(status.current)".capitalized
                        if status.current == .attached {
                            Task {
                                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                                withAnimation {
                                    statusInfo = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func sendMessage() async throws {
        guard !newMessage.isEmpty else {
            return
        }
        _ = try await room().messages.send(params: .init(text: newMessage))
        newMessage = ""
    }

    func sendEditedMessage() async throws {
        guard !newMessage.isEmpty else {
            return
        }

        if let editingMessageItem = listItems.compactMap({ listItem -> MessageListItem? in
            if case let .message(message) = listItem, message.message.id == editingItemID {
                return message
            }
            return nil
        }).first {
            let editedMessage = editingMessageItem.message.copy(text: newMessage)
            _ = try await room().messages.update(newMessage: editedMessage, description: nil, metadata: nil)
        }

        newMessage = ""
    }

    func onMessageDelete(message: Message) async throws {
        _ = try await room().messages.delete(message: message, params: .init())
    }

    func sendReaction(type: String) async throws {
        try await room().reactions.send(params: .init(type: type))
    }

    func startTyping() async throws {
        if newMessage.isEmpty {
            try await room().typing.stop()
        } else {
            try await room().typing.start()
        }
    }
}

extension ContentView {
    struct Reaction: Identifiable {
        let id: UUID
        let emoji: String
        var xPosition: CGFloat
        var yPosition: CGFloat
        var scale: CGFloat
        var opacity: Double
        var rotationAngle: Double // New: stores the current rotation angle
        var rotationSpeed: Double // New: stores the random rotation speed
        var duration: Double
    }

    func showReaction(_ emoji: String) {
        let screenWidth = screenWidth
        let centerX = screenWidth / 2

        // Reduce the spread to 1/5th of the screen width
        let reducedSpreadRange = screenWidth / 5

        // Random x position now has a smaller range, centered around the middle of the screen
        let startXPosition = CGFloat.random(in: centerX - reducedSpreadRange ... centerX + reducedSpreadRange)
        let randomRotationSpeed = Double.random(in: 30 ... 360) // Random rotation speed
        let duration = Double.random(in: 2 ... 4)

        let newReaction = Reaction(
            id: UUID(),
            emoji: emoji,
            xPosition: startXPosition,
            yPosition: screenHeight - 100,
            scale: 1.0,
            opacity: 1.0,
            rotationAngle: 0, // Initial angle
            rotationSpeed: randomRotationSpeed,
            duration: duration
        )

        reactions.append(newReaction)

        // Remove the reaction after the animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            reactions.removeAll { $0.id == newReaction.id }
        }
    }

    func moveReactionUp(reaction: Reaction) {
        if let index = reactions.firstIndex(where: { $0.id == reaction.id }) {
            reactions[index].yPosition = 0 // Move it to the top of the screen
            reactions[index].scale = 0.5 // Shrink
            reactions[index].opacity = 0.5 // Fade out
        }
    }

    func startRotation(reaction: Reaction) {
        if let index = reactions.firstIndex(where: { $0.id == reaction.id }) {
            reactions[index].rotationAngle += 360 // Continuous rotation over time
        }
    }
}

#Preview {
    ContentView()
}

extension PresenceEventType {
    var displayedText: String {
        switch self {
        case .enter:
            "has entered the room"
        case .leave:
            "has left the room"
        case .present:
            "has presented at the room"
        case .update:
            "has updated presence"
        }
    }
}

extension View {
    nonisolated func tryTask(priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async throws -> Void) -> some View {
        task(priority: priority) {
            do {
                try await action()
            } catch {
                print("Action can't be performed: \(error)") // TODO: replace with logger (+ message to the user?)
            }
        }
    }

    func flip() -> some View {
        rotationEffect(.radians(.pi))
            .scaleEffect(x: -1, y: 1, anchor: .center)
    }
}
