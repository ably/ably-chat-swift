# Change Log

## [1.0.1](https://github.com/ably/ably-chat-swift/tree/1.0.1)

### What's Changed

This fixes a bug with typing indicators, in which a user who continued typing for a long time would eventually appear to have stopped typing, even though they hadn't ([#457](https://github.com/ably/ably-chat-swift/pull/457)).

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/1.0.0...1.0.1

## [1.0.0](https://github.com/ably/ably-chat-swift/tree/1.0.0)

We are excited to announce that the Ably Chat SDK API is now stable.

The Chat SDK includes comprehensive support for:

- Chat rooms for 1:1, 1:many, many:1 and many:many participation
- Messages with full CRUD operations (create, read, update, delete)
- Presence to track online status of chat participants
- Occupancy for monitoring total connections and presence members
- Typing indicators for real-time typing awareness
- Room reactions for real-time room reactions
- Message reactions for reactions to specific messages

We are committed to maintaining API stability and providing long-term support for v1.x releases.

Thank you to everyone who provided feedback during the preview releases!

## [0.9.1](https://github.com/ably/ably-chat-swift/tree/0.9.1)

### What's Changed

This fixes the compilation error <code>error: conflicting options '-warnings-as-errors' and '-suppress-warnings'</code> that occurs when using Xcode to build an app that uses version 0.9.0 of this SDK.

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.9.0...0.9.1

## [0.9.0](https://github.com/ably/ably-chat-swift/tree/0.9.0)

### What's Changed

This release includes many changes to the public API, which aim to achieve the following:

1. Matching the functionality and API of the JavaScript version of this SDK.
2. Improving method naming to meet the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

#### Requirements

- Xcode 26 is now required.

#### Improved APIs

- `ChatClient`'s `realtime` property and `ChatClient.Room`'s `channel` property now have concrete types `ARTRealtime` and `ARTRealtimeChannel` respectively, instead of existential (`any`) types.
- `ChatClient` can now be initialised without an `options` argument.

#### New APIs

- `Message.with(_ messageEvent: ChatMessageEvent)` method, to apply a message event to an existing message.
- `Messages.get(withSerial serial: String)` method, to fetch a single message by its `serial`.
- `PresenceMember` has a new `connectionID` property.
- `MessageReactions.clientReactions(forMessageWithSerial:clientID:)` method, to fetch a specific message's reactions for a specific client ID.

#### Renamed APIs

- The `DefaultChatClient` class has been renamed to `ChatClient`.
- `Messages`:
  - `history(options:)` has been renamed to `history(withParams:)`.
  - `send(params:)` has been renamed to `send(withParams:)`.
- `MessageReactions`:
  - `send(messageSerial:params:)` has been renamed to `send(forMessageWithSerial:params:)`.
  - `delete(messageSerial:params:)` has been renamed to `delete(fromMessageWithSerial:params:)`.
- `Presence`:
  - `get(params:)` has been renamed to `get(withParams:)`.
  - `isUserPresent(clientID:)` has been renamed to `isUserPresent(withClientID:)`.
  - `enter(data:)` has been renamed to `enter(withData:)`; ditto for `update`, `leave`.
- `RoomReactions`:
  - `send(params:)` has been renamed to `send(withParams:)`.
- `MessageSubscriptionResponse`:
  - `historyBeforeSubscribe(_:)` has been renamed to `historyBeforeSubscribe(withParams:)`.
- `Rooms`:
  - `get(name:)` has been renamed to `get(named:)`.
  - `release(name:)` has been renamed to `release(named:)`.
- `Message`:
  - `with(summaryEvent:)` has been renamed to `with(_:)`.
- `Typing`:
  - The `get()` method has been renamed to `current`, and is now a synchronous non-throwing property.
- The `QueryOptions` type has been renamed to `HistoryParams`.
- For consistency with the callback-based APIs, `MessageSubscriptionAsyncSequence` has been renamed to `MessageSubscriptionResponseAsyncSequence`, and its `getPreviousMessages` method has been renamed to `historyBeforeSubscribe`.
- `MessageReactionEvent` has been renamed to `MessageReactionEventType`.
- `MessageAction` has been renamed to `ChatMessageAction`, and its cases have been prefixed with `message` (e.g. `.create` is now `.messageCreate`).
- `MessageReaction` has been renamed to `MessageReactionRawEvent.Reaction`.
- The capitalisation of `clientId` has been corrected to `clientID` in various APIs.

#### Modified APIs

- `Messages`:
  - `update` has been changed to accept:
    - a message's `serial`
    - an `UpdateMessageParams` that describes the changes to be made to the message's properties
    - an optional `OperationDetails` to provide metadata about the update operation
  - `delete` has been changed to accept:
    - a message's `serial`
    - an optional `OperationDetails` to provide metadata about the delete operation
- `Message`:
  - The `copy` method no longer accepts a `reactions` argument.
  - The `reactions` property is no longer optional.
- `PaginatedResult`:
  - This type is now isolated to the main actor.
  - The usage of typed throws has been restored (this was temporarily removed in version 0.3.0 due to a compiler bug).
  - `current`, `next`, and `first` are now methods instead of properties.
- The `Room` status API has been changed for consistency with `Connection` and with other platforms. `RoomStatus`'s associated values have been replaced by a new `Room.error` property, and `RoomStatusChange` has a new `error` property.
- The type of the parameters accepted by `historyBeforeSubscribe` has been changed to a new type, `HistoryBeforeSubscribeParams`. This type is the same as the previous `HistoryParams` but omits the `orderBy` property.
- `ChatClientOptions.logLevel` now has a default value of `.error` instead of `nil`, for consistency with other options. To disable logging, set this property to `nil` (the `LogLevel.silent` case has been removed).
- The `LogHandler` protocol has been renamed to `LogHandler.Simple`, and to set a custom log handler on a `ChatClientOptions` you must now write `options.logHandler = .simple(myLogHandler)`.
- `MessageReactionEventType` has been split into two new types: `MessageReactionRawEventType` and `MessageReactionSummaryEventType`.
- `ConnectionStateChange.retryIn` is now optional.
- `MessageReactionRawEvent.timestamp` is no longer optional.
- Reaction summary events have been restructured: `MessageReactionSummaryEvent.summary` has been renamed to `reactions`, and the `messageSerial` property has been moved to the top level of the event.
- Message operation metadata now only accepts `String` values.
- The `ChatClient.clientID` property is now optional.
- Most of the usage of existential (`any`) types has been removed from the public API, in favour of protocol associated types.
- The SDK now throws its own `ErrorInfo` error type instead of ably-cocoa's `ARTErrorInfo`. `ErrorInfo` provides a similar API to `ARTErrorInfo` but does not inherit from `NSError`. As part of this change, the `ErrorCode` enum of possible error `code` values has been removed.
- The `DiscontinuityEvent` type has been removed; the `onDiscontinuity` method now just emits an `ErrorInfo`.

#### Removed APIs

- The `Presence` subscription methods that accept an event filter have been removed, for consistency with the other subscription APIs.
- The `Rooms.clientOptions` property has been removed.
- The `RoomOptions.reactions` property has been removed.
- The `MessageReactionRawEvent.Reaction.isSelf` property has been removed.
- The `context` log handler parameter has been removed, since the SDK was not making use of it.
- `Equatable` conformance has been removed from some types for which this conformance was not appropriate.
- `Identifiable` conformance has been removed from `Message`.

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.8.0...0.9.0

## [0.8.0](https://github.com/ably/ably-chat-swift/tree/0.8.0)

### What's Changed

- Adds new getting started link by @franrob-projects in https://github.com/ably/ably-chat-swift/pull/352
- Add support for clipped summaries and unidentified totals by @ttypic in https://github.com/ably/ably-chat-swift/pull/355

Breaking Changes:

- presence: make data a json object by @AndyTWF in https://github.com/ably/ably-chat-swift/pull/354
- Message payload v4 by @maratal in https://github.com/ably/ably-chat-swift/pull/350

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.7.0...0.8.0

## [0.7.0](https://github.com/ably/ably-chat-swift/tree/0.7.0)

### What's Changed

- Adds moderation and rule based error cases by @umair-ably in https://github.com/ably/ably-chat-swift/pull/328
- Add the soft delete behaviour and validation loosening by @maratal in https://github.com/ably/ably-chat-swift/pull/330

Breaking Changes:

- remove opinionated presence structure by @ttypic in https://github.com/ably/ably-chat-swift/pull/336
- All errors via chat error by @maratal in https://github.com/ably/ably-chat-swift/pull/331
- async and throwing from Messages.subscribe by @maratal in https://github.com/ably/ably-chat-swift/pull/318

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.6.0...0.7.0

## [0.6.0](https://github.com/ably/ably-chat-swift/tree/0.6.0)

### What's Changed

Breaking Changes:

- Renames RoomReaction.type to RoomReaction.name by @umair-ably in https://github.com/ably/ably-chat-swift/pull/326

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.5.0...0.6.0

## [0.5.0](https://github.com/ably/ably-chat-swift/tree/0.5.0)

### What's Changed

The following features have been added in this release:

- Add message reactions by @maratal in https://github.com/ably/ably-chat-swift/pull/307

The following additional changes (some breaking) are also a part of this release:

- Switch to callbacks by @maratal in https://github.com/ably/ably-chat-swift/pull/286
- Soft deletes changes by @maratal in https://github.com/ably/ably-chat-swift/pull/322
- Refactor `roomID` to `name` and `roomName` across SDK by @ttypic in https://github.com/ably/ably-chat-swift/pull/308
- Refactor Occupancy events by @ttypic in https://github.com/ably/ably-chat-swift/pull/309
- Refactor wrap Message in the Messages subscription in MessageEvent by @ttypic in https://github.com/ably/ably-chat-swift/pull/310
- Refactor `PresenceEvent` by @ttypic in https://github.com/ably/ably-chat-swift/pull/311
- Refactor `RoomReactions` event by @ttypic in https://github.com/ably/ably-chat-swift/pull/312
- Unifies message reactions api across platforms by @umair-ably in https://github.com/ably/ably-chat-swift/pull/317

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.4.0...0.5.0

## [0.4.0](https://github.com/ably/ably-chat-swift/tree/0.4.0)

### What's Changed

- All Chat features now use a single underlying channel. This greatly simplifies the SDK whilst improving performance.

The following features have also been added in this release:

- Ephemeral typing indicators

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.3.0...0.4.0

## [0.3.0](https://github.com/ably/ably-chat-swift/tree/0.3.0)

### What's Changed

- All of the main protocols in the SDK are now marked as `@MainActor`, to simplify the experience of using the SDK. (#261)
- All of the errors thrown by the SDK are now explicitly typed as `ARTErrorInfo`. (#234)

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.2.0...0.3.0

## [0.2.0](https://github.com/ably/ably-chat-swift/tree/0.2.0)

### What's Changed

The following features have been added in this release:

- Updating messages in a chat room
- Deleting messages in a chat room

The included example app has been updated to demonstrate the new features.

#### Breaking Changes

- Renames `ClientOptions` within this SDK to `ChatClientOptions` (https://github.com/ably/ably-chat-swift/pull/230)

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.1.2...0.2.0

## [0.1.2](https://github.com/ably/ably-chat-swift/tree/0.1.2)

### What's Changed

This release reverts the pinning of ably-cocoa that was introduced in version 0.1.1 (https://github.com/ably/ably-chat-swift/pull/215).

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.1.1...0.1.2

## [0.1.1](https://github.com/ably/ably-chat-swift/tree/0.1.1)

### What's Changed

This release temporarily pins the SDK's required version of ably-cocoa (https://github.com/ably/ably-chat-swift/pull/213). This change will be reverted in an upcoming release in the near future.

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.1.0...0.1.1

## [0.1.0](https://github.com/ably/ably-chat-swift/tree/0.1.0)

Initial release of the Ably Chat SDK in Swift. It includes the following chat features:

- Chat rooms for 1:1, 1:many, many:1 and many:many participation.
- Sending and receiving chat messages.
- Online status aka presence of chat participants.
- Chat room occupancy, i.e., total number of connections and presence members.
- Typing indicators
- Room-level reactions (ephemeral at this stage - reactions are sent and received in real-time without persistence)
