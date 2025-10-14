# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ably Chat Swift SDK - A Swift SDK for building chat applications on top of Ably's realtime infrastructure. Supports iOS 14+, macOS 11+, and tvOS 14+. Built as a Swift Package with dependencies on ably-cocoa.

**Example app:** The repo includes an example SwiftUI app in `Example/` that demonstrates core SDK functionality. Open `AblyChat.xcworkspace` to access both the library and example app.

## Setup

```bash
git submodule update --init
mint bootstrap  # Takes ~5 minutes first time
npm install
```

## Build Commands

**Build library:**

```bash
swift build
```

**Test:**

```bash
swift test  # All tests
```

**Test in Xcode:**
Open `AblyChat.xcworkspace` and test the `AblyChat` scheme. Use the `UnitTests` test plan for quick feedback during development (runs only unit tests, not integration tests).

**Lint:**

```bash
swift run BuildTool lint       # Check only
swift run BuildTool lint --fix # Auto-fix where possible
```

**Other BuildTool commands:**

- `swift run BuildTool build-library` - Build the library
- `swift run BuildTool build-example-app --platform <platform>` - Build example app (platform: iOS, macOS, or tvOS)
- `swift run BuildTool spec-coverage` - Generate spec coverage report
- `swift run BuildTool build-documentation` - Build docs
- `swift run BuildTool generate-code-coverage` - Generate code coverage

## Architecture

**Protocol-based design:** The SDK exposes functionality via protocols (e.g., `ChatClientProtocol`, `Room`, `Messages`, `Presence`) to enable easy mocking in consumer tests. Most protocols use associated types with opaque return types (`some Protocol`) rather than existentials (`any Protocol`).

**Main actor isolation:** All mutable state is isolated to the main actor. Stateful objects are marked `@MainActor`.

**Typed throws:** Public API uses typed throws with `ARTErrorInfo`. Internally, `InternalError` is used and converted at public API boundaries.

**Room lifecycle:** `RoomLifecycleManager` manages room state transitions (ATTACHING → ATTACHED → DETACHING → DETACHED → RELEASING → RELEASED, with FAILED and SUSPENDED states). Each room has features (messages, presence, typing, reactions, occupancy) that coordinate through the lifecycle manager.

**Key types:**

- `ChatClient` - Entry point, manages rooms and connection
- `Room` - Represents a chat room, provides access to features
- `Messages`, `Presence`, `Typing`, `RoomReactions`, `Occupancy` - Room feature protocols
- `RoomLifecycleManager` - Manages room state and feature coordination
- `Dependencies.swift` - Defines internal protocol hierarchy for wrapping ably-cocoa types

**Testing:**

- Tests live in `Tests/AblyChatTests/`
- Mock implementations in `Tests/AblyChatTests/Mocks/`
- Integration tests use shared spec from `Tests/AblyChatTests/ably-common` submodule
- Test-only APIs prefixed with `testsOnly_` and wrapped in `#if DEBUG`

## Development Guidelines

**Spec attribution:** Reference Chat SDK features spec items in code comments when implementing behavior (e.g., `// @spec CHA-RL3g`). Use test attribution tags:

- `@spec <spec-item-id>` - Test fully covers spec item
- `@specOneOf(m/n) <spec-item-id>` - One of n tests covering spec item
- `@specPartial <spec-item-id>` - Partially tests spec item
- `@specUntested <spec-item-id> - <explanation>` - Implemented but not testable
- `@specNotApplicable <spec-item-id> - <explanation>` - Not relevant for Swift SDK

**Memberwise initializers:** When defining public structs emitted by the API, provide a public memberwise initializer (Swift's auto-generated one isn't public).

**AsyncSequence operators:** When using `AsyncSequence` operators in `@MainActor` contexts, mark operator closures as `@Sendable` to avoid data race warnings.

**Typed throws sharp edges:**

- `Task`, `CheckedContinuation`, `AsyncThrowingStream` don't support typed errors - use `Result` and call `.get()`
- `Dictionary.mapValues` doesn't support typed throws - use `ablyChat_mapValuesWithTypedThrow` extension
- Explicitly specify error type with `do throws(InternalError)` when compiler struggles
- Specify error type in closures: `try items.map { jsonValue throws(InternalError) in … }`
- For Swift Testing `#expect(throws:)` with typed errors, move typed-throw code into separate non-typed-throw function (workaround for compiler crash until Xcode 16.3+)

**Swift settings:** All targets use strict warnings-as-errors and enable upcoming features `MemberImportVisibility` and `ExistentialAny`.
