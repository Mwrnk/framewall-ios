# Framewall

A portfolio and gallery app for painters. The premise: every other app treats a
painting as a file — Framewall treats it as **an object in a place**. A post is a real
3D framed painting floating in white space with real shadows. A profile is a room you
curate. Uploads declare physical dimensions in cm, so a work has a true size
everywhere it appears.

## Read this first

**Figma is the source of truth for anything visual, and the target is 1:1
pixel-perfect.** Before implementing any screen or component, call
`get_design_context` on its node — loading the `figma-design-to-code` skill first, it
is a mandatory prerequisite, plus `figma-swiftui` for the SwiftUI mapping.

- File `5qg6TLlXnbQXksbYyn1otP` ("Formula"), page `iOS` = node `98:2`.
- Per-screen and per-component node IDs are listed in `code.md` §9.
- Figma blur is a **diameter**; SwiftUI's shadow `radius` and CSS `drop-shadow` both
  take the sigma, so halve it. CSS `box-shadow: inset` is quoted 1:1 against Figma,
  so halve that too when moving it to SwiftUI.
- Caveat from the designer: Apple kit components have their text layers hidden with
  custom text overlaid. Read the overlay text nodes, not the component labels.

**`framewall/code.md` is the build spec** — authoritative for intent, build order,
screen inventory, and constraints. It is **not** authoritative for measured visual
values: the numbers it quotes are simplified, and several are simply wrong against
the file (see the drift table below). Use it to know *what* to build and *why*;
use Figma for *what it looks like*.

`~/.claude/papercut.md` is the shared log of tooling friction. Read it when something
fails mysteriously; append to it when you lose time.

## Where the spec is already out of date

`code.md` lists these as open. They are now settled in the project — trust the project,
not the doc:

| `code.md` says | Actual |
|---|---|
| Oak gradient `#D6B489 → #A8815A`, two stops | Three stops at 135°: `#DCC199 → #C9A97C` at 55% `→ #AE8B5B` |
| Black gradient `#2A2A2C → #111113`, two stops | Three stops at 135°: `#3C3C3F → #232326` at 55% `→ #101012` |
| Glass highlight "white, low alpha" | 135° ramp, `0.18 → 0.04` at 42% `→ 0` at 100% |
| Wall shadow blurs 4 / 26 / 80 | Those are Figma diameters. Front view in SwiftUI: radius 2 / 13 / 40. The **perspective** view is a different, heavier stack: `2 3 2 / 0.16`, `14 20 15 / 0.22`, `0 44 45 / 0.10` |
| Name "Salon" is provisional | Display name is **Framewall**, bundle `com.mateuswerneck.framewall` |
| Min deployment target undecided (iOS 26 vs 18) | **iOS 27.0.** Native Liquid Glass — write no `.ultraThinMaterial` fallbacks |
| Use `swiftui-expert-skill` if available | The available skill is `xcode-integration:swiftui-specialist` |

## Project facts

- Project `framewall.xcodeproj`, single target and scheme **framewall** (product and
  module name follow the target; the display name is Framewall). The `@main` file is
  still called `MyApp.swift`. Build check from the shell:
  `xcodebuild -project framewall.xcodeproj -scheme framewall -destination 'generic/platform=iOS Simulator' -quiet build`
- iOS 27.0. `TARGETED_DEVICE_FAMILY = 1,2,7` and `SUPPORTED_PLATFORMS` includes
  `macosx` and `xros` — the spec is iPhone-first, so treat the extra platforms as
  untested rather than supported.
- Swift 5 language mode with **Approachable Concurrency** on and
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: types are main-actor isolated by
  default, so don't scatter `@MainActor` annotations that the default already covers.
- App Sandbox is on with user-selected files read-only; the only usage string is
  `NSMotionUsageDescription`. Camera access (and `NSCameraUsageDescription`) must be
  added before the VisionKit scanner (build step 2) can work.

## Current state

- **Frame (step 1): built, then shelved.** The RealityKit stack —
  `FramedArtworkView`, `FramedArtworkScene`, `FrameTilt`, `FrameHaptics` — is intact
  but unused. Every screen draws the flat `StaticFramedArtwork` instead: it reads
  better at feed and carousel scale and is transparent. The 3D frame is meant to
  return in the room view and Hang at Home.
- **Feed, Profile, Post** are real screens built against Figma. Tab icons are the
  custom SVGs from `code.md` §5.
- **Viewer (step 3): mostly done.** Tapping a feed post or profile tile opens
  `ArtworkView` as an overlay with a `matchedGeometryEffect` hero transition; it
  swipes through the body of work. "View on wall" is a stub — the room view (Figma
  `06 Wall`, 115:358) is next.
- **Scan (step 2): not started.** `PostView` uses a `PhotosPicker`; the Post button
  is a TODO.
- Data is sample-only (`Artwork.sampleFeed`, `Profile`), no persistence.

## Known issues, deferred

Found in a review of the viewer's flight and pull-to-close (`ArtworkView`,
`FeedView`, `ProfileView`) on 2026-09-23, and left alone on purpose. Pick them up
if the pull feels stuttery or misbehaves. Most important first:

1. **Every frame of a pull re-renders the whole viewer.** `drag` is `@State` on
   `ArtworkView`, and its sections (toolbar, pager, page control, info, button)
   are `private var`s, not their own `View` types, so nothing limits the
   re-render. Fix: split them into `View` types with narrow inputs, so a drag
   frame only redraws the travelling piece and the backdrop.
2. **An interrupted pull can close the viewer.** `PullGesture` treats `.cancelled`
   like `.ended`, so a pull the system cancels (a call, Control Center) past
   120 pt dismisses. Fix: spring back on `.cancelled`.
3. **Two copies under Reduce Motion during a pull.** The host keeps the tile
   visible under Reduce Motion, so it shows through the thinning wall behind the
   dragged piece. Fix: hide the tile once a pull starts.
4. **No tile to land on.** After swiping far in the viewer, the feed's
   `LazyVStack` may not have built that piece's tile, so the flight home ends at
   screen centre and the piece vanishes. Fix: scroll the feed to the piece
   before flying home.
5. **The piece drifts from under the finger as it shrinks.** `scaleEffect`
   anchors at the centre. Fix: anchor at the touch point, as Photos does.
6. **No momentum.** The release speed isn't carried into the flight home. Fix:
   pass the pan velocity into the spring.

```
framewall/
  MyApp.swift              @main App
  ContentView.swift        TabView root
  code.md                  the build spec
  Frame/                   Artwork model, FrameGeometry, FrameFinish,
                           StaticFramedArtwork, shelved RealityKit frame
  Post/PostSize.swift
  Profile/                 Profile model, DefaultAvatar
  Views/                   FeedView, PostView, ProfileView, ArtworkView
  Assets.xcassets
```

## Build order

From `code.md` §6. Step 3 is being finished before step 2, since most of it was
already built:

1. **The frame, for real** — RealityKit scene, gyroscope tilt, settle haptic. The only
   technically risky part and the whole identity of the app. Verify on a device.
2. **Scan a painting** — VisionKit scanner plus the metadata form.
3. **Profile and viewer** — grid, swipe between pieces, "View on wall".
4. **Widgets and StandBy.**
5. **Accounts and following** — not before this point.

Do not build likes or comments. Do not build anything generative AI — the "made by
hand" position is the point.

## Working here

- Use the **xcode-tools** MCP server rather than shell commands: `XcodeRead`,
  `XcodeWrite`, `XcodeGrep`, `XcodeGlob` for files, `BuildProject` to build,
  `XcodeRefreshCodeIssuesInFile` for fast per-file diagnostics, `RunCodeSnippet` to
  try an idea. The paths those tools take are project-organization paths and do not
  match filesystem paths.
- `DocumentationSearch` for anything Liquid Glass, RealityKit, or iOS 26/27 era. The
  spec leans on APIs newer than model training data — look them up, don't guess.
- Verify the frame on a physical device early. Gyro tilt and haptics cannot be judged
  in the simulator.

## Code style

- SwiftUI for all UI; RealityKit for the frame and AR. Async/await, never Combine.
- PascalCase types, camelCase members, `@State private var`, 4-space indent.
- Semantic colors throughout so dark mode is free. The one deliberate exception is the
  gallery white in room views — a radial gradient `#FFFFFF` → `#E2E2E6`, not a system
  background.
- Real system components over recreated ones.
- Respect **Reduce Motion**: the gyroscope tilt falls back to the static front view.
- Comment non-obvious geometry and the reason behind a magic number, not the syntax.

## Legal

The placeholder artwork in the design is **not licensed** — other artists' works and
one profile photo are album covers used as stand-ins. Replace all of them before
anything ships or is shown publicly. The only genuine work is Mateus's own painting,
*The Other Side Off a Flower*. The eight default avatars have internal nicknames
referencing painters; never surface those names in the UI.
