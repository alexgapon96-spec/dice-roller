# D&D Dice Roller — Specification v2.0 (draft)

Status: **v1.0 shipped as APK** (2026-10-08). **v1.1 changes** (2026-10-09): two dice shown as soon as Advantage/Disadvantage is picked, no auto-reset, sound and haptics with toggles in settings. **v1.2** (2026-10-09): web version on GitHub Pages. **v2.0** (planned): dice skins and new top-right controls, web only.

## 1. Goal
The simplest possible app for rolling dice in D&D. One screen, one die, minimal controls.

## 2. Platforms & general
- iOS and Android from a single codebase.
- Fully offline. No ads, accounts, analytics or network access.
- Portrait orientation only.
- UI language: English.
- Sound and haptics: see §9.

## 3. Main screen
- **Background:** full-screen purple felt (game-table cloth).
- **Camera:** top-down view onto the table (like Baldur's Gate 3) — the die lies on the felt, we look at it from above.
- **Die:** large, centered. Material: **grey granite** (speckled), **white numbers**.
- **Settings button:** gear icon, top-right corner.
- **Roll mode selector:** at the bottom of the screen (see §6).
- The result is **never** duplicated as text — it is read only from the die itself.

## 4. Roll
1. User taps the die.
2. The result is generated immediately (secure RNG, uniform distribution).
3. The die rolls across the felt for ~1–1.5 s.
4. The die stops with the result face **up** (towards the camera).
5. Taps during the animation are ignored.

Reading the result:
- **d6, d8, d10, d12, d20:** the number on the top face.
- **d4:** as on a physical die — three numbers per face, near the vertices. The die rests on a face with a vertex pointing up; all three visible faces show the same number next to that top vertex.

## 5. Dice
| Die | Values |
|---|---|
| d4 | 1–4 |
| d6 | 1–6 |
| d8 | 1–8 |
| d10 | 1–10 |
| d12 | 1–12 |
| d20 | 1–20 |

## 6. Advantage / Disadvantage
- Segmented control with three states: **`Disadvantage · Normal · Advantage`**.
- **Always visible**, works with **any** die.
- Default on app launch: `Normal` (the mode is not persisted).
- **The number of dice on screen always matches the mode:** `Normal` = one die; `Advantage` / `Disadvantage` = two dice side by side (each smaller than the single die so both fit).
- **Switching the mode** (or the die type) shows a "clean table": every die rests with its maximum value up (e.g. 20 and 20), no glow, no transparency.
- In `Advantage` / `Disadvantage` mode, one tap rolls both dice simultaneously.
  - When they stop, the counted die (higher for Advantage, lower for Disadvantage) stays fully opaque; the other one becomes **semi-transparent** (~35% opacity).
  - If both show the same value, both stay fully opaque.
- **No auto-reset:** the mode stays selected until the user changes it.

## 7. Crits (d20 only)
- **20:** golden glow around the die.
- **1:** red glow.
- The glow is static (no pulsing) and stays until the next tap.
- With Advantage/Disadvantage, the crit is determined by the counted die only (Advantage: glow if the higher die is 20 or 1; Disadvantage: if the lower die is). The glow is shown around the counted die.

## 8. Settings
- Opens as a bottom sheet over the dimmed main screen. No title/heading in the sheet.
- **Top row:** two round icon toggles, centered — **vibration** and **sound** (see §9).
  - On: normal icon. Off: dimmed icon crossed out by a diagonal line.
  - Tapping a toggle flips it immediately; the sheet stays open.
  - Default: both on. Both persist between app launches.
- **Below:** die type — grid of 6 buttons (die silhouette + label): **d4 · d6 · d8 · d10 · d12 · d20**.
  - Default: **d20**. The selection persists between app launches.
  - Selecting a die closes the sheet; the new die appears on the main screen.

## 9. Sound & haptics
Synced to the roll animation, per die:
| Moment | Sound | Haptic |
|---|---|---|
| Each bounce | short die-on-table knock | light tap |
| Die stops | settle knock | medium tap |
| Crit (d20 shows 20 or 1 on the counted die) | — | double vibration |

- Sound: recorded dice-on-table samples from a free sound library (CC0 / public-domain license), bundled with the app (offline).
- Sound respects the phone's silent mode (no sound when the phone is muted).
- Each part works only when its toggle (§8) is on.

## 10. App icon
Granite d20 showing **20** with a golden glow, on purple felt (variant "Golden crit").

## 11. Web version (v1.2)
- Same app built for the browser, hosted for free on **GitHub Pages**; shared as a link.
- Published automatically by GitHub Actions on every push to `main`.
- Numbers use the bundled **Noto Serif Bold** font, so they look the same in every browser and on every platform.
- Vibration toggle is shown only where vibration can work: phones, and browsers on Android. Desktop browsers and iPhone Safari show only the sound toggle.
- Silent mode isn't visible to browsers; the sound toggle is the only control there.
- On wide screens the mode selector and settings sheet keep a phone-like width (max 440 px).
- Friends can "Add to Home screen" to get the dice icon and an app-like window.

## 12. Dice skins (release 2.0, web only)
Inspired by resin dice: translucent bodies, metal-coloured numbers, things embedded inside.

| Skin | Body | Inside | Numbers |
|---|---|---|---|
| **Granite** (default) | opaque grey stone | dark and light specks on the surface | white |
| **Moonpetal** | frosted pearl-pink resin | blue petals, evenly spread | gold |
| **Ocean Shards** | translucent blue | small foil shards (light blue, white, dark blue), evenly spread | copper-orange |
| **Amethyst** | clear purple glass | nothing (clean glass with facet reflections) | gold |
| **Opal Frost** | frosted white-lilac | iridescent glitter (pink, cyan, lilac, white, yellow) | turquoise |
| **Starry Night** | dark navy glass | gold dust | gold |
| **Emerald** | clear green gem | nothing (facet reflections) | gold |
| **Ruby** | clear red gem | nothing (facet reflections) | gold |

- Rendered in 3D like granite: translucent skins show the back edges through the body; inclusions sit **inside** the die, evenly spread, and turn with it while it rolls; glitter and gold dust sparkle as the die turns.
- **One skin for all dice** (d4–d20, both dice in Advantage/Disadvantage).
- The chosen skin persists between visits. Crit glow (§7) works the same on every skin.
- Picked in the **Skins** panel (§13).

## 13. Web controls (release 2.0)
Replaces the gear + bottom sheet **on the web**. All 2.0 work is web-only; Android/iOS are untouched until decided otherwise.

- **Top-right toolbar**, left to right:
  - **Vibration** toggle — only on narrow screens (< 600 px wide) in browsers that can vibrate (Android).
  - **Sound** toggle — icon only (speaker; crossed out when off).
  - **Dice** button — mini die + current type + ▾, e.g. `◆ d20 ▾`.
  - **Skins** button — mini d20 in the current skin + its name + ▾, e.g. `◆ Ruby ▾`.
- **Dice / Skins panels** (one open at a time):
  - **Wide screens (≥ 600 px):** the panel drops down from its button, anchored at the button's top-right corner; the button turns into a **✕** in the panel's top-right corner. The rest of the screen dims slightly.
  - **Narrow screens (< 600 px):** the same panel slides up from the bottom, with the same title and ✕.
  - Closing: ✕, tap/click outside, or **Esc**.
  - Header: panel title (`Dice` / `Skins`) and ✕. Body: 3-column grid of tiles (as before).
  - **Dice:** picking a die applies it and closes the panel. Tiles are drawn in the current skin.
  - **Skins:** picking a skin applies it at once and keeps the panel open for comparing.
- Toolbar buttons are ignored while dice are rolling.
- **Tap anywhere to roll:** any tap/click on the table rolls (not only on the die); taps on the toolbar, an open panel and the mode selector do their own thing instead.
- **Advantage / Disadvantage dice are as big as the single die** whenever both fit side by side (desktop); on narrow screens they shrink just enough to fit.

## 14. Out of scope
d100, roll history, multiple dice (2d6), modifiers (+5), shake to roll, themes, custom number of faces.
