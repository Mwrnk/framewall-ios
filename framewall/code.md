# Salon — iOS build spec

Handoff document for an Xcode agent. Everything needed to start building is in this
file. The Figma file is referenced at the end but is **not** required.

The name **Salon** is provisional. Mateus Werneck (@mwrnk) can rename it.

---

## 1. What the app is

A portfolio and gallery app for painters. The premise: every other app treats a
painting as a file. Salon treats it as an object in a place.

- A post is not a cropped square. It is a **3D framed painting floating in white
  space with real shadows**.
- A profile is a **room** you curate, not a grid you fill.
- You swipe left and right through another artist's works like walking a wall.
- Uploads declare **physical dimensions** (cm), not just pixels, so the work has a
  true size everywhere it appears.
- Native iOS. Apple's own design language, not a cross-platform look.

The competitive gap this fills: Instagram compresses art and buries it under video.
Cara is artist-first but is a plain feed plus portfolio. Behance, Dribbble and
ArtStation are hiring tools built on grids. Artsy and Saatchi are shops. Glass proved
a niche will pay for a calm chronological feed, but it is photographers only. Nobody
renders the work as a physical object.

---

## 2. The framed artwork — exact spec

**This is the identity of the app and the highest-risk part to build. Build it
first.** The geometry below is measured from the design and should be reproduced
faithfully. All values are for a 360 x 360 pt container; scale proportionally.

### Front view (straight-on), 360 x 360 container

| Layer | Origin | Size | Notes |
|---|---|---|---|
| Body | 0, 0 | 360 x 360 | Carries the wall shadow (below). No fill. |
| Front face | 44, 44 | 272 x 272 | The frame moulding. Linear gradient, see below. |
| Rebate lip | 58, 58 | 244 x 244 | Solid black at **0.42 opacity**. The dark inner edge where the moulding steps down to the canvas. |
| Artwork | 60, 60 | 240 x 240 | The painting. Aspect fill. |
| Glass highlight | 60, 60 | 240 x 240 | Linear gradient, white, low alpha. Sits over the artwork. |

So the visible frame border is **16 pt** on a 272 pt frame, roughly **5.9%** of the
frame's width. Keep that ratio when scaling.

### Wall shadow — three layers on the Body

Three separate drop shadows, all pure black, stacked. This is what makes it read as
hanging on a wall rather than pasted on:

| Purpose | Offset | Blur | Alpha |
|---|---|---|---|
| Contact | 0, 2 | 4 | 0.16 |
| Key light | 8, 14 | 26 | 0.20 |
| Ambient | 0, 36 | 80 | 0.10 |

### Artwork inner shadow

Inner shadow on the artwork layer: offset **3, 4**, blur **6**, alpha **0.38**.
This is the moulding casting onto the canvas surface. Subtle but it sells the depth.

### Frame finishes

- **Natural oak** — warm light wood. Gradient roughly `#D6B489` to `#A8815A`, lit
  from the upper left.
- **Black** — near-black satin. Roughly `#2A2A2C` to `#111113`.

### Perspective view

Same construction, drawn as a quad turned slightly to the left, with a visible
**thickness face** on the near (left) edge so you see the frame has depth. In Figma
this was faked with vector quads. In the app it should be a real 3D object.

### How to build it in code

Use **RealityKit** inside a SwiftUI `RealityView`:

- Frame: a box mesh, or four mitred boxes if you want real corner joins.
- Canvas: a thin plane inset into the frame, painting as its material texture.
- Glass: an optional thin plane with low-alpha specular over the canvas.
- One key light from the upper left, plus ambient, matching the shadow spec above.
- White backdrop plane receiving a soft shadow.

**Gyroscope tilt (Core Motion).** The frame shifts a few degrees with device
attitude and the glass highlight sweeps across as it moves. Clamp the rotation to
roughly ±8 degrees and damp it, or it feels twitchy. Respect **Reduce Motion**: fall
back to the static front view.

**Haptics (Core Haptics).** A soft settle when a swiped piece lands. The goal is that
a frame feels like it has weight.

Verify on a device early. If the frame feels good in the hand, everything else in
this app is ordinary iOS work.

---

## 3. Layout and design system

Everything below comes from Apple's iOS 26/27 design kit. Prefer real system
components over recreating them.

### Metrics — iPhone 17 Pro, 402 x 874 pt

| Element | Height |
|---|---|
| Status bar | 62 |
| Toolbar, inline title | 54 |
| Toolbar, large title | 105 |
| Tab bar (Liquid Glass) | 95 |
| Home indicator | 34 |

- Screen edge inset: **16** for content, **20** for inset-grouped cards.
- Inset-grouped card: corner radius **20**, fill `#F2F2F7` (use the semantic grouped
  background so dark mode works), row height **44**, separators **0.5 pt** inset 16.
- Pinned primary button: 370 x 50, 16 from each edge, bottom at y 774.
- Profile picture: **96 pt** circle.

### Type ramp (SF Pro, with line heights)

| Style | Size / line height | Used for |
|---|---|---|
| Large Title Emphasized | 34 / 41 | Feed title |
| Title 2 | 22 / 28 | Artwork title, show title |
| Body | 17 / 22 | Field values, captions, primary labels |
| Body Emphasized | 17 / 22 | Buttons, nav titles, names |
| Footnote | 13 / 18 | Metadata, section headers, secondary lines |
| Footnote Emphasized | 13 / 18 | Chips, segment labels, small buttons |
| Caption 2 | 11 / 13 | Wall label, dimension labels |

### Color

Use **semantic** colors throughout so dark mode is free:

- `Labels/Primary`, `Labels/Secondary` for text.
- `Backgrounds/Primary`, grouped backgrounds for surfaces.
- `Separators/Non-opaque` for hairlines.
- `Accents/Blue` for the tint: links, selection rings, dimension lines, primary
  buttons.

The gallery white in the room views is **not** the system background. It is a
deliberate radial gradient from `#FFFFFF` at the centre to about `#E2E2E6` at the
edges, which is what makes a flat wall read as a lit wall.

### Liquid Glass

Toolbars, tab bars and the floating buttons use the iOS 26+ glass materials. In
SwiftUI use the native `.glassEffect` / glass button styles rather than hand-rolling
blur. **This implies a minimum deployment target of iOS 26.** Confirm with Mateus
before locking that in; if he needs iOS 18, the glass falls back to `.ultraThinMaterial`
and the tab bar becomes a standard `TabView`.

---

## 4. Screen inventory

Twelve screens exist in the design. Interactions implied by each are noted.

1. **Feed** — large title "Salon", chronological posts, each a perspective frame on a
   white stage with title and artist beneath. Glass tab bar. No algorithm, no ads.
2. **Artwork viewer** — hero frame centred, neighbouring works peeking in at both
   edges to signal swipe, page dots, then title, year, medium, size and a description.
   Swipe left/right through the artist's works. A "View on wall" button leads to the
   room view.
3. **Profile** — 96 pt photo, name, handle and location, bio, counts (works,
   followers, following), Follow button, and a 2x2 grid of straight-on framed works.
4. **New Post** — live 3D preview of the piece at the top, frame picker (oak or
   black) with a blue selection ring, a Square / Portrait / Landscape size control,
   a helper line stating the minimum pixel size, and a pinned Post button.
5. **Edit Profile** — photo with a blue camera badge, "Take Photo" and "Choose from
   Library", a grid of eight default avatars with the chosen one ringed and checked,
   an inset-grouped card of Name / Username / Location / Website, a Bio card with a
   character counter (150 max), and a pinned Save.
6. **Wall (room view)** — the single piece alone in a white gallery: vignetted wall,
   baseboard, floor, a track light throwing a blurred warm cone onto the frame, warm
   light pools on wall and floor, nail and hanging wire, a long cast shadow, a small
   museum wall label (title, artist, medium and year), and a bench. A "Detail | On
   wall" segmented switcher at the bottom toggles back to the viewer.
7. **Rooms** — the profile as a curated gallery. Room chips across the top (Studio,
   2025, Sketches, Collected). A salon hang of many pieces at different sizes on one
   wall. In edit mode you drag a piece to rehang it: the dragged piece lifts, tilts,
   and gains a heavier shadow while a dashed blue outline marks where it came from.
   Pinch to resize. "Hang a piece" adds one.
8. **Opening Night** — a scheduled exhibition drop. Dark room, spot-lit pieces, a
   LIVE pill, a count of who is in the room with their avatars, the show title and a
   closing countdown, and a **guestbook** people sign instead of a comment thread.
   Runs for a fixed window, for example 48 hours.
9. **Scan a Painting** — camera viewfinder over the canvas with detected edges
   highlighted, draggable corner handles, a level indicator showing the phone is
   tilted, "Canvas found, hold steady", and a camera bar with an auto-crop toggle.
   Built on **VisionKit's document scanner**, which gives edge detection and
   perspective correction for free.
10. **StandBy** — landscape, black, a single lit frame as the piece of the day with
    title and artist. A phone on a nightstand becomes a framed painting.
11. **Hang at Home** — AR at true scale. The piece on the user's real wall with
    dimension lines reading its actual size in cm, a wall-detection outline, an info
    card and a "Place on wall" button. **RealityKit** plus plane detection. The
    declared cm dimensions drive this.
12. **Home Screen Widget** — a medium widget showing the framed piece of the day with
    a kicker, title, artist and an action line. **WidgetKit**; render the frame to a
    static image since widgets cannot run RealityKit.

---

## 5. Reusable assets

### Tab bar icons

Not the default house/plus/person. Deliberately different:

- **Feed** — a framed picture hanging from a nail.
- **Post** — a paintbrush.
- **Profile** — the artist's signature.

These are custom SVGs, not SF Symbols. Drop them into the asset catalogue as template
images, or convert to SF Symbol custom symbols. All are 24x24, stroke 1.8, round caps
and joins, `fill="none"`, stroke coloured by the tint.

Feed:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="3.4" r="1.4" fill="currentColor" stroke="none"/>
  <path d="M12 4.8L6.5 9.6M12 4.8l5.5 4.8"/>
  <rect x="4.5" y="9.6" width="15" height="10.9" rx="1.2"/>
  <path d="M7.8 17.2l2.6-3 2 2 3.8-3.6"/>
</svg>
```

Post:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <path d="M13.6 10.4L20 4" stroke-width="2.2"/>
  <path d="M13.6 10.4C10.5 10.2 7.6 12.4 6.6 15.8C6.1 17.5 5.4 18.8 4 20C6.4 20.4 8.6 20 10.2 19C13.2 17.3 14.6 14.4 13.6 10.4Z"/>
</svg>
```

Profile:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <path d="M3.5 15c1.6-5.5 3.4-7.5 4.4-5.2.8 1.9-.6 5.2-1.8 7.6 2.6-5.4 4.6-8.4 6-8.2 1.3.2.6 4.2-.8 7 1.9-3.6 3.4-5.4 4.6-5.2 1.1.2.9 2.6.2 4.4 1.3-1.6 2.6-2.5 4.4-2.6"/>
  <path d="M3 19.4c5.6.6 12.4-.4 18-1.2"/>
</svg>
```

### Default profile pictures

Eight painterly abstractions for people who have not uploaded a photo. Each is a
96x96 SVG clipped to a circle. **Internal names only** — they nod to painters and
must not ship as user-facing labels. Give them neutral names in the UI, or none.

```svg
<!-- 1 -->
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" fill="#B5321E"/><rect x="7" y="9" width="82" height="35" rx="4" fill="#F08A24"/><rect x="7" y="52" width="82" height="37" rx="4" fill="#6B1815"/></svg>

<!-- 2 -->
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" fill="#F4F1EA"/><rect x="0" y="0" width="60" height="60" fill="#D9342B"/><rect x="66" y="0" width="30" height="24" fill="#F2C94C"/><rect x="66" y="66" width="30" height="30" fill="#2B4FA2"/><rect x="60" y="0" width="6" height="96" fill="#141414"/><rect x="0" y="60" width="96" height="6" fill="#141414"/><rect x="66" y="24" width="30" height="6" fill="#141414"/><rect x="0" y="80" width="60" height="6" fill="#141414"/><rect x="66" y="60" width="30" height="6" fill="#141414"/></svg>

<!-- 3 -->
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" fill="#F2C14E"/><path d="M48 8 C58 20 74 22 76 40 C78 56 66 60 62 74 C58 88 44 90 40 78 C36 66 22 62 20 48 C18 34 30 26 34 16 C38 6 44 4 48 8 Z" fill="#1F4E9C"/><path d="M50 30 C54 40 58 44 56 56 C54 66 46 66 44 58 C42 50 40 44 44 36 C46 32 48 28 50 30 Z" fill="#F2C14E" opacity="0.9"/><circle cx="74" cy="18" r="6" fill="#E8412C"/></svg>

<!-- 4 -->
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" fill="#EAE3D2"/><path d="M50 12 L88 76 L12 76 Z" fill="#F2B633"/><rect x="12" y="44" width="42" height="42" fill="#1E4C9B"/><circle cx="62" cy="36" r="22" fill="#D63A2C"/></svg>

<!-- 5 -->
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" fill="#F7F5EF"/><rect x="24" y="22" width="48" height="48" fill="#141414" transform="rotate(8 48 46)"/><rect x="62" y="70" width="20" height="8" fill="#D23A2B" transform="rotate(-24 72 74)"/></svg>

<!-- 6 -->
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" fill="#F6F1E4"/><path d="M10 70 C30 40 50 78 70 44 C78 30 86 34 90 24" stroke="#141414" stroke-width="5" fill="none" stroke-linecap="round"/><circle cx="30" cy="30" r="12" fill="#E03C31"/><circle cx="76" cy="66" r="8" fill="#2A57A5"/><path d="M56 12 l3 9 9 3 -9 3 -3 9 -3 -9 -9 -3 9 -3 z" fill="#141414"/><circle cx="20" cy="84" r="5" fill="#3B8F3C"/><circle cx="52" cy="60" r="3" fill="#F2B633"/></svg>

<!-- 7 -->
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" fill="#E4D3B5"/><circle cx="48" cy="48" r="44" fill="#2C3E80"/><circle cx="50" cy="47" r="34" fill="#D9482F"/><circle cx="47" cy="49" r="24" fill="#F0B429"/><circle cx="49" cy="48" r="14" fill="#2C3E80"/><circle cx="48" cy="49" r="6" fill="#F5E6C8"/></svg>

<!-- 8 -->
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" fill="#1C2F6E"/><path d="M8 42 C22 22 44 24 50 42 C56 60 38 70 30 56 C24 46 34 38 42 44" stroke="#F5D547" stroke-width="4" fill="none" stroke-linecap="round"/><path d="M40 82 C54 64 76 66 92 80" stroke="#8FB6E8" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.85"/><path d="M58 30 C66 16 84 18 92 34" stroke="#F5D547" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.75"/><path d="M4 66 C16 58 28 64 34 72" stroke="#8FB6E8" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.6"/><circle cx="76" cy="20" r="10" fill="#F7E27A"/><circle cx="71" cy="17" r="8" fill="#1C2F6E"/></svg>
```

### App icon

A sample exists: an iOS squircle on a vignetted white ground with a warm top light,
holding the perspective oak frame with a Rothko-style gradient painting inside.
Mateus is finishing the icon himself. For the real export, ship the full 1024 square
with **no** rounded corners — the system applies the mask.

---

## 6. Build order

### Build now, in this order

1. **The frame, for real.** RealityKit scene, gyroscope tilt, settle haptic. This is
   the only technically risky part and the whole identity of the app. Roughly two
   weeks, no backend. Verify on a device.
2. **Scan a painting.** VisionKit scanner plus the metadata form: title, year, medium,
   size in cm. Now real work flows through the real frame.
3. **Profile and viewer.** Grid of works, tap to open the viewer, swipe between
   pieces, "View on wall". Ship Rooms as a single fixed wall first; drag-to-hang can
   wait.
4. **Widgets and StandBy.** Once the frame renders to an image, each is about a day.
   They drive return visits and they are the screenshots that sell the app.
5. **Accounts and following.** Only now. Until this point it works as a personal app,
   which means Mateus can use it himself for a month before anyone else does.

### Later, in this order

6. Opening nights with the guestbook.
7. AR hang at true scale.
8. Frame shop: frames, mats, glass finish, plinths for 3D objects, light presets
   (gallery spot, north window, evening).
9. Under the varnish: press and hold to scrub from sketch to underpainting to final.
10. Collect instead of like: collecting hangs someone's piece in a room on your own
    profile with credit. A red dot marks a sold work. Reads as taste, not applause.
11. Postcards: send a piece through iMessage, or order a printed one.
12. Lock screen widget and Apple TV screensaver.
13. Curated walls: guest-curated shows, discovery by place, so artists in the same
    region find each other.
14. Provenance: C2PA content credentials and a "made by hand" badge.
15. Web viewer with the same 3D frame, so a shared link previews as the framed piece
    rather than a cropped square. Plus CV export.

### Do not build yet

- **Likes and comments.** The guestbook and collecting replace them when social
  arrives. Adding a like count early turns the app into every other app.
- **Anything generative AI.** The "made by hand" position is worth more than any
  generated feature, and it is precisely why artists left other platforms.

---

## 7. Stack

- **SwiftUI** for all UI. **RealityKit** for the frame and AR.
- **Core Motion** for tilt, **Core Haptics** for weight.
- **VisionKit** for scanning, **WidgetKit** for widgets and StandBy.
- **SwiftData** locally. Store the original scan and derive every size from it.
- Backend only at step 5. **CloudKit** is the least work if it stays Apple-only;
  **Supabase** if a web viewer is wanted.
- If the `swiftui-expert-skill` is available in the build session, use it.

### Open decisions

- Minimum deployment target. iOS 26 buys native Liquid Glass; iOS 18 needs fallbacks.
- App name. Salon is a working title.

---

## 8. Legal and content notes

- **The placeholder artwork in the design is not licensed.** Other artists' works and
  one profile photo are album covers (Graduation, Currents, GKMC) used as stand-ins.
  Replace all of them before anything ships or is shown publicly.
- The only genuine artwork in the design is Mateus's own painting, *The Other Side Off
  a Flower*.
- The default avatar names are internal nicknames referencing painters. Do not surface
  them in the UI.

---

## 9. Figma reference (optional)

Useful if the build session has the Figma MCP. Nothing above depends on it.

- File: `https://www.figma.com/design/5qg6TLlXnbQXksbYyn1otP/Formula`
- Page `iOS`: node `98:2`
- Components: `Framed Artwork` `101:1762`, `Tab Icon` `104:297`, `Default Avatar`
  `114:417`
- Screens: Feed `100:917`, Artwork `100:932`, Profile `100:947`, New Post `100:962`,
  Edit Profile `100:977`, Wall `115:358`, Rooms `122:457`, Opening Night `122:666`,
  Scan `123:689`, StandBy `124:703`, Hang at Home `124:712`, Home Screen Widget
  `128:1224`
- App icon sample: `121:457`
- Library: Apple's *iOS and iPadOS 27* kit

One caveat if you do open it: the design uses Apple's kit components with their text
layers hidden and custom text overlaid on top, because the kit's text properties could
not be set from the automation session. Read the overlay text nodes, not the component
labels.
