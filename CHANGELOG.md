# Change Log

## [0.4.0](https://github.com/ably/ably-chat-swift/tree/0.4.0)

## What's Changed

- All Chat features now use a single underlying channel. This greatly simplifies the SDK whilst improving performance.

The following features have also been added in this release:

- Ephemeral typing indicators

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.3.0...0.4.0

## [0.3.0](https://github.com/ably/ably-chat-swift/tree/0.3.0)

## What's Changed

- All of the main protocols in the SDK are now marked as `@MainActor`, to simplify the experience of using the SDK. (#261)
- All of the errors thrown by the SDK are now explicitly typed as `ARTErrorInfo`. (#234)

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.2.0...0.3.0

## [0.2.0](https://github.com/ably/ably-chat-swift/tree/0.2.0)

## What's Changed

The following features have been added in this release:

- Updating messages in a chat room
- Deleting messages in a chat room

The included example app has been updated to demonstrate the new features.

#### Breaking Changes

- Renames `ClientOptions` within this SDK to `ChatClientOptions` (https://github.com/ably/ably-chat-swift/pull/230)

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.1.2...0.2.0

## [0.1.2](https://github.com/ably/ably-chat-swift/tree/0.1.2)

## What's Changed

This release reverts the pinning of ably-cocoa that was introduced in version 0.1.1 (https://github.com/ably/ably-chat-swift/pull/215).

**Full Changelog**: https://github.com/ably/ably-chat-swift/compare/0.1.1...0.1.2

## [0.1.1](https://github.com/ably/ably-chat-swift/tree/0.1.1)

## What's Changed

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
