# DJIwphone QDC507 Merge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the proven qdc507-ios CallKit, foreground WebRTC, audio-session, and Gateway-signaling code into the original DJIwphone while producing exactly one validated DJIwphone IPA.

**Architecture:** Keep `GatewayConnectionStore` as the single UI-facing source of truth. Add focused CallKit, media-session, and WebRTC boundaries under `DJIwphone/Communication/Realtime`, all configured from the existing `GatewayConfiguration`; retain the existing screens and route every system/media event back through the existing call state. Build one `DJIwphone` application target and gate artifact upload behind an executable IPA validator.

**Tech Stack:** Swift 5, SwiftUI, Observation, URLSession HTTP/WebSocket, CallKit, AVFoundation, WebRTC XCFramework through Swift Package Manager, XCTest, XcodeGen, GitHub Actions shell validation.

**Spec:** `docs/superpowers/specs/2026-09-06-djiwphone-qdc507-merge-design.md`

## Global Constraints

- The only application is DJIwphone; no second `@main`, application target, scheme, `.app`, or IPA is allowed.
- Preserve display name `DJIwphone` and Bundle ID `com.kevin2xiaomao.qdc507communication`.
- Preserve the existing DJIwphone UI, Gateway settings, Keychain token storage, HTTP/WebSocket, status, SMS, dial, incoming-call, and call-control behavior.
- Do not include, rename, or modify the “你的小掌柜” application or its widget.
- Do not modify QDC507 USB/ADB/serial configuration or the Windows Gateway process/state.
- qdc507-ios is read-only module/reference input and remains a separate repository.
- Token values must never be logged, committed, embedded in test fixtures, or written outside the existing Keychain storage.
- CI must reject incomplete, undersized, malformed, wrong-Bundle-ID, non-Mach-O, or unresolved-framework IPA output before artifact upload.

---

### Task 1: Lock the DJIwphone identity and single-target project

**Files:**
- Modify: `project.yml`
- Modify: `.github/workflows/build.yml`
- Modify: `Tests/DJIwphoneSmokeTests.swift`

**Interfaces:**
- Consumes: existing source root `DJIwphone/` and Bundle ID `com.kevin2xiaomao.qdc507communication`.
- Produces: application target/module/scheme `DJIwphone`, test target `DJIwphoneTests`, and one Release product `DJIwphone.app`.

- [ ] **Step 1: Change the smoke test first so it imports the intended module**

```swift
import XCTest
@testable import DJIwphone

final class DJIwphoneSmokeTests: XCTestCase {
    func testOriginalApplicationIdentity() {
        XCTAssertEqual(DJIwphoneIdentity.bundleIdentifier, "com.kevin2xiaomao.qdc507communication")
        XCTAssertEqual(DJIwphoneIdentity.displayName, "DJIwphone")
    }
}
```

- [ ] **Step 2: Run the test build and confirm RED**

Run on macOS/CI: `xcodegen generate && xcodebuild test -project DJIwphone.xcodeproj -scheme DJIwphone -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`

Expected: failure because the `DJIwphone` scheme/module and `DJIwphoneIdentity` do not yet exist.

- [ ] **Step 3: Rename only project metadata and add immutable identity values**

In `project.yml`, rename `QDC507Communication` to `DJIwphone`, rename its test target to `DJIwphoneTests`, keep the original Bundle ID, and keep `DJIwphone/QDC507CommunicationApp.swift` as the only source containing `@main`. Add to that source:

```swift
enum DJIwphoneIdentity {
    static let bundleIdentifier = "com.kevin2xiaomao.qdc507communication"
    static let displayName = "DJIwphone"
}
```

Update the workflow to reference only the `DJIwphone` scheme without changing artifact behavior yet.

- [ ] **Step 4: Run the smoke test and confirm GREEN**

Run the same command. Expected: the scheme resolves, the test target imports `DJIwphone`, and the identity test passes.

- [ ] **Step 5: Commit**

```text
git add project.yml DJIwphone/QDC507CommunicationApp.swift Tests/DJIwphoneSmokeTests.swift .github/workflows/build.yml
git commit -m "build: make DJIwphone the sole application target"
```

### Task 2: Reuse the existing Gateway configuration for realtime signaling

**Files:**
- Create: `DJIwphone/Communication/Realtime/GatewayRealtimeModels.swift`
- Create: `DJIwphone/Communication/Realtime/GatewayRealtimeSignaling.swift`
- Modify: `DJIwphone/Communication/GatewayConfiguration.swift`
- Create: `Tests/GatewayRealtimeSignalingTests.swift`

**Interfaces:**
- Consumes: `GatewayConfiguration.request(path:webSocket:)` and the existing Keychain-backed `GatewaySettingsStore`.
- Produces: `GatewayRealtimeEvent`, `GatewayRealtimeSignaling`, and `URLSessionGatewayRealtimeSignaling(configuration:)` using the same `/ws` URL and Bearer header as the current client.

- [ ] **Step 1: Write tests for real request construction and literal Gateway envelopes**

```swift
func testRealtimeRequestUsesExistingWebSocketURLAndBearerToken() throws {
    let token = UUID().uuidString
    let config = try GatewayConfiguration(address: "http://192.168.1.97:17576", token: token)
    let request = try config.realtimeRequest()
    XCTAssertEqual(request.url?.absoluteString, "ws://192.168.1.97:17576/ws")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
}

func testDecodesTypeEnvelopeAndCallID() throws {
    let data = Data(#"{"type":"call.ringing","sequence":7,"data":{"call_id":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","state":"incoming","masked_number":"***00"}}"#.utf8)
    let event = try JSONDecoder().decode(GatewayRealtimeEvent.self, from: data)
    XCTAssertEqual(event.type, "call.ringing")
    XCTAssertEqual(event.data?.callID, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
}
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `xcodebuild test -project DJIwphone.xcodeproj -scheme DJIwphone -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DJIwphoneTests/GatewayRealtimeSignalingTests CODE_SIGNING_ALLOWED=NO`

Expected: failure because `realtimeRequest` and the realtime types do not exist.

- [ ] **Step 3: Implement the minimal adapter without duplicating credentials**

`GatewayConfiguration.realtimeRequest()` delegates to `request(path: "ws", webSocket: true)`. `URLSessionGatewayRealtimeSignaling` accepts that request, owns one `URLSessionWebSocketTask`, decodes the existing `type/sequence/data` envelope, loops receives, and exposes closures for decoded events and disconnection. It must not accept or store a second plaintext Token.

- [ ] **Step 4: Run focused and existing Gateway tests**

Expected: new request/envelope tests and existing `GatewayConfigurationTests` pass.

- [ ] **Step 5: Commit**

```text
git add DJIwphone/Communication/GatewayConfiguration.swift DJIwphone/Communication/Realtime Tests/GatewayRealtimeSignalingTests.swift
git commit -m "feat: add authenticated Gateway realtime signaling"
```

### Task 3: Route incoming calls and actions through CallKit

**Files:**
- Create: `DJIwphone/Communication/Realtime/DJIwphoneCallKit.swift`
- Create: `DJIwphone/Communication/Realtime/CallCoordinator.swift`
- Modify: `DJIwphone/Communication/GatewayConnectionStore.swift`
- Create: `Tests/CallCoordinatorTests.swift`

**Interfaces:**
- Consumes: existing `GatewayCall`, `GatewayCallAction`, `GatewayConnectionStore.performCallAction`, and realtime call events.
- Produces: `DJIwphoneCallKitReporting`, `DefaultDJIwphoneCallKit`, and `CallCoordinator` that maps one stable Gateway call ID to one stable CallKit UUID.

- [ ] **Step 1: Write coordinator tests with a recording reporter**

```swift
func testIncomingThenEndedUsesTheSameSystemCallIdentifier() {
    let reporter = RecordingCallKitReporter()
    let coordinator = CallCoordinator(callKit: reporter)
    coordinator.apply(.incoming(callID: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", number: "***00"))
    coordinator.apply(.ended(callID: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
    XCTAssertEqual(reporter.incomingIDs, reporter.endedIDs)
}
```

Also test that answer/reject/end delegate callbacks produce exactly one corresponding `GatewayCallAction` request and that duplicate end events are ignored.

- [ ] **Step 2: Run the focused tests and confirm RED**

Expected: failure because the reporter and coordinator do not exist.

- [ ] **Step 3: Implement CallKit reporting and action callbacks**

Use `CXProviderConfiguration(localizedName: "DJIwphone")`. Derive a deterministic UUID from a valid 32-character hex call ID; cache the UUID for other IDs. Handle `CXAnswerCallAction` and `CXEndCallAction` by invoking an injected async action closure, then fulfill or fail the CallKit action. `GatewayConnectionStore` remains the only object that performs Gateway call actions.

- [ ] **Step 4: Run coordinator tests and full XCTest**

Expected: one system call per Gateway call and no regression in existing call controls.

- [ ] **Step 5: Commit**

```text
git add DJIwphone/Communication/Realtime/DJIwphoneCallKit.swift DJIwphone/Communication/Realtime/CallCoordinator.swift DJIwphone/Communication/GatewayConnectionStore.swift Tests/CallCoordinatorTests.swift
git commit -m "feat: integrate DJIwphone calls with CallKit"
```

### Task 4: Coordinate the WebRTC audio lifecycle

**Files:**
- Create: `DJIwphone/Communication/Realtime/DJIwphoneAudioSession.swift`
- Create: `DJIwphone/Communication/Realtime/CallMediaCoordinator.swift`
- Modify: `DJIwphone/Communication/GatewayCallAudioSession.swift`
- Create: `Tests/CallMediaCoordinatorTests.swift`

**Interfaces:**
- Consumes: `GatewayCallAudioState` transitions and a foreground peer abstraction.
- Produces: `DJIwphoneAudioSessionControlling` and `CallMediaCoordinator` with `start(callID:)`, `markReady(callID:)`, `stop(callID:)`, and `fail(callID:error:)`.

- [ ] **Step 1: Write lifecycle tests**

```swift
func testActiveCallActivatesAudioOnceAndEndedCallClosesMedia() throws {
    let audio = RecordingAudioSession()
    let peer = RecordingPeerConnection()
    let coordinator = CallMediaCoordinator(audio: audio, peer: peer)
    try coordinator.start(callID: "call")
    coordinator.stop(callID: "call")
    XCTAssertEqual(audio.activations, 1)
    XCTAssertEqual(audio.deactivations, 1)
    XCTAssertEqual(peer.closeCount, 1)
}
```

Also test duplicate starts, wrong call IDs, activation failure, disconnect, and idempotent stop.

- [ ] **Step 2: Run focused tests and confirm RED**

Expected: failure because media coordinator and audio abstraction do not exist.

- [ ] **Step 3: Implement AVAudioSession and fail-closed lifecycle**

Configure `.playAndRecord`, `.voiceChat`, `.allowBluetooth`, and `.defaultToSpeaker`; do not force a sample rate. On any activation/peer failure, close the peer, deactivate audio, and publish a safe failure state through `GatewayCallAudioSession`.

- [ ] **Step 4: Run focused and existing audio tests**

Expected: lifecycle tests and `GatewayCallAudioSessionTests` pass.

- [ ] **Step 5: Commit**

```text
git add DJIwphone/Communication/Realtime/DJIwphoneAudioSession.swift DJIwphone/Communication/Realtime/CallMediaCoordinator.swift DJIwphone/Communication/GatewayCallAudioSession.swift Tests/CallMediaCoordinatorTests.swift
git commit -m "feat: coordinate WebRTC call audio lifecycle"
```

### Task 5: Link the foreground WebRTC framework into DJIwphone

**Files:**
- Modify: `project.yml`
- Create: `DJIwphone/Communication/Realtime/ForegroundPeerConnection.swift`
- Create: `DJIwphone/Communication/Realtime/GoogleWebRTCPeerConnection.swift`
- Create: `Tests/ForegroundPeerConnectionTests.swift`

**Interfaces:**
- Consumes: the pinned `stasel/WebRTC` binary package product `WebRTC` and signaling envelopes from Task 2.
- Produces: `ForegroundPeerConnection` plus a `GoogleWebRTCPeerConnection` implementation for offer, answer, ICE candidate, state callback, and close.

- [ ] **Step 1: Write state and idempotency tests against an injected engine boundary**

```swift
func testCloseIsIdempotentAndRejectsFurtherNegotiation() async throws {
    let engine = RecordingPeerEngine(offer: "literal-sdp")
    let peer = GoogleWebRTCPeerConnection(engine: engine)
    XCTAssertEqual(try await peer.createOffer(), "literal-sdp")
    peer.close()
    peer.close()
    XCTAssertEqual(engine.closeCount, 1)
    await XCTAssertThrowsErrorAsync { try await peer.createOffer() }
}
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Expected: failure because peer abstractions and package dependency are absent.

- [ ] **Step 3: Add the pinned binary package and implement the adapter**

Add `https://github.com/stasel/WebRTC.git` pinned to `151.0.1` in XcodeGen and link product `WebRTC` only to the `DJIwphone` target. Keep RTP/ICE/DTLS/SRTP/Opus framework-owned. The adapter owns `RTCPeerConnectionFactory`, one audio track/transceiver, SDP callbacks, ICE callbacks, and deterministic close behavior.

- [ ] **Step 4: Run full simulator tests and iphoneos Release build**

Expected: package resolves, all tests pass, and `DJIwphone.app` contains or statically links the WebRTC binary as reported by Xcode/`otool`.

- [ ] **Step 5: Commit**

```text
git add project.yml DJIwphone/Communication/Realtime/ForegroundPeerConnection.swift DJIwphone/Communication/Realtime/GoogleWebRTCPeerConnection.swift Tests/ForegroundPeerConnectionTests.swift
git commit -m "feat: add foreground WebRTC peer to DJIwphone"
```

### Task 6: Gate the single IPA artifact on structural and Mach-O validation

**Files:**
- Create: `scripts/validate_ipa.sh`
- Create: `Tests/validate_ipa_test.sh`
- Modify: `.github/workflows/build.yml`
- Modify: `README.md`

**Interfaces:**
- Consumes: a path to a generated IPA, expected app name, expected Bundle ID, and minimum IPA/executable sizes.
- Produces: nonzero exit for every invalid artifact; `ipa-validation.txt` containing sizes, plist identity, executable type, linked libraries, frameworks, and archive listing for a valid artifact.

- [ ] **Step 1: Write executable validator tests with invalid ZIP fixtures**

```bash
expect_failure empty_archive empty.ipa
expect_failure missing_executable missing-executable.ipa
expect_failure wrong_bundle_id wrong-bundle.ipa
expect_failure undersized_ipa tiny.ipa
```

Each fixture is created in a temporary directory and the test asserts the validator exits nonzero for the named reason. No source-text assertions are used.

- [ ] **Step 2: Run validator tests and confirm RED**

Run on macOS/Git Bash: `bash Tests/validate_ipa_test.sh`

Expected: failure because `scripts/validate_ipa.sh` does not exist.

- [ ] **Step 3: Implement the validator and single-artifact workflow**

The validator must use `unzip -t`, require exactly `Payload/DJIwphone.app`, parse `Info.plist` with `/usr/libexec/PlistBuddy`, require Bundle ID `com.kevin2xiaomao.qdc507communication`, locate `CFBundleExecutable`, require executable mode and a configurable minimum size, require `file` output containing `Mach-O 64-bit executable arm64`, inspect `otool -L`, resolve all `@rpath` non-system frameworks inside `Frameworks`, enforce an initial IPA size of at least 1 MiB, and write `ipa-validation.txt`.

The workflow must build `DJIwphone` only, assert exactly one Release `.app`, package `DJIwphone.ipa`, run the validator, and upload one artifact containing `DJIwphone.ipa` plus `ipa-validation.txt`. The upload step must use the default success-only condition.

- [ ] **Step 4: Run negative validator tests, full XCTest, simulator build, and iphoneos build**

Expected: all invalid fixtures are rejected; all Swift tests pass; generated real IPA passes validation.

- [ ] **Step 5: Commit**

```text
git add scripts/validate_ipa.sh Tests/validate_ipa_test.sh .github/workflows/build.yml README.md
git commit -m "ci: reject incomplete DJIwphone IPA artifacts"
```

### Task 7: Review, push, run GitHub Actions, and independently inspect the artifact

**Files:**
- Modify only if review or verification finds a concrete defect.

**Interfaces:**
- Consumes: all preceding commits and GitHub Actions workflow dispatch.
- Produces: a pushed DJIwphone main branch and one independently verified DJIwphone artifact.

- [ ] **Step 1: Run local static checks**

Run: `git diff --check origin/main...HEAD`, `rg -n "@main" DJIwphone`, and inspect `project.yml` to confirm exactly one application target and the original Bundle ID.

- [ ] **Step 2: Request code review and resolve every Critical or Important finding**

Review against the design spec, especially credential handling, CallKit UUID/action correctness, media cleanup, single-target identity, and validator bypasses.

- [ ] **Step 3: Run fresh full verification**

Run validator negative tests and the complete macOS Xcode test/build/package/validate sequence. Record exact test counts and artifact sizes.

- [ ] **Step 4: Push the reviewed commits to `origin/main` and dispatch the workflow**

Run: `git push origin main` then `gh workflow run build.yml --repo kevin2xiaomao-max/DJIwphone --ref main`.

- [ ] **Step 5: Wait for the triggered run and require success**

Use the exact new run ID from `gh run list`, then `gh run watch <run-id> --exit-status` and `gh run view <run-id> --log-failed` if any job fails.

- [ ] **Step 6: Download and inspect the uploaded artifact independently**

Download to a fresh temporary directory with `gh run download <run-id>`. Confirm exactly one artifact, print its byte size and SHA-256, run `scripts/validate_ipa.sh` again, and compare `ipa-validation.txt` with the downloaded archive contents.

- [ ] **Step 7: Report evidence**

Report commit SHA, workflow URL/run ID, job conclusion, artifact name, exact byte size, SHA-256, Bundle ID, executable byte size/type, and framework inventory. Do not claim install or launch success without a real signed-device launch test; report cloud build and structural validation precisely.
