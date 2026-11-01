# Rove voice prototype

A floating Rove character connected to local Apple speech recognition, Apple's on-device Foundation Model, and Gradium Phonon 0.4.0 speech. Rove can explain the front page using local Qwen vision and accessible text, list running apps and open or switch to a requested installed app. It can also click accessible controls, focus fields, type requested text and scroll through the bundled agent-desktop engine, with guarded confirmation for consequential actions. This app is separate from the installed agent-desktop CLI and the earlier Aural Assistant app.

## Current interaction

Press the character's Talk button to start a conversation. The microphone closes after each completed utterance while Rove reasons and streams Gradium audio. After playback and a 350 ms tail, listening resumes for a follow-up question. Press Talk while it is thinking or speaking to cancel and listen again. Escape, “end conversation” and the menu's Stop action end the conversation and stop listening and playback. Listening times out after 35 seconds. The character supports dragging and inertial movement.

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

The local model receives a bounded accessibility-text excerpt from the last external app, through a bundled agent-desktop snapshot command. App switching uses AppKit; guarded control actions use the bundled agent-desktop engine. Screen text is treated as untrusted data. Access failures are handled with a fixed message rather than asking the model to invent permission instructions. The excerpt may be incomplete and does not describe images.

The Companion menu offers Pixel Face, the recovered white handheld with sticky hand, and Orbloom; selection persists. The handheld reuses the original Metal shader and its four-pass rendering. Its expressions reflect conversation state; its original interaction physics have not all been ported. Gradium starts loading at app launch; the reply text appears at first audio scheduling rather than before synthesis. Audible latency still needs user validation.

## Development signing and desktop reader

Set `ROVE_SIGNING_IDENTITY` to a development signing identity, or save its name in an untracked `.signing-identity` file in this directory. Otherwise the build uses ad-hoc signing. A stable development identity helps macOS retain grants between builds. Signing material and personal calibration are not included in the repository.

The build prefers this fork's `target/release/agent-desktop` and `agent-desktop-macos-helper` binaries when both exist. Build them from the repository root with `cargo build --release -p agent-desktop -p agent-desktop-macos --bin agent-desktop --bin agent-desktop-macos-helper`. Set `ROVE_AGENT_DESKTOP_BIN` to override their directory; the fallback checks the existing local Node installation's native package binaries. The build copies the engine and helper into the app; at runtime Rove installs them into its private support folder because the executable did not return output from Resources. Reading a dense app allows up to ten seconds. Window selection prefers the accessibility-focused window over small browser utility windows; one selected page supplies both text and image bounds.

The white handheld uses the original lid geometry. Its neutral mode keeps pupils and lids dark, limits lens reflections over dark areas, and applies extended-range brightness to the case, handle, hand, and white display areas. Actual HDR appearance depends on display headroom and cannot be assessed from an SDR screenshot alone.

## Casting Room import

Scout is available under Companion → Scout · Casting Room. Its original survey-rover GLSL body and face shaders were extracted from the collection's offline source download, with provenance hashes retained in `Resources/scout-shaders.js`. `scout-renderer.js` reuses the collection's WebGL renderer. The Rove bridge maps listening, thinking, and speaking to the authored states. The import uses a transparent silhouette and the original rounded Rove controls.

Scout now reuses that signed-distance geometry in native Metal, with a linear RGBA16Float surface and an extended-range layer. No mesh conversion is required. The authored GLSL remains the source for geometry and materials; `scripts/compile-scout.py` generates `Resources/scout.metal` using Khronos glslang and SPIRV-Cross. The WebGL renderer remains a fallback when Metal initialization fails. A recorded turn sprite still has different import requirements. The collection itself is at https://companion-casting-room.britonbaker.chatgpt.site/.

Idle face animation is capped around 20 frames per second, active animation around 30. Native Scout uses a 600 × 760 render target, 12 idle frames per second and 30 during driving or interaction. Its WebGL fallback uses a 288 × 252 target. The WebGL context is not allocated when native Scout is active. Native eye geometry remains unchanged; dark neutral lid shades and lens masking prevent gray lids and bright lens bands. Body/handle/hand highlights use extended-range brightness on the Metal handheld. Only the selected companion is mounted. Keyboard-recency system queries are cached for 20 milliseconds while motion samples retain their original timing. These changes reduce scheduled work; no whole-app CPU or power reduction percentage has been established.

## Scout driving prototype

Scout rests flat in a top-down survey view. Position and hinge angle add subtle parallax, capped at seven degrees from overhead. Display dimensions set physical scale: one model unit is 11 mm, about 40 percent smaller than the earlier version. Moving him across the screen changes perspective without stretching his geometry. Guide him by dragging; the native drive controller steers and brakes toward the destination instead of applying the floating companion's release momentum. The menu offers **Drive Scout in a small loop**, **Let Scout wander** and **Park Scout**. Stop, listening, switching companions, and quitting cancel the route. Movement stays inside the current screen's visible frame.

Wheel tread and hub rotation follow traveled distance and tire radius. Two emissive lamps attach to the upper front edge of the chassis. Ground-plane cones, body shadow and wheel-contact shadows use the same projection. This is a visual lighting approximation; it does not change other apps' pixels. Clicking Scout lifts him and turns him toward you, with the shadow fading as wheel contact breaks. Talk, the explanation command and double-tapping keep the survey view and roof readout visible. Stop returns him to the display. Reduced Motion snaps between these poses.

`Tests/RoverDriveTests.swift` checks arrival, braking, speed and turning limits, parked behavior, traveled distance, and a bounded time step after a stall. The live app's loop was visually checked at changing headings with aligned lights and shadow.


## Scout viewpoint and HDR

**Scout viewpoint** offers 45, 55 and 70 cm viewing distances. These are assumed head positions, not camera-based tracking. The renderer keeps the rover's ground footprint fixed as distance changes.

On a MacBook with a readable hinge sensor, **Follow lid angle (experimental)** is enabled by default. A read-only HID feature report is sampled at most four times per second. Hinge input is attenuated and capped with position parallax, so the view stays top-down rather than revealing a large side or rear profile. The rover does not rotate to keep his face visible while parked. This applies only to the built-in display; external displays use the fixed view. The setting persists, and unavailable sensors leave a fixed viewpoint. This private hardware interface is not guaranteed on every Mac. A live read returned 89 degrees on the development Mac; physical tilt behavior still needs user review.

Native rendering preserves linear material values and emits lamp highlights above SDR white, limited to the display's current EDR headroom. An offscreen test confirmed nonempty geometry and channels above 1.0. This proves the HDR signal, not perceived brightness on the physical panel. SDR screenshots cannot establish that appearance.

Run `build/Rove.app/Contents/MacOS/Rove --scout-self-test` to compile and render Scout offscreen without microphone or audio. Compile `Sources/ScoutCamera.swift` with `Tests/ScoutCameraTests.swift` for physical scale, off-axis eye, distance and hinge checks. The existing drive tests cover steering and braking. A single development offscreen render took about 1.2 ms of GPU time; this is not a whole-app CPU or power benchmark.


## Roof status and page explanations

Scout's recessed roof display uses amber pixel lettering like his face. It shows the current conversation or driving activity from the native state. Routine thought bubbles and the old browser microphone diagnostics are hidden. Errors that need attention can still show above him. The existing Talk and type controls remain available, and the character button exposes its state to accessibility tools. **Show last reply** (Command-R) opens the full spoken answer in an accessible native dialog.

**Explain front window** (Command-E) reads the last external app through the same local conversation pipeline. The reader prioritizes embedded web pages and main content before browser controls and host sidebars, while retaining the bounded excerpt and protected-field exclusions. Ordinary greetings no longer require a successful screen read. When the optional local vision installation is present, Rove captures the same window and crops it to the selected embedded page. Screen Recording permission is required for images; without it, the reply identifies that it is using readable text. App switching uses a separate action allowlist.


With local vision installed, Qwen3.5-4B receives the window image, source identity and bounded accessibility excerpt. Apple Foundation Models remains responsible for conversation and action routing. Without the vision installation, the Apple screen-summary path checks numbered source references and a second generation reviews support for its claims. Neither path guarantees correctness; live Apple-only tests produced unsupported descriptions, which motivated the image model.

## Natural desktop requests

`DesktopAgent.swift` classifies the current spoken or typed request using Apple's local model and a catalog of running and installed apps. Examples include “bring Safari up,” “take me to Finder,” “what am I looking at here?” and “which applications are open?” Ordinary conversation uses a separate conversational response. Previous foreground-app context and the most recent verified switch support “go back” when the target can be resolved.

Only a uniquely resolved installed-app ID can reach the switch executor. The chosen app must also be named in the trusted user request, match a supported name alias, or match the recorded previous app for a back request. Screen content cannot authorize an action; the action planner receives it as untrusted context after the user requests a task. App activation uses a validated bundle URL from the running process, Launch Services registration or the standard application folders, with Launch Services' existing-instance configuration. Registered apps outside /Applications, including Discord's updater-managed bundle, are supported. A closed app can be launched; its returned process ID must become the foreground process. It does not pass user text as a path, shell command or launch argument. Rove confirms the foreground process before announcing success; uncertain results are reported without an automatic repeat. Cancellation is checked before mutation and while waiting for verification.

The app catalog and switching use AppKit because the installed agent-desktop `list-apps` returned `application_inventory_unstable` during development. Window content and accessible control actions come from the bundled agent-desktop engine. No changes were made to the Rust core. Each action uses a fresh window snapshot and an exact element reference, followed by readback. The loop stops after eight planning steps, a foreground-window change, a tool failure or uncertain verification; it does not automatically repeat an uncertain action. “Next field” uses semantic focus navigation. Other shortcuts have a restricted allowlist and stop if they cannot be verified. Unsupported controls remain unavailable.

Destructive, submission and overwrite actions require two separate replies: **confirm action**, then **do it now**. Rove names the control, application, window and available selection context. Confirmation expires after 120 seconds, is consumed once, and is cancelled if the observed context changes. Stop and desktop locking cancel pending actions. Secure fields, terminal/script tools and system privacy grants remain manual. Typing must use text present in the user's request, or an explicitly requested composition with a specified app or field; page text cannot authorize a payload or destination.

`--desktop-self-test` exercises the real local model on natural routing, negated requests, quoted screen instructions and guarded action requests, previous-app resolution, compound switch-and-explain requests, evidence checks and a screen-summary fixture. It does not switch apps, open the microphone or play audio. Run it under a network-denying sandbox to verify this path has no cloud dependency:

```sh
sandbox-exec -p '(version 1)(allow default)(deny network*)' build/Rove.app/Contents/MacOS/Rove --desktop-self-test
```

Follow-up listening and activation need separate live checks; the silent self-test does not establish physical microphone behavior or a successful app switch. A live UI check observed listening resume after a spoken reply from a typed turn in an active conversation, and Escape returned the app to idle. Spoken interruption during playback still requires tap or Talk because the microphone remains closed during speech.


Live development checks brought Finder forward from a natural typed request and obtained a conversational explanation of Finder's accessible contents. Foreground acknowledgment was verified in the runtime before speech. Physical speech-recognition accuracy still requires user validation; typed requests exercise the same routing and action layer without establishing recognition accuracy.


## Idle movement and compact controls

Scout takes short idle drives around the spot where you placed him, with pauses between trips. Idle speed is limited to 20–30 points per second with slower acceleration than dragging. The existing steering, braking, tread rotation and contact shadows are reused. Destinations remain within the current display's visible frame. Dragging establishes a new home area.

Wandering pauses while the pointer is near Scout or his controls, while the text input is open, during a conversation, while a modal dialog is open, and when Reduce Motion is enabled. **Park Scout** disables automatic wandering; **Let Scout wander** turns it back on. That preference persists. The existing rounded control is now positioned just below the smaller rover, with compact button sizing and a circular, inset close affordance inside the expanded text capsule.


Live window-position sampling observed ten distinct positions during a 15-second idle check, and one position during a separate 15-second check with the text input open and the pointer elsewhere. The minimized and expanded capsules were visually reviewed. Transparent window padding lets mouse clicks pass through to the app underneath; mouse interaction regions surround the rover and controls.


Page capture reads to depth 30 so content nested inside a browser hosted by another app can reach the model. Embedded page titles remain ahead of article content, and articles are read before long navigation trees. Numeric heading levels are omitted from spoken text. A real capture of the GitHub Rove folder reproduced the shallow-navigation failure; after the fix, the local model identified it as the GitHub repository page for the Rove voice prototype. `--screen-file-test PATH` runs this pipeline against a local snapshot JSON without microphone, playback or desktop actions. Its diagnostics print the proposed answer, source references and review result, so use it only with snapshots you intend to inspect locally.

## Optional local vision

Run `python3 vision/setup-local-vision.py` from this directory to install the pinned MLX runtime and Qwen3.5-4B 4-bit model under `~/Library/Application Support/Rove/Vision`. The installer records absolute paths in `~/Library/Application Support/Rove/local-vision.json`. The model requires about 3.1 GB plus its Python runtime; the installer checks available space before a fresh installation. Weights and machine-specific configuration are not part of the repository.

At runtime, Rove owns a bearer-authenticated server bound to a random loopback port. A macOS sandbox denies external networking; Hugging Face and Transformers offline modes prevent runtime downloads. The server exits when its owning Rove process exits. Its MLX cache is capped at 256 MiB, with an 8 GiB allocation limit. Normal operation keeps screenshots in memory and suppresses server logs. This integration returns a completed explanation before speech begins; vision-to-speech streaming is not implemented.

`--vision-front-test` captures and explains the current front page without microphone, audio or desktop actions. `--vision-image-test PATH --source-window TITLE` tests a supplied image and prints local diagnostics. The optional `--save-test-image PATH` on the front test writes a diagnostic screenshot only when explicitly requested. Do not commit screenshots containing private content. A captured Scout editor image was correctly described as a rover customization page in a cold test taking about 17 seconds. That single result does not establish general screen accuracy or live voice latency.

A full capture test identified a ChatGPT image-editing conversation from its current Chrome page in about 11 seconds of local vision time. Page-reader tests, the Apple routing self-test, the native build and signature verification passed. Physical double-knock speech input and the new vision reply still need a combined user test.

## Updated Scout and knock greeting

Scout uses the current Casting Room shader retrieved on 2026-10-31, with its revised undertray, wheel inserts, rotating tread and hub details, original pixel face, roof navigation display and folding lightbar. `Resources/scout-source.json` records the downloaded archive and shader hashes. The desktop uses the authored studio geometry, shadow, tire-lug pattern and reflector distributions in native Metal with EDR output. Beam intensity is reduced and the receiving floor is transparent so the page remains readable. Each tire contact leaves a mark at a fixed desktop position. Marks keep their position and orientation through Scout’s movement and turns, fade independently and disappear after 1.1 seconds. A separate click-through receiver draws them below Rove’s body, shadow and light pass. Only contacting tires deposit marks; spinning in place and large position jumps create no sliding or connecting trail.

Wheel angle follows desktop travel distance, including idle wandering and the greeting approach. A double knock that begins or interrupts into a conversation also starts an edge greeting: turn toward the nearest side bezel, drive there at an eager pace, then lift the front wheels only after reaching the bezel, hold the climbed pose through listening, reasoning and speech, then lower and back away 16 points when the conversation ends. There is no lift during the approach or a wheelie in the middle of the screen. Approach time scales with distance; listening starts independently. A spoken request does not cancel the approach. Stop, dragging, companion changes and Reduce Motion cancel the motion; Reduce Motion suppresses it entirely. The transparent panel may extend beyond the side edge, while the rover and its controls remain visible.

The Rove menu includes **Preview Scout’s edge greeting**, which runs the same motion without microphone input. `--scout-self-test --greeting-preview /tmp/rove-scout-preview` renders the rest, lift and wheelie poses plus two fixed-time driving frames. The driving comparison verifies that changing travel distance changes rendered wheel details. `ScoutGreetingTests.swift` checks the nearest edge, lift only after arrival, maintained edge contact, controlled backdown and safe placement and displays with offset coordinates. Native build, signature, motion tests, offscreen HDR rendering and the live preview were checked; physical knock activation of the new greeting still needs user review.

## Double Shift and Scout studio

Tap and release Shift twice within about 0.8 seconds to start or interrupt into the same edge approach and listening used by the case knock. A Shift held for over 0.6 seconds, modifier chord or intervening typing cancels the candidate gesture. A standalone pair works immediately after typing; it does not require the physical-knock detector’s quiet period. The shortcut observes modifier transitions and keyboard-activity timing, without recording typed text. Global activation uses the existing Accessibility grant; it does not need a calibrated motion sensor. Repeated activation restarts listening while preserving an existing edge climb. Escape and Stop end the conversation; the Talk button can still toggle listening off.

**Scout studio** offers the authored Factory, Rally twins, Ribbon and Survey projector optics; the Inset navigator, Mast gauge, Scanline and Rangefinder roof kits; Titanium, Signal Red, Lunar Rover and Cobalt Blue paint; and Original, Binocular, Waypoint, Sweep and Buddy faces. Lights, the folding lightbar, ground shadow and tire tracks can be toggled separately. Choices persist locally. The complete studio fragment is preserved in `Resources/scout-study-source.glsl`; its optional 3D speech-cloud source is retained but not enabled in the desktop renderer. The local build imports no live site dependency.

**Knock diagnostics…** shows sensor sample count, last-sample age, accepted pairs, threshold, shortcut-monitor status and twelve recent motion strengths with time since keyboard activity. It retains no typed text or audio. This separates a missing sensor stream from a threshold or typing-suppression problem. The right palm-rest knock still needs a live user check; the original corner profile has not been loosened without measurement.

The receiver reuses the source `scoutTreadLug` function to create two cached front/rear stamp textures. It draws only the bounded region containing live marks, caps history at 2,000 marks and stops its fade timer when empty. No track history is written to disk. `TireTrackTrailTests.swift` checks fixed desktop positions through movement and turns, independent expiry, four tire paths, and lifted/spinning/repositioned behavior. The existing preview command also writes `desktop-tracks.gif`, a rendered composite using the same stamp drawing and body-over-tracks order; this is an offscreen proof rather than a recording of the live desktop.

## Recent app visits

Rove keeps the latest 40 foreground app visits locally in `~/Library/Application Support/Rove/recent-apps.json`. It records app bundle ID, name and visit time, without window text, URLs or screenshots. Consecutive duplicates and Rove’s own controls are excluded; returning to an earlier app counts as another visit. The current app is not counted as a previous visit. History survives a restart.

Say “switch to the app we were just using,” “take me to three apps ago,” or “go back three apps and explain the page.” Common page, named-app and app-history requests take a direct validated path. Other phrasing uses Apple’s local router, with a separate authorization review before a generated switch. The executor independently checks the history offset against the spoken reference, resolves the saved bundle ID to one installed app and verifies it came forward. Closed installed apps can be opened; missing history or an unavailable app produces an explanation instead of a guessed target. Prior visits are captured before inference so switching apps during reasoning cannot silently redirect the request.

`AppTimelineTests.swift` covers duplicate exclusion, repeat visits, ordinal references, bounded storage and a persistence roundtrip. The desktop self-test adds natural history commands and a negated history request. Actual speech recognition and live app activation remain separate runtime checks.

After a verified app switch, Scout drives toward that app’s readable Dock tile on the same display. If the tile is unavailable, he uses the actual destination window’s upper-left area. Reduced Motion keeps him parked; an unavailable position or a destination on another display also leaves him parked. He speaks the selected app name and history offset. **Show last reply** includes the request heard, kept in memory for the current session.

Scout’s roof glass shows the existing authored face ink while listening, thinking, speaking or driving toward an app. When his front face tilts upward, the roof returns to its readout so both screens do not show his face together. This reuses the selected face design and expression on the physical display, with the existing Metal renderer and extended-range color path. The normal readout also returns after the conversation and movement finish.

The display perimeter has an invisible rounded floor-to-wall transition. Four tire contacts determine body pitch, bank and rise; an angled approach raises the nearest wheel first. Interior movement stays flat. The native camera, lights and body share that contact transform, and banked wheels do not deposit flat desktop tracks. Reduced Motion disables the wall tilt. `ScoutWallTests.swift` checks mirrored edges, angled entry, corners, offset displays and continuous approach.

`--voice-audition PATH.wav` writes a clean local Gradium sample without opening the microphone or playing audio. `python3 scripts/make-voice-auditions.py --output /absolute/output/folder` creates three local robot-character previews using that sample and ffmpeg. These audition files do not change the live voice; selection and integration are separate.

## Voice and tap sounds

Rove explicitly selects the bundled Gradium **Miles** US English voice. **Speaking voice · US English** also offers Micah and Trevor, with the choice saved locally. The original implicit selection used the alphabetically first voice, Alfie (UK English). Voice changes cancel the current conversation; the next reply conditions the same local model on the selected voice. Speech and chirps share a small local speaker effect: mostly dry audio with a quiet resonant delay and the same flutter frequency. State continues across streamed chunks, without buffering a complete reply, pitch-shifting English or calling an external speech service. **Show last reply** reports the voice used by the last synthesis, separately from the selected setting.

Summoning him by a case knock, double Shift or the Talk control plays one of three original 430 ms robot gestures. They are synthesized locally from gliding harmonics, moving vowel-like resonances and a quiet motor undertone. The microphone opens 40 ms after the gesture ends, avoiding recognition of the cue itself. Stop or another summon cancels a pending cue and microphone start. Follow-up listening does not replay the cue. **Robot tap sounds** turns them off; **Preview robot tap sound** plays a cue with the microphone off.

`--character-voice-previews /absolute/output/folder` writes the three tap cues and Micah/Miles speech samples without playback or microphone access. `RobotChirpTests.swift` checks waveform headroom, fades, variation and WAV export. `--voice-self-test` verifies the selected bundled voice, streaming, cancellation and a replacement reply. Both preview generation and voice tests can run with `sandbox-exec -p '(version 1)(allow default)(deny network*)'` prefixed to the executable.

`--app-catalog-test Discord` checks installed-app resolution without opening the app. `RobotVoiceEffectTests.swift` checks stream-boundary continuity, headroom, preserved signal and fresh state between replies.

## Guarded action check

The disposable native fixture contains two fields, a scrolling list and test buttons. Its Delete button changes a dummy counter; it never deletes files. Close and reopen the fixture before each run so its draft is empty and counter is zero. From the repository root:

```sh
zsh apps/mist-desktop/scripts/build-action-fixture.sh
open /tmp/RoveActionFixture.app --args /tmp/rove-action-fixture-state.json
sandbox-exec -p '(version 1)(allow default)(deny network-outbound (remote ip "*:*"))' apps/mist-desktop/build/Rove.app/Contents/MacOS/Rove --actions-self-test /tmp/rove-action-fixture-state.json
```

This live check uses Apple's local model and the bundled CLI to click, type, navigate fields and scroll, with independent fixture readback. It checks two-stage confirmation, approval replay rejection and cancellation after a selection change. The sandbox blocks outbound IP networking while allowing the CLI's local Unix socket. It does not establish microphone recognition accuracy or compatibility with every app.

Scout's ground lighting uses a separate transparent, click-through EDR receiver beneath the body and above the desktop tire tracks. It spans 1,000 points and fades radially before its edge, allowing authored headlight beams to extend beyond the small body window. Shadow rays trace the existing Scout geometry toward a fixed desktop light; turning the rover does not turn that light. Offscreen tests check four headings, beam extent, edge fade and GPU timing. Actual HDR appearance still depends on display headroom.
