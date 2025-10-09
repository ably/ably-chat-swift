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

    @MainActor
    func createChatClient() -> any ChatClientProtocol {
        switch self {
        case .mock:
            return MockChatClient(
                clientOptions: ChatClientOptions(),
            )
        case let .live(key: key, clientId: clientId):
            let realtimeOptions = ARTClientOptions()
            realtimeOptions.key = key
            realtimeOptions.clientId = clientId
            let realtime = ARTRealtime(options: realtimeOptions)

            return ChatClient(realtime: realtime, clientOptions: .init())
        }
    }
}

struct ContentView: View {
    #if os(macOS)
        let screenWidth = NSScreen.main?.frame.width ?? 500
        let screenHeight = NSScreen.main?.frame.height ?? 500
    #else
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
    #endif

    // Can be replaced with your own room name
    private let roomName = "DemoRoom"

    @State private var chatClient = Environment.current.createChatClient()

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
                item.message.serial
            case let .presence(item):
                item.presence.member.updatedAt.description
            }
        }
    }

    func listItemWithMessageSerial(_ serial: String) -> MessageListItem? {
        listItems.compactMap { listItem -> MessageListItem? in
            if case let .message(messageItem) = listItem, messageItem.message.serial == serial {
                return messageItem
            }
            return nil
        }.first
    }

    private func room() async throws -> any Room {
        try await chatClient.rooms.get(name: roomName, options: .init(occupancy: .init(enableEvents: true)))
    }

    private var sendTitle: String {
        if newMessage.isEmpty {
            ReactionName.like.emoji
        } else if editingItemID != nil {
            "Update"
        } else {
            "Send"
        }
    }

    private var currentClientID: String {
        chatClient.clientID
    }

    var body: some View {
        ZStack {
            VStack {
                Text("In \(roomName) as \(currentClientID)")
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
                        if messageItem.message.action == .messageDelete {
                            DeletedMessageView(item: messageItem)
                                .flip()
                        } else {
                            MessageView(
                                currentClientID: currentClientID,
                                item: messageItem,
                                isEditing: Binding(get: {
                                    editingItemID == messageItem.message.serial
                                }, set: { editing in
                                    editingItemID = editing ? messageItem.message.serial : nil
                                    newMessage = editing ? messageItem.message.text : ""
                                }),
                                onDeleteMessage: {
                                    deleteMessage(messageItem.message)
                                },
                                onAddReaction: { reaction in
                                    addMessageReaction(reaction, messageSerial: messageItem.message.serial)
                                },
                                onDeleteReaction: { reaction in
                                    deleteMessageReaction(reaction, messageSerial: messageItem.message.serial)
                                },
                            ).id(item.id)
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
                                        startTyping()
                                    }
                                }
                            } else {
                                startTyping()
                            }
                        }
                    #if !os(tvOS)
                        .textFieldStyle(.roundedBorder)
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
        .task {
            do {
                let room = try await room()

                printConnectionStatusChange(duration: 30) // stops printing after 30 seconds
                subscribeToReactions(room: room)
                subscribeToRoomStatus(room: room)
                subscribeToTypingEvents(room: room)
                subscribeToOccupancy(room: room)
                subscribeToPresence(room: room)
                subscribeToMessageReactions(room: room)

                try await room.attach()
                try await showOccupancy(room: room)
                try await room.presence.enter(withData: ["status": "📱 Online"])

                try await showMessages(room: room)
            } catch {
                print("Failed to initialize room: \(error)") // TODO: replace with logger (+ message to the user?)
            }
        }
    }

    func sendButtonAction() {
        if newMessage.isEmpty {
            sendRoomReaction(ReactionName.like.emoji)
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

    func showMessages(room: any Room) async throws {
        let subscription = room.messages.subscribe { event in
            let message = event.message
            switch event.type {
            case .created:
                withAnimation {
                    listItems.insert(
                        .message(
                            .init(
                                message: message,
                                isSender: message.clientID == currentClientID,
                            ),
                        ),
                        at: 0,
                    )
                }
            case .updated, .deleted:
                if let index = listItems.firstIndex(where: { $0.id == message.serial }) {
                    listItems[index] = .message(
                        .init(
                            message: message,
                            isSender: message.clientID == currentClientID,
                        ),
                    )
                }
            }
        }
        let previousMessages = try await subscription.historyBeforeSubscribe(withParams: .init())

        for message in previousMessages.items {
            switch message.action {
            case .messageCreate, .messageUpdate, .messageDelete:
                withAnimation {
                    listItems.append(.message(.init(message: message, isSender: message.clientID == currentClientID)))
                }
            }
        }
    }

    func subscribeToReactions(room: any Room) {
        room.reactions.subscribe { event in
            withAnimation {
                showReaction(event.reaction.displayedText)
            }
        }
    }

    func subscribeToMessageReactions(room: any Room) {
        room.messages.reactions.subscribe { summaryEvent in
            do {
                try withAnimation {
                    if let reactedMessageItem = listItemWithMessageSerial(summaryEvent.messageSerial) {
                        if let index = listItems.firstIndex(where: { $0.id == reactedMessageItem.message.serial }) {
                            listItems[index] = try .message(
                                .init(
                                    message: reactedMessageItem.message.with(summaryEvent),
                                    isSender: reactedMessageItem.message.clientID == currentClientID,
                                ),
                            )
                        }
                    }
                }
            } catch {
                print("Can't update message with reaction: \(error)")
            }
        }
    }

    func subscribeToPresence(room: any Room) {
        room.presence.subscribe(events: [.enter, .leave, .update]) { event in
            withAnimation {
                listItems.insert(
                    .presence(
                        .init(
                            presence: event,
                        ),
                    ),
                    at: 0,
                )
            }
        }
    }

    func subscribeToTypingEvents(room: any Room) {
        room.typing.subscribe { typing in
            withAnimation {
                // Set the typing info to the list of users currently typing
                let reset = typing.currentlyTyping.isEmpty || typing.currentlyTyping.count == 1 && typing.change.type == .stopped
                typingInfo = reset ? "" : "Typing: \(typing.currentlyTyping.joined(separator: ", "))..."
            }
        }
    }

    func showOccupancy(room: any Room) async throws {
        let occupancy = try await room.occupancy.get()
        occupancyInfo = "Connections: \(occupancy.presenceMembers) (\(occupancy.connections))"
    }

    func subscribeToOccupancy(room: any Room) {
        room.occupancy.subscribe { event in
            withAnimation {
                occupancyInfo = "Connections: \(event.occupancy.presenceMembers) (\(event.occupancy.connections))"
            }
        }
    }

    func printConnectionStatusChange(duration: TimeInterval) {
        let subscription = chatClient.connection.onStatusChange { status in
            print("Connection status changed to: `\(status.current)` from `\(status.previous)`")
        }
        after(duration) {
            subscription.off()
            print("Unsubscribed from connection status changes.")
        }
    }

    func subscribeToRoomStatus(room: any Room) {
        room.onStatusChange { status in
            withAnimation {
                if status.current.isAttaching {
                    statusInfo = "\(status.current)...".capitalized
                } else {
                    statusInfo = "\(status.current)".capitalized
                    if status.current.isAttached {
                        after(1) {
                            withAnimation {
                                statusInfo = ""
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
        _ = try await room().messages.send(withParams: .init(text: newMessage))
        newMessage = ""
    }

    func sendEditedMessage() async throws {
        guard !newMessage.isEmpty else {
            return
        }

        if let editingMessageItem = listItems.compactMap({ listItem -> MessageListItem? in
            if case let .message(message) = listItem, message.message.serial == editingItemID {
                return message
            }
            return nil
        }).first {
            let editedMessage = editingMessageItem.message.copy(text: newMessage)
            _ = try await room().messages.update(newMessage: editedMessage, description: nil, metadata: nil)
        }

        newMessage = ""
    }

    func deleteMessage(_ message: Message) {
        Task {
            _ = try await room().messages.delete(message: message, params: .init())
        }
    }

    func sendRoomReaction(_ reaction: String) {
        Task {
            try await room().reactions.send(withParams: .init(name: reaction))
        }
    }

    func addMessageReaction(_ reaction: String, messageSerial: String) {
        Task {
            try await room().messages.reactions.send(forMessageWithSerial: messageSerial, params: .init(name: reaction, type: .distinct))
        }
    }

    func deleteMessageReaction(_ reaction: String, messageSerial: String) {
        Task {
            try await room().messages.reactions.delete(forMessageWithSerial: messageSerial, params: .init(name: reaction, type: .distinct))
        }
    }

    func startTyping() {
        Task {
            if newMessage.isEmpty {
                try await room().typing.stop()
            } else {
                try await room().typing.keystroke()
            }
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
            duration: duration,
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
    func flip() -> some View {
        rotationEffect(.radians(.pi))
            .scaleEffect(x: -1, y: 1, anchor: .center)
    }
}
