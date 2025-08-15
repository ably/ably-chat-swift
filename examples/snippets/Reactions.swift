//
//  Reactions.swift
//  Ably Chat Swift SDK Examples
//
//  Reactions implementation including message reactions, room-level reactions, and reaction aggregation
//  This example demonstrates comprehensive reaction handling with Ably Chat
//

import AblyChat
import Ably
import Foundation

// MARK: - Message Reactions

/// Comprehensive examples for handling message reactions
class MessageReactionHandler {
    private let room: Room
    
    init(room: Room) {
        self.room = room
    }
    
    // MARK: - Adding Message Reactions
    
    /// Add a simple reaction to a message
    /// - Parameters:
    ///   - messageSerial: Serial of the message to react to
    ///   - reactionName: Name of the reaction (e.g., "👍", "❤️", "like")
    func addSimpleReaction(to messageSerial: String, reactionName: String) async throws {
        let params = SendMessageReactionParams(name: reactionName)
        try await room.messages.reactions.send(to: messageSerial, params: params)
        
        print("✅ Added reaction '\(reactionName)' to message \(messageSerial)")
    }
    
    /// Add reaction with specific type
    /// - Parameters:
    ///   - messageSerial: Message serial
    ///   - reactionName: Reaction name
    ///   - reactionType: Type of reaction (distinct, multiple, unique)
    func addReactionWithType(
        to messageSerial: String,
        reactionName: String,
        reactionType: MessageReactionType
    ) async throws {
        let params = SendMessageReactionParams(
            name: reactionName,
            type: reactionType
        )
        
        try await room.messages.reactions.send(to: messageSerial, params: params)
        
        print("✅ Added \(reactionType) reaction '\(reactionName)' to message \(messageSerial)")
    }
    
    /// Add multiple count reaction (for MessageReactionType.multiple)
    /// - Parameters:
    ///   - messageSerial: Message serial
    ///   - reactionName: Reaction name
    ///   - count: Count of reactions to add
    func addMultipleReaction(
        to messageSerial: String,
        reactionName: String,
        count: Int
    ) async throws {
        let params = SendMessageReactionParams(
            name: reactionName,
            type: .multiple,
            count: count
        )
        
        try await room.messages.reactions.send(to: messageSerial, params: params)
        
        print("✅ Added \(count)x '\(reactionName)' reactions to message \(messageSerial)")
    }
    
    /// Add distinct reaction (one per user)
    /// - Parameters:
    ///   - messageSerial: Message serial
    ///   - reactionName: Reaction name
    func addDistinctReaction(to messageSerial: String, reactionName: String) async throws {
        let params = SendMessageReactionParams(
            name: reactionName,
            type: .distinct
        )
        
        try await room.messages.reactions.send(to: messageSerial, params: params)
        
        print("✅ Added distinct reaction '\(reactionName)' to message \(messageSerial)")
    }
    
    /// Add unique reaction (replaces existing reaction from same user)
    /// - Parameters:
    ///   - messageSerial: Message serial
    ///   - reactionName: Reaction name
    func addUniqueReaction(to messageSerial: String, reactionName: String) async throws {
        let params = SendMessageReactionParams(
            name: reactionName,
            type: .unique
        )
        
        try await room.messages.reactions.send(to: messageSerial, params: params)
        
        print("✅ Added unique reaction '\(reactionName)' to message \(messageSerial)")
    }
    
    // MARK: - Removing Message Reactions
    
    /// Remove a reaction from a message
    /// - Parameters:
    ///   - messageSerial: Message serial
    ///   - reactionName: Reaction name to remove
    ///   - reactionType: Type of reaction
    func removeReaction(
        from messageSerial: String,
        reactionName: String,
        reactionType: MessageReactionType
    ) async throws {
        let params = DeleteMessageReactionParams(
            name: reactionName,
            type: reactionType
        )
        
        try await room.messages.reactions.delete(from: messageSerial, params: params)
        
        print("🗑️ Removed reaction '\(reactionName)' from message \(messageSerial)")
    }
    
    /// Remove unique reaction (no name needed)
    /// - Parameter messageSerial: Message serial
    func removeUniqueReaction(from messageSerial: String) async throws {
        let params = DeleteMessageReactionParams(type: .unique)
        
        try await room.messages.reactions.delete(from: messageSerial, params: params)
        
        print("🗑️ Removed unique reaction from message \(messageSerial)")
    }
    
    // MARK: - Reaction Subscriptions
    
    /// Subscribe to reaction summary events (aggregated counts)
    /// - Parameter onSummary: Callback for summary events
    /// - Returns: Subscription for unsubscribing
    @discardableResult
    func subscribeToReactionSummaries(
        onSummary: @escaping (MessageReactionSummaryEvent) -> Void
    ) -> SubscriptionProtocol {
        let subscription = room.messages.reactions.subscribe { summaryEvent in
            print("📊 Reaction summary updated for message \(summaryEvent.summary.messageSerial)")
            print("   Summary: \(summaryEvent.summary.values)")
            
            onSummary(summaryEvent)
        }
        
        return subscription
    }
    
    /// Subscribe to raw reaction events (individual reactions)
    /// - Parameter onRawReaction: Callback for raw reaction events
    /// - Returns: Subscription for unsubscribing
    @discardableResult
    func subscribeToRawReactions(
        onRawReaction: @escaping (MessageReactionRawEvent) -> Void
    ) -> SubscriptionProtocol {
        let subscription = room.messages.reactions.subscribeRaw { rawEvent in
            print("⚡ Raw reaction event:")
            print("   Type: \(rawEvent.type)")
            print("   Message: \(rawEvent.reaction.messageSerial)")
            print("   Reaction: \(rawEvent.reaction.name)")
            print("   Client: \(rawEvent.reaction.clientID)")
            
            onRawReaction(rawEvent)
        }
        
        return subscription
    }
    
    /// Subscribe using AsyncSequence for summaries
    /// - Returns: AsyncSequence for reaction summaries
    func subscribeToSummariesAsync() -> SubscriptionAsyncSequence<MessageReactionSummaryEvent> {
        let subscription = room.messages.reactions.subscribe()
        
        // Process events in background
        Task {
            for await summaryEvent in subscription {
                await MainActor.run {
                    print("📊 Async summary: \(summaryEvent.summary.messageSerial)")
                }
            }
        }
        
        return subscription
    }
    
    /// Subscribe using AsyncSequence for raw reactions
    /// - Returns: AsyncSequence for raw reactions
    func subscribeToRawReactionsAsync() -> SubscriptionAsyncSequence<MessageReactionRawEvent> {
        let subscription = room.messages.reactions.subscribeRaw()
        
        // Process events in background
        Task {
            for await rawEvent in subscription {
                await MainActor.run {
                    print("⚡ Async raw reaction: \(rawEvent.reaction.name) on \(rawEvent.reaction.messageSerial)")
                }
            }
        }
        
        return subscription
    }
}

// MARK: - Room Reactions

/// Examples for handling room-level reactions
class RoomReactionHandler {
    private let room: Room
    
    init(room: Room) {
        self.room = room
    }
    
    // MARK: - Sending Room Reactions
    
    /// Send a simple room reaction
    /// - Parameter reactionName: Name of the reaction
    func sendSimpleRoomReaction(reactionName: String) async throws {
        let params = SendReactionParams(name: reactionName)
        try await room.reactions.send(params: params)
        
        print("🎉 Sent room reaction: \(reactionName)")
    }
    
    /// Send room reaction with metadata
    /// - Parameters:
    ///   - reactionName: Reaction name
    ///   - metadata: Additional metadata
    func sendRoomReactionWithMetadata(
        reactionName: String,
        metadata: [String: Any]
    ) async throws {
        let params = SendReactionParams(
            name: reactionName,
            metadata: metadata
        )
        
        try await room.reactions.send(params: params)
        
        print("🎉 Sent room reaction '\(reactionName)' with metadata: \(metadata)")
    }
    
    /// Send room reaction with headers (for filtering)
    /// - Parameters:
    ///   - reactionName: Reaction name
    ///   - headers: Headers for filtering
    func sendRoomReactionWithHeaders(
        reactionName: String,
        headers: [String: String]
    ) async throws {
        let params = SendReactionParams(
            name: reactionName,
            headers: headers
        )
        
        try await room.reactions.send(params: params)
        
        print("🎉 Sent room reaction '\(reactionName)' with headers: \(headers)")
    }
    
    /// Send rich room reaction with metadata and headers
    /// - Parameters:
    ///   - reactionName: Reaction name
    ///   - metadata: Rich metadata
    ///   - headers: Filter headers
    func sendRichRoomReaction(
        reactionName: String,
        metadata: [String: Any],
        headers: [String: String]
    ) async throws {
        let params = SendReactionParams(
            name: reactionName,
            metadata: metadata,
            headers: headers
        )
        
        try await room.reactions.send(params: params)
        
        print("🎉 Sent rich room reaction '\(reactionName)'")
    }
    
    // MARK: - Room Reaction Subscriptions
    
    /// Subscribe to room reactions
    /// - Parameter onReaction: Callback for room reactions
    /// - Returns: Subscription for unsubscribing
    @discardableResult
    func subscribeToRoomReactions(
        onReaction: @escaping (RoomReactionEvent) -> Void
    ) -> SubscriptionProtocol {
        let subscription = room.reactions.subscribe { reactionEvent in
            print("🎉 Room reaction received:")
            print("   Type: \(reactionEvent.type)")
            print("   Reaction: \(reactionEvent.reaction.name)")
            print("   From: \(reactionEvent.reaction.clientID)")
            print("   Timestamp: \(reactionEvent.reaction.timestamp)")
            
            onReaction(reactionEvent)
        }
        
        return subscription
    }
    
    /// Subscribe using AsyncSequence
    /// - Returns: AsyncSequence for room reactions
    func subscribeToRoomReactionsAsync() -> SubscriptionAsyncSequence<RoomReactionEvent> {
        let subscription = room.reactions.subscribe()
        
        // Process events in background
        Task {
            for await reactionEvent in subscription {
                await MainActor.run {
                    print("🎉 Async room reaction: \(reactionEvent.reaction.name) from \(reactionEvent.reaction.clientID)")
                }
            }
        }
        
        return subscription
    }
    
    /// Subscribe with custom buffering policy
    /// - Parameter bufferingPolicy: Buffering policy
    /// - Returns: AsyncSequence with buffering
    func subscribeWithBuffering(
        bufferingPolicy: BufferingPolicy
    ) -> SubscriptionAsyncSequence<RoomReactionEvent> {
        return room.reactions.subscribe(bufferingPolicy: bufferingPolicy)
    }
}

// MARK: - Reaction Aggregation

/// Helper for aggregating and managing reaction data
class ReactionAggregator {
    
    /// Aggregate reaction summary into readable format
    /// - Parameter summary: Message reaction summary
    /// - Returns: Formatted reaction data
    static func formatReactionSummary(_ summary: MessageReactionSummary) -> [ReactionCount] {
        var reactions: [ReactionCount] = []
        
        for (reactionName, data) in summary.values {
            if let reactionData = data as? [String: Any],
               let count = reactionData["count"] as? Int {
                
                let userIds = reactionData["clientIds"] as? [String] ?? []
                
                reactions.append(ReactionCount(
                    name: reactionName,
                    count: count,
                    userIds: userIds
                ))
            }
        }
        
        return reactions.sorted { $0.count > $1.count }
    }
    
    /// Get top reactions from summary
    /// - Parameters:
    ///   - summary: Reaction summary
    ///   - limit: Maximum reactions to return
    /// - Returns: Top reactions by count
    static func getTopReactions(
        from summary: MessageReactionSummary,
        limit: Int = 5
    ) -> [ReactionCount] {
        let formatted = formatReactionSummary(summary)
        return Array(formatted.prefix(limit))
    }
    
    /// Check if user has reacted to message
    /// - Parameters:
    ///   - summary: Reaction summary
    ///   - clientId: User's client ID
    ///   - reactionName: Specific reaction to check (optional)
    /// - Returns: True if user has reacted
    static func hasUserReacted(
        summary: MessageReactionSummary,
        clientId: String,
        reactionName: String? = nil
    ) -> Bool {
        for (name, data) in summary.values {
            if let reactionName = reactionName, name != reactionName {
                continue
            }
            
            if let reactionData = data as? [String: Any],
               let userIds = reactionData["clientIds"] as? [String] {
                if userIds.contains(clientId) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Get user's reactions to a message
    /// - Parameters:
    ///   - summary: Reaction summary
    ///   - clientId: User's client ID
    /// - Returns: Array of reaction names the user has made
    static func getUserReactions(
        summary: MessageReactionSummary,
        clientId: String
    ) -> [String] {
        var userReactions: [String] = []
        
        for (name, data) in summary.values {
            if let reactionData = data as? [String: Any],
               let userIds = reactionData["clientIds"] as? [String],
               userIds.contains(clientId) {
                userReactions.append(name)
            }
        }
        
        return userReactions
    }
}

// MARK: - Models

/// Represents a reaction count with users
struct ReactionCount {
    let name: String
    let count: Int
    let userIds: [String]
    
    var emoji: String {
        return name
    }
    
    var displayText: String {
        return "\(name) \(count)"
    }
}

// MARK: - Predefined Reactions

/// Common emoji reactions for easy use
enum CommonReactions: String, CaseIterable {
    case thumbsUp = "👍"
    case thumbsDown = "👎"
    case heart = "❤️"
    case laugh = "😂"
    case wow = "😮"
    case sad = "😢"
    case angry = "😠"
    case fire = "🔥"
    case partyPopper = "🎉"
    case clap = "👏"
    
    var description: String {
        switch self {
        case .thumbsUp: return "Like"
        case .thumbsDown: return "Dislike"
        case .heart: return "Love"
        case .laugh: return "Laugh"
        case .wow: return "Wow"
        case .sad: return "Sad"
        case .angry: return "Angry"
        case .fire: return "Fire"
        case .partyPopper: return "Celebrate"
        case .clap: return "Applause"
        }
    }
}

// MARK: - Reaction UI Manager

/// Manager for handling reactions in UI contexts
@MainActor
class ReactionUIManager: ObservableObject {
    @Published var messageReactions: [String: [ReactionCount]] = [:]
    @Published var recentRoomReactions: [RoomReaction] = []
    
    private let messageReactionHandler: MessageReactionHandler
    private let roomReactionHandler: RoomReactionHandler
    
    private var messageSubscription: SubscriptionProtocol?
    private var roomSubscription: SubscriptionProtocol?
    
    init(room: Room) {
        self.messageReactionHandler = MessageReactionHandler(room: room)
        self.roomReactionHandler = RoomReactionHandler(room: room)
    }
    
    /// Start monitoring reactions
    func startMonitoring() {
        setupMessageReactionSubscription()
        setupRoomReactionSubscription()
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        messageSubscription?.unsubscribe()
        roomSubscription?.unsubscribe()
        messageSubscription = nil
        roomSubscription = nil
    }
    
    /// Add reaction to message
    /// - Parameters:
    ///   - messageSerial: Message serial
    ///   - reaction: Reaction to add
    func addMessageReaction(to messageSerial: String, reaction: CommonReactions) async throws {
        try await messageReactionHandler.addDistinctReaction(
            to: messageSerial,
            reactionName: reaction.rawValue
        )
    }
    
    /// Remove reaction from message
    /// - Parameters:
    ///   - messageSerial: Message serial
    ///   - reaction: Reaction to remove
    func removeMessageReaction(from messageSerial: String, reaction: CommonReactions) async throws {
        try await messageReactionHandler.removeReaction(
            from: messageSerial,
            reactionName: reaction.rawValue,
            reactionType: .distinct
        )
    }
    
    /// Send room reaction
    /// - Parameter reaction: Room reaction to send
    func sendRoomReaction(_ reaction: CommonReactions) async throws {
        try await roomReactionHandler.sendRoomReactionWithMetadata(
            reactionName: reaction.rawValue,
            metadata: [
                "description": reaction.description,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    /// Get reactions for a specific message
    /// - Parameter messageSerial: Message serial
    /// - Returns: Reaction counts for the message
    func getReactionsForMessage(_ messageSerial: String) -> [ReactionCount] {
        return messageReactions[messageSerial] ?? []
    }
    
    /// Check if user has reacted to message
    /// - Parameters:
    ///   - messageSerial: Message serial
    ///   - clientId: User's client ID
    ///   - reaction: Specific reaction to check
    /// - Returns: True if user has reacted
    func hasUserReacted(
        to messageSerial: String,
        clientId: String,
        reaction: CommonReactions
    ) -> Bool {
        guard let reactions = messageReactions[messageSerial] else { return false }
        
        return reactions.first { $0.name == reaction.rawValue }?
            .userIds.contains(clientId) ?? false
    }
    
    // MARK: - Private Methods
    
    private func setupMessageReactionSubscription() {
        messageSubscription = messageReactionHandler.subscribeToReactionSummaries { [weak self] summaryEvent in
            Task { @MainActor in
                self?.handleReactionSummary(summaryEvent)
            }
        }
    }
    
    private func setupRoomReactionSubscription() {
        roomSubscription = roomReactionHandler.subscribeToRoomReactions { [weak self] reactionEvent in
            Task { @MainActor in
                self?.handleRoomReaction(reactionEvent.reaction)
            }
        }
    }
    
    private func handleReactionSummary(_ event: MessageReactionSummaryEvent) {
        let formatted = ReactionAggregator.formatReactionSummary(event.summary)
        messageReactions[event.summary.messageSerial] = formatted
        
        print("📊 Updated reactions for message \(event.summary.messageSerial): \(formatted.map { $0.displayText })")
    }
    
    private func handleRoomReaction(_ reaction: RoomReaction) {
        // Keep only recent room reactions (last 10)
        recentRoomReactions.append(reaction)
        if recentRoomReactions.count > 10 {
            recentRoomReactions.removeFirst()
        }
        
        print("🎉 Room reaction: \(reaction.name) from \(reaction.clientID)")
    }
}

// MARK: - Reaction Animation Helper

/// Helper for reaction animations and effects
struct ReactionAnimation {
    
    /// Create floating reaction animation data
    /// - Parameter reaction: Reaction to animate
    /// - Returns: Animation data
    static func createFloatingReaction(_ reaction: String) -> FloatingReaction {
        FloatingReaction(
            emoji: reaction,
            id: UUID(),
            startTime: Date(),
            duration: 3.0,
            startPosition: CGPoint(
                x: Double.random(in: 50...300),
                y: 400
            ),
            endPosition: CGPoint(
                x: Double.random(in: 50...300),
                y: 100
            )
        )
    }
    
    /// Create burst animation for multiple reactions
    /// - Parameters:
    ///   - reaction: Base reaction
    ///   - count: Number of reactions in burst
    /// - Returns: Array of floating reactions
    static func createReactionBurst(_ reaction: String, count: Int = 5) -> [FloatingReaction] {
        return (0..<count).map { index in
            let delay = Double(index) * 0.2
            return FloatingReaction(
                emoji: reaction,
                id: UUID(),
                startTime: Date().addingTimeInterval(delay),
                duration: 2.5,
                startPosition: CGPoint(
                    x: Double.random(in: 100...250),
                    y: 350
                ),
                endPosition: CGPoint(
                    x: Double.random(in: 50...300),
                    y: 50
                )
            )
        }
    }
}

/// Model for floating reaction animations
struct FloatingReaction: Identifiable {
    let emoji: String
    let id: UUID
    let startTime: Date
    let duration: TimeInterval
    let startPosition: CGPoint
    let endPosition: CGPoint
    
    var isActive: Bool {
        Date().timeIntervalSince(startTime) < duration
    }
    
    var progress: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        return min(elapsed / duration, 1.0)
    }
}

// MARK: - Complete Reactions Example

/// Complete example demonstrating all reaction features
class CompleteReactionsExample {
    
    func runReactionsExample(room: Room) async {
        print("🎉 Running Reactions Example")
        
        let messageHandler = MessageReactionHandler(room: room)
        let roomHandler = RoomReactionHandler(room: room)
        let uiManager = ReactionUIManager(room: room)
        
        do {
            // 1. Setup reaction monitoring
            print("\n1. Setting up reaction monitoring:")
            await uiManager.startMonitoring()
            
            // Subscribe to summaries
            let summarySubscription = messageHandler.subscribeToReactionSummaries { summaryEvent in
                let reactions = ReactionAggregator.formatReactionSummary(summaryEvent.summary)
                print("Summary updated: \(reactions.map { $0.displayText })")
            }
            
            // 2. Send a test message to react to
            print("\n2. Sending test message:")
            let testMessage = try await room.messages.send(
                params: SendMessageParams(text: "This is a test message for reactions! 🎉")
            )
            
            // 3. Add various message reactions
            print("\n3. Adding message reactions:")
            
            try await messageHandler.addSimpleReaction(
                to: testMessage.serial,
                reactionName: CommonReactions.thumbsUp.rawValue
            )
            
            try await messageHandler.addDistinctReaction(
                to: testMessage.serial,
                reactionName: CommonReactions.heart.rawValue
            )
            
            try await messageHandler.addMultipleReaction(
                to: testMessage.serial,
                reactionName: CommonReactions.clap.rawValue,
                count: 3
            )
            
            // 4. Send room reactions
            print("\n4. Sending room reactions:")
            
            try await uiManager.sendRoomReaction(.partyPopper)
            try await uiManager.sendRoomReaction(.fire)
            
            // 5. Test reaction removal
            print("\n5. Testing reaction removal:")
            
            try await messageHandler.removeReaction(
                from: testMessage.serial,
                reactionName: CommonReactions.thumbsUp.rawValue,
                reactionType: .distinct
            )
            
            // 6. Demonstrate aggregation
            print("\n6. Reaction aggregation:")
            
            // Wait for reactions to be processed
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            let messageReactions = uiManager.getReactionsForMessage(testMessage.serial)
            print("Current reactions on message:")
            for reaction in messageReactions {
                print("   \(reaction.displayText) from \(reaction.userIds)")
            }
            
            // 7. Show recent room reactions
            print("\n7. Recent room reactions:")
            for roomReaction in uiManager.recentRoomReactions {
                print("   \(roomReaction.name) from \(roomReaction.clientID)")
            }
            
            // Wait to observe events
            try await Task.sleep(nanoseconds: 3_000_000_000)
            
            // 8. Cleanup
            print("\n8. Cleaning up:")
            summarySubscription.unsubscribe()
            await uiManager.stopMonitoring()
            
            print("✅ Reactions example completed!")
            
        } catch {
            print("❌ Reactions example failed: \(error)")
        }
    }
}

/*
USAGE:

1. Basic message reactions:
   let reactionHandler = MessageReactionHandler(room: room)
   try await reactionHandler.addSimpleReaction(to: messageSerial, reactionName: "👍")

2. Different reaction types:
   // Distinct - one per user
   try await reactionHandler.addDistinctReaction(to: messageSerial, reactionName: "❤️")
   
   // Multiple - can add multiple from same user
   try await reactionHandler.addMultipleReaction(to: messageSerial, reactionName: "👏", count: 3)
   
   // Unique - replaces user's previous reaction
   try await reactionHandler.addUniqueReaction(to: messageSerial, reactionName: "🎉")

3. Room reactions:
   let roomHandler = RoomReactionHandler(room: room)
   try await roomHandler.sendSimpleRoomReaction(reactionName: "🔥")

4. Reaction subscriptions:
   // Message reaction summaries
   reactionHandler.subscribeToReactionSummaries { summaryEvent in
       print("Reaction summary updated: \(summaryEvent.summary)")
   }
   
   // Raw message reactions
   reactionHandler.subscribeToRawReactions { rawEvent in
       print("Raw reaction: \(rawEvent.reaction.name)")
   }
   
   // Room reactions
   roomHandler.subscribeToRoomReactions { reactionEvent in
       print("Room reaction: \(reactionEvent.reaction.name)")
   }

5. SwiftUI integration:
   @StateObject private var reactionManager = ReactionUIManager(room: room)
   
   .task {
       await reactionManager.startMonitoring()
   }
   
   .onTapGesture {
       Task {
           try await reactionManager.addMessageReaction(to: messageSerial, reaction: .thumbsUp)
       }
   }

6. Reaction aggregation:
   let formatted = ReactionAggregator.formatReactionSummary(summary)
   let topReactions = ReactionAggregator.getTopReactions(from: summary, limit: 3)
   let hasReacted = ReactionAggregator.hasUserReacted(summary: summary, clientId: userId)

7. Complete example:
   Task {
       await CompleteReactionsExample().runReactionsExample(room: room)
   }

FEATURES COVERED:
- Message reactions (distinct, multiple, unique types)
- Room-level reactions
- Reaction removal and management
- Real-time reaction subscriptions
- Reaction aggregation and counting
- UI integration patterns
- Animation helpers for visual effects
- Common emoji reaction presets
- AsyncSequence support
- Comprehensive error handling
*/