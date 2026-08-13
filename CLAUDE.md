# Habit — project brief

A habit tracker for iOS, iPadOS, macOS and watchOS. Black-and-white pen-and-ink
aesthetic, serif type, no guilt mechanics. Free forever, no accounts, no server.

**Read `docs/habit-spec.md` before writing any code.** It is the source of truth for
every decision below. `docs/habit-mockups.html` shows every screen — open it in a
browser; the theme toggle, accent swatches and heat-map range control are live.

---

## Status

Design is settled. No code has been written yet. The next step is scaffolding the
Xcode project — see **Build order** below.

## Locked decisions — do not relitigate

| | |
|---|---|
| Minimum OS | iOS 26 / iPadOS 26 / macOS 26 / watchOS 26. Greenfield app; do not support older |
| Persistence | SwiftData + CloudKit **private** database. No Core Data |
| Accounts | None. No Sign in with Apple, no login screen, no backend |
| Price | Free forever. No ads, no analytics, no telemetry, no paywall surface |
| Habit kinds | `.binary` and `.counted` (target + optional unit) |
| NFC | Shortcuts automations matched on tag UID. **No domain, no universal links, no AASA** |
| Journalling | Obsidian only, via the built-in `obsidian://` URI |
| Mac | Native SwiftUI, not Catalyst |

## Invariants — these are the product

Violating any of these is a bug, however good the reason sounds.

1. **The app never uses guilt as a mechanic.** No streak-loss alarms, no red, no
   "you're falling behind", no reference to a missed day unless the user explicitly
   opted in. Missing a day produces silence.
2. **Colour carries no meaning.** Heat-map intensity is hatching density, never hue.
   The user's accent colour tints *marks only* — never text, never rules. Text
   contrast must stay a fixed constant the user cannot break.
3. **Pausing can only ever help you.** A paused day with no log never breaks a run
   and never extends it. A paused day *with* a log is extra credit and extends it.
   The streak function must have unit tests asserting exactly this, because it is the
   rule most likely to erode during a later "simplification".
4. **Every input is optional.** NFC, widgets and the Watch are shortcuts, not
   dependencies. Losing a tag breaks nothing.
5. **One write path.** Every `LogEvent` in the system is written by `LogHabitIntent`
   and nothing else — widget button, Shortcuts/NFC, Control Centre, Action button,
   Siri, and in-app taps all route through it.

## Engineering rules

- **Schema is additive only, forever.** SwiftData supports lightweight migrations
  only, and a custom migration ends CloudKit sync. Never rename or retype a field.
  New fields are optional or defaulted. Deprecated fields stay and are ignored.
  Every schema change ships as a tested `VersionedSchema`.
- **CloudKit schema must be deployed to Production** in the CloudKit Console before
  every release that touches the model. Development creates schema just-in-time;
  Production does not. Skipping this ships an app that syncs perfectly in Xcode and
  not at all on the App Store. Keep this in a release checklist.
- **`LogEvent` is append-only** — store `delta` (+1/−1), never an absolute value.
  Concurrent increments across devices must be commutative. Day totals are derived
  and cached in memory, never stored.
- **`dayKey` is an `Int` (yyyymmdd)** computed in the user's calendar with a settable
  day-start hour (default 04:00), and fixed at write time. Crossing timezones must
  never rewrite history.
- Structure: one shared Swift package `HabitKit` (models, day/pause maths, ordering,
  nudge scheduling, formatting), consumed by the app, watch, widget and intents targets.
- Ship JSON export early. It is the escape hatch for every persistence risk above.

## Accessibility is v1, not polish

Dynamic Type to AX5 on every screen. VoiceOver on the heat map groups by week with a
summary plus an `AXChartDescriptor` — never 365 individually focusable cells. Increase
Contrast maps to the "heavier ink" setting. 44×44 minimum targets. Full Keyboard Access
and complete menu-bar commands on Mac. Differentiate Without Colour needs no special
handling and must stay that way.

## Build order

1. Core loop — model, Today, binary + counted logging, local only
2. History — heat map (week/month/year) with the full seven-state mark vocabulary
3. Pausing — `Pause` records, Vacation Mode, Gentle Mode, extra-credit streak maths
4. Sync — CloudKit, tested with deliberately conflicting offline edits on two devices
5. Ambient — widgets, App Intents, Watch app and complication
6. Nudges — scheduling engine and settings
7. Ordering — Focus, manual, by-time, then Smart
8. Obsidian — file-path append, then the daily-note option
9. Removal — archive, restore, Recently Deleted, purge, JSON export
10. Polish — accessibility audit with VoiceOver on device, Dynamic Type sweep

## Working style

- Ask before adding a dependency. This app should have none beyond Apple's frameworks.
- Prefer deleting code to adding a flag.
- When a design question isn't answered in the spec, ask rather than inventing a
  convention — the design has a strong point of view and guessing tends to violate it.
- After every commit, run `git push`. The repo is backed up at
  github.com/ByrneLikeBurn/habit-project, and a commit that isn't pushed isn't backed up.

## Command approvals

Before running any command that needs my approval, state in one plain sentence what
it does and whether it's reversible.

Always flag explicitly, in that sentence:

- `rm` (and anything else that deletes files)
- `sudo`
- `git reset --hard`
- force pushes (`git push --force` / `--force-with-lease`)
- anything that touches files or state outside this project folder
