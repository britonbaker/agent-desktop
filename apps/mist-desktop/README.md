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

Scout now reuses that signed-distance geometry in native Metal, with a linear RGBA16Float surface and an extended-range layer. No mesh conversion is required. The authored GLSL remains the source for geometry and materials; `scripts/compile-scout.py` generates `Resources/scout.metal` using Khronos glslang and SPIRV-Cross. The WebGL renderer remains a fallback when Metal initialization fails. A recorded turn sprite still has different import requirements. The collection itself is at https://companion-casting-room.britonbaker.chatgpt.site/.

Idle face animation is capped around 20 frames per second, active animation around 30. Native Scout uses a 600 × 760 render target, 12 idle frames per second and 30 during driving or interaction. Its WebGL fallback uses a 288 × 252 target. The WebGL context is not allocated when native Scout is active. Native eye geometry remains unchanged; dark neutral lid shades and lens masking prevent gray lids and bright lens bands. Body/handle/hand highlights use extended-range brightness on the Metal handheld. Only the selected companion is mounted. Keyboard-recency system queries are cached for 20 milliseconds while motion samples retain their original timing. These changes reduce scheduled work; no whole-app CPU or power reduction percentage has been established.

## Scout driving prototype

Scout rests flat in a top-down survey view. Position and hinge angle add subtle parallax, capped at seven degrees from overhead. Display dimensions set physical scale: one model unit is 11 mm, about 40 percent smaller than the earlier version. Moving him across the screen changes perspective without stretching his geometry. Guide him by dragging; the native drive controller steers and brakes toward the destination instead of applying the floating companion's release momentum. The menu offers **Drive Scout in a small loop** and **Park Scout**. Stop, listening, switching companions, and quitting cancel the route. Movement stays inside the current screen's visible frame.

Wheel tread and hub rotation follow traveled distance and tire radius. Two emissive lamps attach to the upper front edge of the chassis. Ground-plane cones, body shadow and wheel-contact shadows use the same projection. This is a visual lighting approximation; it does not change other apps' pixels. Clicking Scout lifts him and turns him toward you, with the shadow fading as wheel contact breaks. Talk, the explanation command and double-tapping keep the survey view and roof readout visible. Stop returns him to the display. Reduced Motion snaps between these poses.

`Tests/RoverDriveTests.swift` checks arrival, braking, speed and turning limits, parked behavior, traveled distance, and a bounded time step after a stall. The live app's loop was visually checked at changing headings with aligned lights and shadow.


## Scout viewpoint and HDR

**Scout viewpoint** offers 45, 55 and 70 cm viewing distances. These are assumed head positions, not camera-based tracking. The renderer keeps the rover's ground footprint fixed as distance changes.

On a MacBook with a readable hinge sensor, **Follow lid angle (experimental)** is enabled by default. A read-only HID feature report is sampled at most four times per second. Hinge input is attenuated and capped with position parallax, so the view stays top-down rather than revealing a large side or rear profile. The rover does not rotate to keep his face visible while parked. This applies only to the built-in display; external displays use the fixed view. The setting persists, and unavailable sensors leave a fixed viewpoint. This private hardware interface is not guaranteed on every Mac. A live read returned 89 degrees on the development Mac; physical tilt behavior still needs user review.

Native rendering preserves linear material values and emits lamp highlights above SDR white, limited to the display's current EDR headroom. An offscreen test confirmed nonempty geometry and channels above 1.0. This proves the HDR signal, not perceived brightness on the physical panel. SDR screenshots cannot establish that appearance.

Run `build/Rove.app/Contents/MacOS/Rove --scout-self-test` to compile and render Scout offscreen without microphone or audio. Compile `Sources/ScoutCamera.swift` with `Tests/ScoutCameraTests.swift` for physical scale, off-axis eye, distance and hinge checks. The existing drive tests cover steering and braking. A single development offscreen render took about 1.2 ms of GPU time; this is not a whole-app CPU or power benchmark.


## Roof status and page explanations

Scout's recessed roof display uses amber pixel lettering like his face. It shows READY, LISTEN, THINK, TALK or ERROR from the native conversation state. Routine thought bubbles and the old browser microphone diagnostics are hidden. Errors that need attention can still show above him. The existing Talk and type controls remain available, and the character button exposes its state to accessibility tools. **Show last reply** (Command-R) opens the full spoken answer in an accessible native dialog.

**Explain front window** (Command-E) reads the last external app through the same local conversation pipeline. The reader prioritizes embedded web pages and main content before browser controls and host sidebars, while retaining the bounded excerpt and protected-field exclusions. Ordinary greetings no longer require a successful screen read. Screenshot vision and desktop action tools remain disabled; image-only content is still unavailable.


Screen readouts currently use the local model to choose up to three source lines, then speak those exact lines. Invalid indexes and duplicates are discarded; failed selection falls back to the first readable lines. This avoids the unsupported page capabilities observed in free-form local summaries. It is a grounded readout, not a verified visual interpretation or an open-ended explanation. Ordinary conversation remains free-form and local.
