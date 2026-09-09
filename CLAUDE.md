# Habit — project brief

A habit tracker for iOS, iPadOS, macOS and watchOS. Black-and-white pen-and-ink
aesthetic, serif type, no guilt mechanics. Free forever, no accounts, no server.

**Read `docs/habit-spec.md` before writing any code.** It is the source of truth for
every decision below. `docs/habit-mockups.html` shows every screen — open it in a
browser; the theme toggle, accent swatches and heat-map range control are live.

---

## Status

The app builds and runs. `HabitKit` holds the models, day and pause maths, ordering,
the nudge engine, and export/import; the `Habit` target holds the SwiftUI screens.
Against **Build order** below: 1 Core loop, 3 Pausing, 6 Nudges, 7 Ordering and
10 Removal/Export are done, 2 History is partial, and 4 Sync, 5 Ambient, 8 NFC,
9 Obsidian and 11 Polish are not started.

Two things the code does not yet match. Navigation is a single `NavigationStack`
with a toolbar in `ContentView.swift`, while §2 of the spec specifies a four-tab
bar; the toolbar is interim scaffolding. And §10's nudge wording — seven tones,
per-habit phrasing, Quiet Hours holding rather than dropping, and four additional
`Habit` fields as `HabitSchemaV3` — is specified but unbuilt, so `NudgeTone` still
carries three cases including `.silent`.

Sync is blocked on the Apple Developer Program, which hasn't been bought yet, so
the schema stays at `HabitSchemaV2` and no `.entitlements` file exists.

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
  New fields are optional or defaulted — and the default must live on the stored
  property itself (`var thing: Int = 0`), not only in `init(...)`; an init-only
  default is invisible to SwiftData's migration and can't backfill existing rows.
  This exact gap in `nudgeHour` shipped without a store-visible default and
  crashed the app on launch for anyone with an existing store — see
  `HabitKit/Sources/HabitKit/Migration.swift` for the fix and the full
  step-by-step process every future field addition must follow (bump
  `HabitSchemaVN`, add a migration stage, add a migration test). Deprecated
  fields stay and are ignored. Every schema change ships as a tested
  `VersionedSchema`, and `HabitApp`'s `ModelContainer` must always be built with
  `HabitMigrationPlan` — never a bare `Schema`.
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
8. NFC — tag writing and the Shortcuts walkthrough
9. Obsidian — file-path append, then the daily-note option
10. Removal — archive, restore, Recently Deleted, purge, JSON export
11. Polish — accessibility audit with VoiceOver on device, Dynamic Type sweep

## Working style

- Ask before adding a dependency. This app should have none beyond Apple's frameworks.
- Prefer deleting code to adding a flag.
- When a design question isn't answered in the spec, ask rather than inventing a
  convention — the design has a strong point of view and guessing tends to violate it.
- After every commit, run `git push`. The repo is backed up at
  github.com/ByrneLikeBurn/habit-project, and a commit that isn't pushed isn't backed up.

## How a change runs

- One change, one branch, one PR. Branch off `main`, named for what it does
  (`docs/…`, `fix/…`, `feat/…`).
- Stay in scope. A docs change touches no `.swift`. Anything else you notice on
  the way is a line in the PR body, not a commit.
- Finish the run: commit, push, open the PR with `gh`. Stop there. Merge when I
  ask you to in that run, after the diff has been checked — never on your own
  initiative, and never by enabling auto-merge.
- A change made to test a hypothesis is reverted when the hypothesis fails.
- Describe the diff you actually made, and say what the prompt asked for that you
  did not do.

## Writing

Prose you write — commit messages, PR bodies, code comments, and any text headed
for `docs/` — is plain and says what changed. One idea per sentence.

Avoid writing for effect: "worth stating", "worth noting", "worth flagging", "the
real question is", "the honest answer is", "to be clear", "let me be direct",
"this isn't X, it's Y", sentence fragments used for emphasis, and grading your own
work with words like "successfully", "perfect" or "production ready". If a
sentence can be deleted without losing information, delete it.

## Branch protection

Work happens on feature branches, never directly on `main`. A branch merges to
`main` only once CI is green — the `Tests` workflow (`.github/workflows/tests.yml`)
runs on pushes to `main` and on pull requests targeting `main`. A feature-branch
push gets no CI signal, so the PR is where the check reports and where it must
pass before merge.

## Command approvals

Before running any command that needs my approval, state in one plain sentence what
it does and whether it's reversible.

Always flag explicitly, in that sentence:

- `rm` (and anything else that deletes files)
- `sudo`
- `git reset --hard`
- force pushes (`git push --force` / `--force-with-lease`)
- anything that touches files or state outside this project folder
