# Contributing

## Requirements

- The Xcode version [mentioned in the README](./README.md#requirements)
- [Mint](https://github.com/yonaskolb/Mint) package manager
- Node.js (any recent version should be fine)

## Setup

1. `git submodule update --init`
2. `mint bootstrap` — this will take quite a long time (~5 minutes on my machine) the first time you run it
3. `npm install`

## Running the tests

Either:

- `swift test`, or
- open `AblyChat.xcworkspace` in Xcode and test the `AblyChat` scheme

### Running only the unit tests

There is a test plan called `UnitTests` which will run only the unit tests. These tests are very quick to execute, so it's a useful option to have for quick feedback when developing.

Here's how to set this test plan as the _active test plan_ (the test plan which ⌘U will run):

![Screenshot showing how to activate the UnitTests test plan](/images/unit-tests-test-plan-screenshot.png)

## Linting

To check formatting and code quality, run `swift run BuildTool lint`. Run with `--fix` to first automatically fix things where possible.

## Development guidelines

- The aim of the [example app](README.md#example-app) is that it demonstrate all of the core functionality of the SDK. So if you add a new feature, try to add something to the example app to demonstrate this feature.
- If you add a new feature, try to extend the `IntegrationTests` tests to perform a smoke test of its core functionality.
- We should aim to make it easy for consumers of the SDK to be able to mock out the SDK in the tests for their own code. A couple of things that will aid with this:
  - Describe the SDK’s functionality via protocols (when doing so would still be sufficiently idiomatic to Swift).
  - When defining a `struct` that is emitted by the public API of the library, make sure to define a public memberwise initializer so that users can create one to be emitted by their mocks. (There is no way to make Swift’s autogenerated memberwise initializer public, so you will need to write one yourself. In Xcode, you can do this by clicking at the start of the type declaration and doing Editor → Refactor → Generate Memberwise Initializer.)
- When writing code that implements behaviour specified by the Chat SDK features spec, add a comment that references the identifier of the relevant spec item.
- The SDK isolates all of its mutable state to the main actor. Stateful objects should be marked as `@MainActor`.

### Throwing errors

- The public API of the SDK should use typed throws, and the thrown errors should be of type `ARTErrorInfo`.
- Currently, we throw the `InternalError` type everywhere internally, and then convert it to `ARTErrorInfo` at the public API. This allows us to use richer Swift errors for our internals.

If you haven't worked with typed throws before, be aware of a few sharp edges:

- Some of the Swift standard library does not (yet?) interact as nicely with typed throws as you might hope.
  - It is not currently possible to create a `Task`, `CheckedContinuation`, or `AsyncThrowingStream` with a specific error type. You will need to instead return a `Result` and then call its `.get()` method.
  - `Dictionary.mapValues` does not support typed throws. We have our own extension `ablyChat_mapValuesWithTypedThrow` which does; use this.
- There are times when the compiler struggles to infer the type of the error thrown within a `do` block. In these cases, you can disable type inference for a `do` block and explicitly specify the type of the thrown error, like: `do throws(InternalError) { … }`.
- The compiler will never infer the type of the error thrown by a closure; you will need to specify this yourself; e.g. `let items = try jsonValues.map { jsonValue throws(InternalError) in … }`.
- It is possible to crash the compiler when using Swift Testing's `#expect(throws: …)` in combination with an `expression` that throws a typed error. See https://github.com/ably/ably-chat-swift/issues/233. A workaround that seems to work, which we're using at the moment (will be able to remove once Xcode 16.3 is released) is to move the code with a typed throw into a separate, non-typed-throw function; for example:
  ```swift
  let doIt = {
      try await rooms.get(name: name, options: differentOptions)
  }
  await #expect {
      try await doIt()
  } throws: { error in
      isChatError(error, withCodeAndStatusCode: .fixedStatusCode(.badRequest))
  }
  ```

### Swift concurrency rough edges

#### `AsyncSequence` operator compiler errors

Consider the following code:

```swift
@MainActor
func myThing() async {
    let streamComponents = AsyncStream<Void>.makeStream()
    await streamComponents.stream.first { _ in true }
}
```

This gives a compiler error "Sending main actor-isolated value of type '(Void) async -> Bool' with later accesses to nonisolated context risks causing data races". This is a minimal reproduction of a similar error that I have come across when trying to use operators on an `AsyncSequence`. I do not understand enough about Swift concurrency to be able to give a good explanation of what's going on here. However, I have noticed that this error goes away if you explicitly mark the operator body as `@Sendable` (my reasoning was "the closure mentions the fact that the closure is main actor-isolated, so what if I make it not be; I think writing `@Sendable` achieves that for reasons I'm not fully sure of").

So the following code compiles, and you'll notice lots of `@Sendable` closures dotted around the codebase for this reason.

```swift
@MainActor
func myThing() async {
    let streamComponents = AsyncStream<Void>.makeStream()
    await streamComponents.stream.first { @Sendable _ in true }
}
```

I hope that as we understand more about Swift concurrency, we'll have a better understanding of what's going on here and whether this is the right way to fix it.

### Testing guidelines

#### Exposing test-only APIs

When writing unit tests, there are times that we need to access internal state of a type. To enable this, we might expose this state at an `internal` access level so that it can be used by the unit tests. However, we want to make it clear that this state is being exposed _purely_ for the purposes of testing that class, and that it should not be used by other components of the SDK.

So, when writing an API which has `internal` access level purely to enable it to be called by the tests, prefix this API’s name with `testOnly_`. For example:

```swift
private nonisolated let realtime: RealtimeClient

#if DEBUG
    internal nonisolated var testsOnly_realtime: RealtimeClient {
        realtime
    }
#endif
```

A couple of notes:

- Using a naming convention will allow us to verify that APIs marked `testsOnly` are not being used inside the SDK; we’ll do this in #70.
- I believe that we should be able to eliminate the boilerplate of re-exposing a `private` member as a `testsOnly` member (as exemplified above) using a macro (called e.g. `@ExposedToTests`), but my level of experience with macros is insufficient to be confident about being able to do this quickly, so have deferred it to #71.

#### Attributing tests to a spec point

When writing a test that relates to a spec point from the Chat SDK features spec, add a comment that contains one of the following tags:

- `@spec <spec-item-id>` — The test case directly tests all the functionality documented in the spec item.
- `@specOneOf(m/n) <spec-item-id>` — The test case is the m<sup>th</sup> of n test cases which, together, test all the functionality documented in the spec item.
- `@specPartial <spec-item-id>` — The test case tests some, but not all, of the functionality documented in the spec item. This is different to `@specOneOf` in that it implies that the test suite does not fully test this spec item.

The `<spec-item-id>` parameter should be a spec item identifier such as `CHA-RL3g`.

Each of the above tags can optionally be followed by a hyphen and an explanation of how the test relates to the given spec item.

Examples:

```swift
// @spec CHA-EX3f
func test1 { … }
```

```swift
// @specOneOf(1/2) CHA-EX2h — Tests the case where the room is FAILED
func test2 { … }

// @specOneOf(2/2) CHA-EX2h — Tests the case where the room is SUSPENDED
func test3 { … }
```

```swift
// @specPartial CHA-EX1h4 - Tests that we retry, but not the retry attempt limit because we’ve not implemented it yet
func test4 { … }
```

You can run `swift run BuildTool spec-coverage` to generate a report about how many spec points have been implemented and/or tested. This script is also run in CI by the `spec-coverage` job. This script will currently only detect a spec point attribution tag if it’s written exactly as shown above; that is, in a `//` comment with a single space between each component of the tag.

#### Marking a spec point as untested

In addition to the above, you can add the following as a comment anywhere in the test suite:

- `@specUntested <spec-item-id> - <explanation>` — This indicates that the SDK implements the given spec point, but that there are no automated tests for it. This should be used sparingly; only use it when there is no way to test a spec point. It must be accompanied by an explanation of why this spec point is not tested.
- `@specNotApplicable <spec-item-id> - <explanation>` — This indicates that the spec item is not relevant for this version of the SDK. It must be accompanied by an explanation of why.

Example:

```swift
// @specUntested CHA-EX2b - I was unable to find a way to test this spec point in an environment in which concurrency is being used; there is no obvious moment at which to stop observing the emitted state changes in order to be sure that FAILED has not been emitted twice.
```

```swift
// @specNotApplicable CHA-EX3a - Our API does not have a concept of "partial options" unlike the JS API which this spec item considers.
```

## Release process

For each release, the following needs to be done:

- Create a new branch `release/x.x.x` (where `x.x.x` is the new version number) from the `main` branch
- Update the following (we have https://github.com/ably/ably-chat-swift/issues/277 for adding a script to do this):
  - the `version` constant in [`Sources/AblyChat/Version.swift`](Sources/AblyChat/Version.swift)
  - the `from: "…"` in the SPM installation instructions in [`README.md`](README.md)
- Go to [Github releases](https://github.com/ably/ably-chat-swift/releases) and press the `Draft a new release` button. Choose your new branch as a target
- Press the `Choose a tag` dropdown and start typing a new tag, Github will suggest the `Create new tag x.x.x on publish` option. After you select it Github will unveil the `Generate release notes` button
- From the newly generated changes remove everything that don't make much sense to the library user
- Copy the final list of changes to the top of the `CHANGELOG.md` file. Modify as necessary to fit the existing format of this file
- Commit these changes and push to the origin `git add CHANGELOG.md && git commit -m "Update change log." && git push -u origin release/x.x.x`
- Make a pull request against `main` and await approval of reviewer(s)
- Once approved and/or any additional commits have been added, merge the PR
- After merging the PR, wait for all CI jobs for `main` to pass.
- Publish your drafted release (refer to previous releases for release notes format)
