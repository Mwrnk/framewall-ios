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

**`MyApp/code.md` is the build spec** — authoritative for intent, build order,
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

- Workspace `Untitled Project.xcodeproj`, single target and scheme **MyApp** (product
  and module name are `MyApp`; only the display name is Framewall).
- iOS 27.0. `TARGETED_DEVICE_FAMILY = 1,2,7` and `SUPPORTED_PLATFORMS` includes
  `macosx` and `xros` — the spec is iPhone-first, so treat the extra platforms as
  untested rather than supported.
- Swift 5 language mode with **Approachable Concurrency** on and
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: types are main-actor isolated by
  default, so don't scatter `@MainActor` annotations that the default already covers.
- App Sandbox is on and every resource-access setting is `NO`. Camera and photo
  library must be enabled before the VisionKit scanner (build step 2) can work.

## Current state

Scaffolding only. `ContentView` is a three-tab `TabView`; `FeedView`, `PostView` and
`ProfileView` are placeholder `Text` in a `NavigationStack`. The tab icons are SF
Symbols standing in for the custom SVGs in `code.md` §5.

```
MyApp/
  MyApp.swift            @main App
  ContentView.swift      TabView root
  code.md                the build spec
  Views/
    FeedView.swift
    PostView.swift
    ProfileView.swift
  Assets.xcassets
```

## Build order

From `code.md` §6, unchanged:

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
