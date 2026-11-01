# Rove voice prototype

A floating Rove character connected to local Apple speech recognition, Apple's on-device Foundation Model, and Gradium Phonon 0.4.0 speech. Desktop actions are disabled. This app is separate from the installed agent-desktop CLI and the earlier Aural Assistant app.

## Current interaction

Press the character's Talk button to listen. The microphone closes after a completed utterance. Rove generates a short local reply and streams Gradium audio. Press Talk while it is thinking or speaking to cancel and listen again. Escape and the menu's Stop action stop listening and playback. Listening times out after 35 seconds. The character supports dragging and inertial movement.

Double-tap activation is wired to the same interaction but stays disabled without a measured calibration profile. The profile is loaded from `~/Library/Application Support/Rove/tap-profile.json`; it must contain a finite `threshold` between 0.001 and 0.2 and `keyboardVerified: true`. Do not manufacture a profile to bypass calibration.

The detector waits for two distinct impacts, rejects additional impacts in the same gesture, and suppresses activation during keyboard activity and for 650 milliseconds afterward. Its delayed decision also lets a subsequent keypress cancel a candidate gesture. It reads elapsed keyboard activity, not keys or text. These rules pass synthetic tests. An initial personal calibration detected five training pairs and three validation pairs with no events in the recorded typing sample. Longer-term false-trigger rates and ordinary desk movement remain unverified.

Voice interruption through the microphone while Rove speaks is not enabled in this version. Tap or Talk interrupts instead. This prevents the assistant's speaker output from entering recognition until acoustic echo cancellation is validated.

## Build

Requires macOS 26 or newer, Swift tooling, local Apple model availability, and downloaded Phonon Core ML models. From this directory:

```sh
zsh build.sh
```

Set `ROVE_MODELS_SOURCE` to the directory containing the Phonon Core ML bundle. The default reuses the existing personal Aural Assistant model directory. Build output is `build/Rove.app`. The first build downloads the pinned Gradium package and binary dependency; normal conversation has no configured cloud fallback. Microphone and Speech Recognition permission are requested only when Talk is used.

## Checks

From the repository root:

```sh
xcrun swiftc apps/mist-desktop/Sources/TapDetector.swift apps/mist-desktop/Tests/DetectorTests.swift -o /tmp/mist-detector-tests
/tmp/mist-detector-tests
```

The built executable accepts `--voice-self-test`. It generates audio silently, checks finite streaming samples, cancels after three chunks, and verifies that a replacement stream receives no stale completion. It does not open the microphone or play audio.

`Tests/Capture.swift` records bounded motion samples and keyboard recency to a specified local JSON file. `Tests/Replay.swift` replays that file through the detector. Record separate typing, deliberate-pair, and ordinary-movement samples before accepting a profile. Temporary recordings and calibration reports must stay outside version control.

## Reused components and limits

The character renderer and local speech components were copied from the user's personal `aural-assistant` working copy. The renderer's old Jev network paths are disabled through the native bridge, a no-network content policy, and blocked non-file navigation. It does not run the old Jev proxy. Gradium's package remains a pinned dependency; existing installed Phonon models are reused.

The motion report layout follows the public research at https://github.com/olvvier/apple-silicon-accelerometer. Sensor properties are restored on normal shutdown; crash and sleep/wake recovery still need validation. The prototype uses a default of zero when a driver property was absent before activation.

The local model receives a bounded accessibility-text excerpt from the last external app, through a bundled agent-desktop snapshot command. It has no action tools. Screen text is treated as untrusted data. Access failures are handled with a fixed message rather than asking the model to invent permission instructions. The excerpt may be incomplete and does not describe images.

The Companion menu offers Pixel Face, the recovered white handheld with sticky hand, and Orbloom; selection persists. The handheld reuses the original Metal shader and its four-pass rendering. Its expressions reflect conversation state; its original interaction physics have not all been ported. Gradium starts loading at app launch; the reply text appears at first audio scheduling rather than before synthesis. Audible latency still needs user validation.

## Development signing and desktop reader

Set `ROVE_SIGNING_IDENTITY` to a development signing identity, or save its name in an untracked `.signing-identity` file in this directory. Otherwise the build uses ad-hoc signing. A stable development identity helps macOS retain grants between builds. Signing material and personal calibration are not included in the repository.

Set `ROVE_AGENT_DESKTOP_BIN` to the installed agent-desktop package's native `bin` directory. The current fallback checks the existing local Node installation. The build copies the engine and helper into the app; at runtime Rove installs them into its private support folder because the executable did not return output from Resources. Reading a dense app currently allows up to ten seconds. A live test identified the open Computer Use/JEV post, but surrounding host-window context still leaks into explanations.

The white handheld uses the original lid geometry. Its neutral mode keeps pupils and lids dark, limits lens reflections over dark areas, and applies extended-range brightness to the case, handle, hand, and white display areas. Actual HDR appearance depends on display headroom and cannot be assessed from an SDR screenshot alone.

## Casting Room import

Scout is available under Companion → Scout · Casting Room. Its original survey-rover GLSL body and face shaders were extracted from the collection's offline source download, with provenance hashes retained in `Resources/scout-shaders.js`. `scout-renderer.js` reuses the collection's WebGL renderer. The Rove bridge maps listening, thinking, and speaking to the authored states. The import uses a transparent silhouette and the original rounded Rove controls.

This first Scout import is SDR WebGL. Native HDR needs a shader adaptation; the existing white handheld uses native Metal HDR. A WebGL shader, recorded turn sprites, and a mesh have different import requirements. The collection itself is at https://companion-casting-room.britonbaker.chatgpt.site/.

Idle face animation is capped around 20 frames per second, active animation around 30. Scout uses a 288 × 252 cached render target, about 12 idle frames per second and 25 active frames per second. Native eye geometry remains unchanged; dark neutral lid shades and lens masking prevent gray lids and bright lens bands. Body/handle/hand highlights use extended-range brightness on the Metal handheld. Only the selected companion is mounted. Keyboard-recency system queries are cached for 20 milliseconds while motion samples retain their original timing. These changes reduce scheduled work; no whole-app CPU or power reduction percentage has been established.

## Scout driving prototype

Scout now uses a 62-degree overhead camera on the original shader geometry. Guide him by dragging; the native drive controller steers and brakes toward the destination instead of applying the floating companion's release momentum. The menu offers **Drive Scout in a small loop** and **Park Scout**. Stop, listening, switching companions, and quitting cancel the route. Movement stays inside the current screen's visible frame.

Wheel tread and hub rotation follow traveled distance. Two forward lamps and soft cones rotate with the heading, while body and wheel-contact shadows sit beneath the transparent rover. These are screen-space lighting overlays, not changes to other apps' pixels or a physical light simulation. Scout remains SDR; the handheld's native HDR renderer is separate.

`Tests/RoverDriveTests.swift` checks arrival, braking, speed and turning limits, parked behavior, traveled distance, and a bounded time step after a stall. The live app's loop was visually checked at changing headings with aligned lights and shadow.
