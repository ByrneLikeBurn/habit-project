# Habit — milestone prompt (worked example)

Filled copy of `app-prompt-template.md`, populated for Habit's actual next
milestone. Swap §0 and §4 for the next one and the rest carries over unchanged.

> **Two things to fix in the repo before you use this.** `CLAUDE.md` says *"No code
> has been written yet"* and that the next step is scaffolding the Xcode project —
> both are now wrong. `HabitKit` has seventeen source files and a full test suite, and
> `Habit/Habit` has the Today screen, heat map, settings, Gentle and Vacation modes,
> removal, export and `LogHabitIntent`. A stale status line is worse than none: a
> model that reads it will offer to build what already exists. Also, `habit-spec.md`
> is duplicated at the repo root and in `docs/` — the root copy is newer. `CLAUDE.md`
> points at `docs/`, so either delete the root copies or repoint the brief.

---

## 0. Role and objective

You are building one milestone of **Habit**, a habit tracker for iOS, iPadOS, macOS
and watchOS with a pen-and-ink aesthetic and no guilt mechanics. Free forever, no
accounts, no server. Swift 6 / SwiftUI / SwiftData. Minimum OS: iOS 26, iPadOS 26,
macOS 26, watchOS 26.

Your objective this run is **build order step 4 — CloudKit sync — and nothing else.**

## 1. Read first

Before writing any code, read:

- `CLAUDE.md` — locked decisions, engineering rules, working style
- `habit-spec.md` **(repo root — the newer copy; the one in `docs/` is stale)** —
  source of truth for product behaviour (§3 data model, §4 the SwiftData verdict
  and its two production traps, §10 architecture)
- `habit-mockups.html` (repo root) — every screen; open it in a browser, the theme toggle,
  accent swatches and heat-map range control are live
- `HabitKit/Sources/HabitKit/` — the shared package: models, day and pause maths,
  ordering, nudges, export/import, migration. **This exists and works. Do not
  rebuild it.**
- `HabitKit/Sources/HabitKit/Migration.swift` — the versioned-schema process every
  field addition must follow, and the `nudgeHour` bug that made it necessary
- `Habit/Habit/HabitApp.swift` — the single `sharedModelContainer` you will be
  changing

Do not ask me to paste these. Read them. If a file contradicts this prompt, the
file wins on product behaviour and this prompt wins on scope.

## 2. Invariants — these outrank every other instruction

Violating one is a bug however good the reason sounds. If following an instruction
later in this prompt would break one, stop and tell me.

1. **The app never uses guilt as a mechanic.** No streak-loss alarms, no red, no
   "you're falling behind", no reference to a missed day unless explicitly opted
   in. Missing a day produces silence. **A sync failure is not an exception to
   this** — it is reported plainly and quietly, never as alarm.
2. **Colour carries no meaning.** Heat-map intensity is hatching density, never hue.
   The accent tints marks only — never text, never rules.
3. **Pausing can only ever help you.** A paused day with no log neither breaks a run
   nor extends it. A paused day *with* a log is extra credit and extends it. This
   must survive sync: a `Pause` arriving from another device cannot retroactively
   shorten a streak.
4. **Every input is optional.** NFC, widgets and the Watch are shortcuts, not
   dependencies.
5. **One write path.** Every `LogEvent` is written by `LogHabitIntent` and nothing
   else. Sync must not introduce a second one.
6. **No data loss, ever.** If a conflict cannot be resolved commutatively, keep
   both records. Never resolve by discarding.

## 3. Locked decisions — do not relitigate

| | |
|---|---|
| Persistence | SwiftData + CloudKit **private** database. No Core Data, no public or shared DB |
| Accounts | None. No Sign in with Apple, no login screen, no backend. Sync keys to the iCloud account already on the device |
| Dependencies | None beyond Apple's frameworks. Ask before adding any |
| Schema | Additive only, forever. Lightweight migrations only — a custom migration ends CloudKit sync |
| `LogEvent` | Append-only, stores `delta` (+1/−1), never an absolute value |
| `dayKey` | `Int` (yyyymmdd) in the user's calendar, settable day-start hour (default 04:00), fixed at write time |
| Mac | Native SwiftUI, not Catalyst |

## 4. This milestone

**In scope**

- Add CloudKit to the `ModelContainer` in `HabitApp.swift`: private database,
  container identifier, keeping `HabitMigrationPlan` — never a bare `Schema`.
- Audit every `@Model` type against CloudKit's constraints and fix what fails.
  CloudKit requires all relationships to be optional and every non-optional
  attribute to carry a default; unique constraints are unsupported. Report each
  change: any that isn't purely additive is a red flag, so raise it rather than
  applying it.
- Move the store into a shared App Group container, and add the App Group +
  iCloud + background-mode entitlements. *This is a deliberate exception to the
  out-of-scope rule below: the widget and Watch targets need the store in the
  group container, and relocating a populated store later risks the data. Set up
  the location now, build nothing that consumes it.*
- Sync status surfaced honestly and quietly in Settings: last synced, and a plain
  line if iCloud is unavailable or the account is signed out. One line, no badge,
  no alert, no colour. Invariant 1 applies.
- Tests for the conflict cases that matter: two offline increments of the same
  counted habit on the same `dayKey` must sum, not overwrite; a `Pause` and a
  `LogEvent` arriving out of order must produce extra credit, not a broken run;
  a habit deleted on one device while logged on another must not resurrect as an
  orphan.
- A `docs/release-checklist.md` whose first line is **deploy the CloudKit schema
  to Production** (Console → Schema → Deploy Schema Changes), with the one-line
  reason: Development creates schema just-in-time, Production does not, so an App
  Store build syncs perfectly in Xcode and not at all for real users.

**Explicitly out of scope — do not build, do not stub, do not "prepare for"**

- The widget extension, the Watch app, complications, WatchConnectivity
- The Mac target and its sidebar layout
- NFC tag writing and the Shortcuts walkthrough
- Obsidian hand-off
- Any UI change beyond the single sync-status line in Settings
- Any redesign, refactor or "tidy" of existing HabitKit code

## 5. Design contract

Use these exact values. They live in `Assets.xcassets`; do not invent alternatives.

| Token | Paper | Ink |
|---|---|---|
| Background | `#FBFAF6` | `#14120F` |
| Ink (text) | `#16130F` | `#F2EEE5` |
| Secondary text | 70% ink | 70% ink |
| Tertiary text | 60% ink | 52% ink |
| Rule | 16% ink | 18% ink |

New York (serif) for habit names, headings and numerals; SF for labels and
controls. Icons are 1.5pt stroked line art on a 48×48 grid as custom SF Symbols.
Reuse the existing components — `SectionEyebrow`, `Chip`, `Buttons`, `Checkbox` —
rather than re-deriving them.

Where the mockup is ambiguous, ask. The design has a strong point of view and
guessing tends to violate it — in particular, anything that reads as urgency,
scoring or reproach is wrong even when it's conventional.

## 6. Accessibility contract — v1, not polish

- Dynamic Type to **AX5** on every screen; rows reflow to two lines rather than
  truncate
- 44×44 minimum targets
- VoiceOver on the heat map groups by week with a summary ("Week of 14 July, five
  of seven days, two paused") plus an `AXChartDescriptor`. Never 365 individually
  focusable cells
- WCAG AA minimum at every size — including secondary and tertiary text. The
  tertiary tint measured 2.97:1 during design and had to be corrected; treat small
  text contrast as a thing to verify, not assume
- Differentiate Without Colour needs no special handling and must stay that way
- Increase Contrast maps to "heavier ink": thicker strokes, darker rules, solid
  rather than hatched fills. Reduce Motion removes the check-mark draw-on and the
  sheet spring
- Full Keyboard Access and complete menu-bar commands on Mac; Switch Control
  ordering verified per screen; Voice Control labels on every control
- The sync-status line must be reachable and legible at AX5 without clipping

## 7. Portability contract

**A. The user's data follows them across every device on their Apple Account.**
A habit checked off on the Watch appears on the iPhone, iPad and Mac; the
complication and widget reflect it. That is what this milestone is for.

- CloudKit private database is the source of truth. Every write goes through
  `LogHabitIntent`.
- **Offline-first**: every write succeeds with no network. Nothing in the UI blocks
  on sync, and no spinner ever gates logging a habit.
- **Conflicts resolve commutatively.** `LogEvent` stores `delta`, so a counted habit
  incremented on the Watch and the iPhone inside the same sync window sums to two.
  Do not introduce any mutable absolute-value field, and do not add
  last-writer-wins resolution anywhere.
- **Schema is additive only, forever.** New fields optional or defaulted, with the
  default on the stored property (`var thing: Int = 0`), not only in `init(...)` —
  an init-only default is invisible to migration and cannot backfill existing rows.
  This exact gap in `nudgeHour` crashed the app on launch for anyone with an
  existing store. Every change ships as a tested `VersionedSchema` with a bumped
  `HabitSchemaVN`, a migration stage and a migration test.
- The store lives in the App Group container so widget, Watch and intents targets
  read the *same* store, never a copy.
- **The deployment trap**: the CloudKit schema must be deployed to Production before
  every release that touches the model. This is the single most common way CloudKit
  apps ship broken. It goes in `docs/release-checklist.md` this run.
- WatchConnectivity is a later milestone. When it arrives it delivers and CloudKit
  reconciles; they never race. Do not add it now.

**B. The user can leave with their data.** Export and import already exist in
`HabitKit`. This run must not break them.

- Verify the export round-trips after the CloudKit changes: export → import →
  identical state. Assert it in a test.
- If the CloudKit audit changes any model field, the export format version must
  reflect it and import must still read the old version.

## 8. Security and privacy contract

Scope this honestly: there is no server, no account, no analytics and no third-party
code, so most of a standard checklist doesn't apply. The surfaces that are real:

- **Data at rest**: set an explicit file protection class on the store, and name the
  tension rather than guessing — a store protected to complete-while-locked cannot
  be read by a widget or a background sync push. State which class you chose and
  what it costs.
- **Secrets**: there are none. Do not introduce any. No API keys, no tokens, no
  hardcoded container credentials beyond the entitlement identifier.
- **Logging**: never log habit names, notes or counts. Use `Logger` with `.private`
  interpolation for anything user-derived. CloudKit error logging must not include
  record contents.
- **Least privilege**: this milestone adds exactly three capabilities — iCloud
  (CloudKit, private DB), App Groups, and the `remote-notification` background mode
  for silent sync pushes. Nothing else. No associated domains, ever — the no-domain
  NFC decision in spec §7 depends on it.
- **Untrusted input**: the JSON import path is attacker-controlled in principle.
  Confirm it decodes into intermediate DTOs rather than straight into `@Model`
  types, bounds its sizes, and fails closed on malformed input without crashing.
- **Outbound URLs**: the Obsidian hand-off percent-encodes every user-supplied
  component. It's the only injection surface in the app. Not in scope this run —
  just don't regress it.
- **Network**: CloudKit only. No telemetry, no crash SDK, no remote config, no font
  or asset CDN. If you find yourself adding a URL, stop and ask.
- **Supply chain**: zero dependencies. CI (`.github/workflows/tests.yml`, `swift
  test`) must be green before merge, and work happens on a feature branch, never
  directly on `main`.
- The export file is unencrypted plaintext JSON. The UI should say so where the
  user creates it.

## 9. Architecture rules

- `HabitKit` holds models, day and pause maths, ordering, nudge scheduling and
  formatting. Views hold none of it. A view that computes a rule is a bug.
- **One write path.** `LogHabitIntent` serves the widget button, Shortcuts/NFC,
  Control Center, the Action button, Siri and in-app taps. Sync must not add a
  second writer.
- `HabitApp.sharedModelContainer` stays the single container, built from
  `HabitSchemaV1` and `HabitMigrationPlan`.
- Prefer deleting code to adding a flag.

## 10. Definition of done

Do not tell me it's finished until every line is true. Walk this list explicitly
in your report and mark each one.

- [ ] Builds for iOS and macOS with no errors and no new warnings
- [ ] `swift test` passes in `HabitKit`, including the tests added this run
- [ ] A test asserts two offline `+1` deltas on the same habit and `dayKey` sum to 2
- [ ] A test asserts a paused day with a log extends the streak and a paused day
      without one neither breaks nor extends it — the rule most likely to erode
- [ ] A migration test covers any schema change made for CloudKit compatibility
- [ ] Export → import round-trip verified after the changes
- [ ] Every `@Model` audited against CloudKit's constraints, with the findings listed
- [ ] The sync-status line checked at AX5 and in both themes
- [ ] Nothing from the §4 out-of-scope list was built
- [ ] No new dependencies, no new entitlements beyond the three named in §8
- [ ] No habit names, notes or counts in any log output
- [ ] `docs/release-checklist.md` exists and leads with the Production schema deploy
- [ ] Work is on a feature branch, not `main`, and CI is green

## 11. How to work

1. **Plan first.** Reply with: the files you'll create or change, the approach in a
   short paragraph, the results of the CloudKit model audit, and any question where
   the spec is silent. **Then stop and wait for my go.** No code in that message.
2. On approval, implement in the order you proposed.
3. Report back: what you built, the §10 checklist walked line by line with honest
   pass/fail, anything you had to guess, and anything stale or wrong you noticed in
   the spec or existing code.

**When the spec is silent, ask — do not invent a convention.** The design has a
strong point of view and guessing tends to violate it.

Before running any command that needs approval, state in one plain sentence what it
does and whether it's reversible. Always flag `rm`, `sudo`, `git reset --hard`,
force pushes, and anything touching files outside this project folder. After every
commit, `git push`.

## 12. Stop condition

Stop when §4 is complete and §10 passes. Do not begin build order step 5 (Ambient).
Do not refactor HabitKit beyond what CloudKit compatibility strictly requires. If
you finish early, report what you'd do next rather than doing it.
