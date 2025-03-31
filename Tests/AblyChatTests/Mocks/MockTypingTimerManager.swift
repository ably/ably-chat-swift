@testable import AblyChat

/*
 // Create a mock implementation for testing
 @MainActor
 final class MockTypingTimerManager: TypingTimerManagerProtocol {
     func startHeartbeatTimer() {}

     var isHeartbeatTimerActive: Bool = false

     func cancelHeartbeatTimer() {}

     func startTypingTimer(for _: String, handler _: (@MainActor @Sendable () -> Void)?) {}

     func cancelTypingTimer(for _: String) {}

     var shouldPublishTypingResults: [Bool] = []
     private var shouldPublishTypingCallCount = 0

     // Make these properties public so tests can access them
     var activeTimers: Set<String> = []
     var typingClients: Set<String> = []

     func shouldPublishTyping() -> Bool {
         guard shouldPublishTypingCallCount < shouldPublishTypingResults.count else {
             print("MockTypingTimerManager: No more preconfigured results, defaulting to 'true'")
             return true
         }

         let result = shouldPublishTypingResults[shouldPublishTypingCallCount]
         shouldPublishTypingCallCount += 1
         print("MockTypingTimerManager.shouldPublishTyping() returning \(result) for call #\(shouldPublishTypingCallCount)")
         return result
     }

     func startTypingTimer(for clientID: String, isSelf: Bool = false, handler _: (@MainActor () -> Void)? = nil) {
         activeTimers.insert(clientID)
         typingClients.insert(clientID)
         print("MockTypingTimerManager: Started timer for \(clientID), isSelf: \(isSelf)")
     }

     func cancelTypingTimer(for clientID: String, isSelf: Bool = false) {
         activeTimers.remove(clientID)
         typingClients.remove(clientID)
         print("MockTypingTimerManager: Cancelled timer for \(clientID), isSelf: \(isSelf)")
     }

     func isTypingTimerActive(for clientID: String) -> Bool {
         activeTimers.contains(clientID)
     }

     func currentlyTypingClients() -> Set<String> {
         typingClients
     }
 }

 */
