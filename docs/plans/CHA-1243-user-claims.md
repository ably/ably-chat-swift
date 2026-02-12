# Plan: Add `userClaim` Field to Chat Events

## Context

The Chat specification (PR #423) adds an optional `userClaim` field across all chat event types. This field is a server-provided, read-only string extracted from JWT claims embedded in realtime message `extras.userClaim`. It enables per-room/channel authorization by exposing channel-specific JWT user claims to SDK consumers. The JS SDK has implemented this in PR #711. This plan covers the equivalent implementation in the Swift SDK.

### Spec Items

| Spec Item | Entity | Summary |
|-----------|--------|---------|
| CHA-M2h | Message | Optional `userClaim` on Message |
| CHA-MR7d | MessageReactionRawEvent.Reaction | Optional `userClaim` on raw reaction events |
| CHA-ER2a | RoomReaction | Optional `userClaim` on ephemeral room reactions |
| CHA-PR6g | PresenceMember | Optional `userClaim` on presence members |
| CHA-T13a1 | TypingSetEvent.Change | Optional `userClaim` on typing event changes; must persist across heartbeats and inactivity timeouts |

All fields share these characteristics:
- Optional `String?`, read-only, server-provided
- Extracted from `extras.userClaim` on the underlying Ably realtime message/annotation/presence message
- Clients cannot send this field

---

## Implementation Steps

### Step 1: Add a `userClaim` extraction helper

**File:** `Sources/AblyChat/JSONValue.swift` (or a new small extension)

Add a helper function to extract `userClaim` from an extras dictionary, following the existing pattern of `objectFromAblyCocoaExtras`:

```swift
internal extension Dictionary where Key == String, Value == JSONValue {
    var userClaim: String? {
        self["userClaim"]?.stringValue
    }
}
```

This centralizes extraction and ensures type safety (must be a string).

---

### Step 2: Add `userClaim` to `Message`

**File:** `Sources/AblyChat/Message.swift`

- Add `public var userClaim: String?` property to `Message` struct
- Update the public memberwise initializer to include `userClaim: String? = nil` (default nil for backwards compatibility)
- Update `Message.init(jsonObject:)` (JSONObjectDecodable) to extract `userClaim` from the JSON response: `jsonObject.optionalStringValueForKey("userClaim")`
- Update `Message.copy(...)` — no change needed since `userClaim` is server-provided and shouldn't be modified by copy

**File:** `Sources/AblyChat/DefaultMessages.swift`

- In `subscribe(_:)`, extract `userClaim` from the `extras` dictionary (already parsed from `message.extras`): `let userClaim = extras.userClaim`
- Pass `userClaim` to the `Message(...)` initializer

---

### Step 3: Add `userClaim` to `RoomReaction`

**File:** `Sources/AblyChat/RoomReaction.swift`

- Add `public var userClaim: String?` to `RoomReaction`
- Update the public memberwise initializer with `userClaim: String? = nil`

**File:** `Sources/AblyChat/DefaultRoomReactions.swift`

- In `subscribe(_:)`, extract `userClaim` from the `extras` dictionary (already parsed): `let userClaim = extras["userClaim"]?.stringValue`
- Pass to `RoomReaction(...)` initializer

---

### Step 4: Add `userClaim` to `PresenceMember`

**File:** `Sources/AblyChat/Presence.swift`

- Add `public var userClaim: String?` to `PresenceMember`
- Update the public memberwise initializer with `userClaim: String? = nil`

**File:** `Sources/AblyChat/DefaultPresence.swift`

- In `processPresenceGet(members:)` and `processPresenceSubscribe(_:for:)`, extract `userClaim` from `member.extras`: `member.extras?.userClaim`
- Pass to `PresenceMember(...)` initializer

The `PresenceMessage` internal struct already parses `extras` from `ARTPresenceMessage`, so the extras dictionary is already available.

---

### Step 5: Add `userClaim` to `TypingSetEvent.Change`

**File:** `Sources/AblyChat/Typing.swift`

- Add `public var userClaim: String?` to `TypingSetEvent.Change`
- Update the public memberwise initializer with `userClaim: String? = nil`

**File:** `Sources/AblyChat/TypingTimerManager.swift`

- Add a `userClaim: String?` field to the per-client typing state. The typing timer manager needs to track the `userClaim` alongside each client's timer so it persists across heartbeats and inactivity timeouts.
- Update `TypingTimerManagerProtocol`:
  - `startTypingTimer(for:userClaim:handler:)` — add `userClaim` parameter
  - `userClaimForClient(_:) -> String?` — retrieve stored claim for a client
- In `TypingTimerManager`, store `userClaim` alongside the timer in `whoIsTypingTimers` (change value type from `TimerManager` to a struct holding both timer and optional userClaim)
- When a new typing.started event arrives with a `userClaim`, store/update it; when it arrives without one, preserve the existing stored claim (CHA-T13a1: "must persist across heartbeat events")

**File:** `Sources/AblyChat/DefaultTyping.swift`

- In the `typing.started` handler:
  - Extract `userClaim` from the realtime message extras: `let extras = message.extras.flatMap { JSONValue.objectFromAblyCocoaExtras($0) } ?? [:]` then `extras.userClaim`
  - Pass to `typingTimerManager.startTypingTimer(for:userClaim:handler:)`
  - Include in the `TypingSetEvent.Change` for both the "new client" event and the timeout-driven synthetic stop event
- In the `typing.stopped` handler:
  - Extract `userClaim` from the message extras (or fall back to the cached value from the timer manager)
  - Include in the `TypingSetEvent.Change`

---

### Step 6: Add `userClaim` to `MessageReactionRawEvent.Reaction`

**File:** `Sources/AblyChat/MessageReaction.swift`

- Add `public var userClaim: String?` to `MessageReactionRawEvent.Reaction`
- Update the public memberwise initializer with `userClaim: String? = nil`

**File:** `Sources/AblyChat/DefaultMessageReactions.swift`

- In `subscribeRaw(_:)`, the callback receives an `ARTAnnotation`. Extract extras: `let extras = annotation.extras.flatMap { JSONValue.objectFromAblyCocoaExtras($0) } ?? [:]` then `extras.userClaim`
- Pass to `MessageReactionRawEvent.Reaction(...)` initializer

Note: `ARTAnnotation` has an `extras` property (it's an `ARTBaseMessage` subclass). The internal `Annotation` wrapper already handles extras extraction but isn't used in `subscribeRaw` — we can extract directly from `ARTAnnotation.extras`.

---

### Step 7: Update Mock/Test Helpers

**Files in `Tests/AblyChatTests/Mocks/`:**

- Update any mock implementations that create `Message`, `PresenceMember`, `RoomReaction`, `TypingSetEvent.Change`, or `MessageReactionRawEvent.Reaction` to include the new `userClaim` parameter (default nil keeps them backwards compatible)

---

### Step 8: Unit Tests

**File:** `Tests/AblyChatTests/` (new or existing test files)

For each type, test:

1. **Message userClaim:**
   - Realtime message with `extras.userClaim` → Message has correct `userClaim`
   - Realtime message without `extras.userClaim` → Message has `nil` userClaim
   - REST/JSON decoded message with `userClaim` → Message has correct `userClaim`
   - REST/JSON decoded message without `userClaim` → Message has `nil` userClaim

2. **RoomReaction userClaim:**
   - Realtime reaction with `extras.userClaim` → RoomReaction has correct `userClaim`
   - Realtime reaction without `extras.userClaim` → RoomReaction has `nil` userClaim

3. **PresenceMember userClaim:**
   - Presence message with `extras.userClaim` → PresenceMember has correct `userClaim`
   - Presence message without extras → PresenceMember has `nil` userClaim
   - Both `get()` and `subscribe()` paths

4. **TypingSetEvent.Change userClaim:**
   - Typing started with `userClaim` → change includes claim
   - Heartbeat (repeated started) preserves existing claim when new event lacks one
   - Typing stopped includes claim (from message or cached)
   - Inactivity timeout synthetic stop includes cached claim

5. **MessageReactionRawEvent.Reaction userClaim:**
   - Annotation with `extras.userClaim` → Reaction has correct `userClaim`
   - Annotation without extras → Reaction has `nil` userClaim

6. **Helper extraction:**
   - `extras.userClaim` returns string value correctly
   - Non-string `userClaim` values return nil
   - Missing `userClaim` key returns nil

---

### Step 9: Integration Tests

**File:** `Tests/AblyChatTests/IntegrationTests.swift`

Integration tests require the server to actually populate `userClaim` from JWT tokens. This depends on the sandbox supporting `ably.room.<roomName>` claims in JWTs.

- If sandbox JWT support is available: Add integration tests that create a client with a JWT containing room claims, send messages/reactions/presence/typing, and verify `userClaim` is populated on received events.
- If not yet available: Add placeholder integration tests with `@Test(.disabled("Requires server-side userClaim support"))` or similar, documenting what should be tested once server support lands.

At minimum, add integration tests that verify `userClaim` is `nil` when using standard API key auth (confirming no regression and that the field is properly exposed even when absent).

---

## Key Files to Modify

| File | Changes |
|------|---------|
| `Sources/AblyChat/Message.swift` | Add `userClaim` property, update init, update JSON decoding |
| `Sources/AblyChat/DefaultMessages.swift` | Extract `userClaim` from extras, pass to Message |
| `Sources/AblyChat/RoomReaction.swift` | Add `userClaim` property, update init |
| `Sources/AblyChat/DefaultRoomReactions.swift` | Extract `userClaim` from extras, pass to RoomReaction |
| `Sources/AblyChat/Presence.swift` | Add `userClaim` property to PresenceMember, update init |
| `Sources/AblyChat/DefaultPresence.swift` | Extract `userClaim` from member extras |
| `Sources/AblyChat/Typing.swift` | Add `userClaim` to TypingSetEvent.Change, update init |
| `Sources/AblyChat/DefaultTyping.swift` | Extract `userClaim` from message extras, pass through |
| `Sources/AblyChat/TypingTimerManager.swift` | Track `userClaim` per client alongside timers |
| `Sources/AblyChat/MessageReaction.swift` | Add `userClaim` to Reaction, update init |
| `Sources/AblyChat/DefaultMessageReactions.swift` | Extract `userClaim` from annotation extras |
| `Sources/AblyChat/JSONValue.swift` | Add `userClaim` extraction helper on extras dictionary |
| `Tests/AblyChatTests/` | Unit tests for all above |
| `Tests/AblyChatTests/IntegrationTests.swift` | Integration tests |

---

## Verification

1. **Build:** `swift build` — ensure no compilation errors
2. **Lint:** `swift run BuildTool lint` — ensure no lint warnings
3. **Unit tests:** `swift test` — all existing and new tests pass
4. **Spec coverage:** Add `@spec` tags to tests referencing CHA-M2h, CHA-MR7d, CHA-ER2a, CHA-PR6g, CHA-T13a1
5. **Manual verification:** Confirm default `nil` values don't break existing consumers (all new parameters have defaults)
