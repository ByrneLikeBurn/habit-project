# Habit — product & technical spec

*Working title. v0.3 · 1 August 2026*

---

## 1. Decisions

| | |
|---|---|
| **Platforms** | iOS, iPadOS, macOS, watchOS — one SwiftUI codebase |
| **Accounts** | None. CloudKit private database, keyed to the iCloud account already on the device |
| **Habit model** | Binary check-off **and** counted habits with a target |
| **Heat map** | Customisable range — week / month / year |
| **Nudges** | Quiet push + ambient widgets, non-escalating, granular per habit |
| **NFC** | Shortcuts automations matched on tag UID. **No domain, no server, no recurring cost** |
| **Persistence** | SwiftData + CloudKit, iOS 26 minimum |
| **Price** | Free forever. No ads, no analytics, no paywall surface |
| **Priority** | Focus group + manual reorder + time-based and learned ordering |
| **Pausing** | Vacation Mode (dated, per-trip) and Gentle Mode (armed once, one switch). Logging while paused is **extra credit** |
| **Journalling** | Out of scope as a feature. Obsidian hand-off via the built-in `obsidian://` URI |
| **Removal** | Archive with restore, plus true delete via a 30-day Recently Deleted |
| **Aesthetic** | Pen-and-ink line art, serif type, paper-white default with an ink-dark alternate, one user-chosen accent |

**The one unavoidable cost** is the Apple Developer Program at $99/year. Everything else in this plan is genuinely free to run — which is a direct consequence of the no-domain NFC decision in §7.

---

## 2. The design position

Three rules the whole app is built on.

**The app never uses guilt as a mechanic.** No broken-streak alarms, no red, no "you're falling behind". Missing a day produces silence. The heat map shows the gap honestly and says nothing about it. This is the rule that should never be traded away for engagement metrics.

**Colour carries no meaning.** Heat-map intensity is drawn with hatching density, not hue — identical in greyscale, unaffected by colour-blindness, and unbreakable by whatever accent the user picks. The accent recolours *marks* only; type and rules stay ink, so text contrast is a fixed constant rather than something a user can accidentally destroy.

**Every input is optional.** NFC is a shortcut, not a dependency. Lose a tag and nothing breaks.

### Type & colour tokens

| Token | Paper | Ink |
|---|---|---|
| Background | `#FBFAF6` | `#14120F` |
| Ink (text) | `#16130F` | `#F2EEE5` |
| Secondary text | 70% ink | 70% ink |
| Tertiary text | 60% ink | 52% ink |
| Rule | 16% ink | 18% ink |

Measured contrast: body 17.7:1 / 16.2:1, secondary 6.8:1 / 8.3:1, tertiary 4.8:1 / 5.1:1. All clear WCAG AA at every size; body clears AAA with room, which makes the "heavier ink" setting headroom rather than a rescue.

> The tertiary tint started at 45% ink while I was drawing, measuring **2.97:1 on paper** — a fail, carrying real content. It's now 60%/52%. Worth flagging because it's the trap a monochrome palette invites: with no colour to worry about it's easy to assume contrast is handled, then quietly tint the small text into illegibility.

Serif for habit names, headings and numerals (New York, which supports Dynamic Type properly). SF for labels and controls. Icons are 1.5pt stroked line art on a 48×48 grid, built as custom SF Symbols so they inherit weight and scale with Dynamic Type.

### Two findings from building the mockups

**Texture stops working below ~11pt.** Hatching becomes visual static at small cell sizes, so the year view falls back to solid ink at four opacity steps while week and month keep the hatch. Same data, two renderings, chosen by cell size.

**Pausing needs its own mark, and so does doing it anyway.** A paused day cannot look like a missed day or the whole feature is pointless — and a day you logged *while* paused deserves better than looking like an ordinary Tuesday. The vocabulary is seven states, all colour-free: solid (full), hatched (partial), empty outline (missed), **centred dash (paused)**, **centred diamond (extra credit)**, blank (off-schedule), and outlined (today). A fortnight away reads as a row of dashes with the odd diamond in it — ledger notation meaning *no entry was expected here, and look, one arrived anyway*.

---

## 3. Data model

```swift
@Model final class Habit {
    var id: UUID
    var name: String
    var symbolName: String
    var kind: HabitKind             // .binary | .counted
    var target: Int                 // 1 for binary
    var unit: String?
    var scheduleMask: Int           // weekday bitmask, 127 = daily
    var sortIndex: Int
    var isFocus: Bool               // Focus group — nudges + widget + complication
    var gentleEnabled: Bool         // armed for the global Gentle Mode switch
    var vacationByDefault: Bool     // pre-ticked when a trip is created
    var obsidian: ObsidianConfig?   // nil = no hand-off
    var tagNickname: String?        // cosmetic only — see §7
    var createdAt: Date
    var archivedAt: Date?           // hidden from Today, history intact, restorable
    var deletedAt: Date?            // in Recently Deleted; purged 30 days later
    var nudge: NudgeConfig?
    @Relationship(deleteRule: .cascade, inverse: \LogEvent.habit) var events: [LogEvent]
    @Relationship(deleteRule: .cascade, inverse: \Pause.habit)    var pauses: [Pause]
}

@Model final class LogEvent {       // append-only
    var id: UUID
    var habit: Habit?
    var dayKey: Int                 // 20260801, in the user's calendar
    var delta: Int                  // +1 / -1
    var source: LogSource           // .manual .watch .widget .shortcut .siri .control
    var timestamp: Date
    var deviceID: String
}

@Model final class Pause {
    var id: UUID
    var habit: Habit?
    var startDay: Int
    var endDay: Int?                // nil = open-ended (Gentle Mode)
    var reason: PauseReason         // .vacation | .gentle | .manual
}
```

**Why append-only.** A counted habit incremented on the Watch and the iPhone inside the same sync window would silently lose a tick under last-writer-wins on a single `value` field. Storing deltas makes concurrent increments commutative, which is the only conflict resolution that actually works across four devices. Day totals are derived and cached in memory, never stored.

**Day boundaries.** `dayKey` is computed in the user's calendar with a settable day-start hour (default 04:00), so a midnight log lands on the right day. It's fixed at write time — crossing timezones never rewrites history.

**Streaks, pauses and extra credit.** A paused day with no log is skipped in streak arithmetic — it neither breaks a run nor extends it. A twelve-day run, a week in Portugal, and three more days is a fifteen-day run with a gap, not two short ones.

A paused day *with* a log is extra credit: it extends the run and is counted separately in stats ("Extra credit · 2 days"), but its absence would never have cost anything. So the arithmetic is strictly one-directional — **pausing can only ever help you.** It's worth writing the streak function's unit tests around exactly that invariant, because it's the kind of rule that quietly erodes the first time someone "simplifies" the calculation.

This all has to live in the model, not the view, which is why `Pause` is a record rather than a UI flag.

---

## 4. SwiftData or Core Data — the verdict

**SwiftData.** For this app, in 2026, it isn't close.

SwiftData reached production maturity with iOS 26: the serious iOS 18.x bugs are fixed, model inheritance landed, and many fixes were back-deployed. Its one genuinely disqualifying limitation — no support for CloudKit *shared* databases — is irrelevant here, because a private-only, no-account app never touches sharing. Meanwhile the code is a fraction of the Core Data equivalent, which matters when one person is maintaining four platform targets for free.

Since this is a brand-new app with no legacy users, set the deployment target at **iOS 26 / macOS 26 / watchOS 26** and take the mature version. Nothing is gained by supporting iOS 17 here.

Two production traps, both of which bite silently:

**1. CloudKit schema must be deployed to Production manually.** Development supports just-in-time schema creation; Production forbids it. An App Store build talks to Production, so if you haven't pushed the schema in the CloudKit Console (Schema → Deploy Schema Changes), sync fails completely for every real user while working perfectly in Xcode. This must be repeated before *every* release that touches the model. Put it in a release checklist on day one — it is the single most common way CloudKit apps ship broken.

**2. Only lightweight migrations are safe.** You cannot change a field's type, rename without data loss, or split a model — and a custom migration ends CloudKit sync. So the schema discipline is: **additive only, forever.** New fields are optional or defaulted; nothing is ever renamed or retyped; deprecated fields are left in place and ignored. Every schema change ships as a tested `VersionedSchema`.

And ship JSON export in v1, so no user is ever trapped by either of the above.

---

## 5. Ordering, focus, and the "now" line

No cap on habits, but three mechanisms keep a long list from feeling like a to-do list.

**Focus.** A group above the rule. Only Focus habits send nudges, and only they appear in the small widget and the watch complication. Everything else is loggable but quiet. The first habit a new user creates is automatically Focus, which is how "start with one" survives contact with a list of twenty.

**Ordering** has three modes:

- **Manual** — drag to reorder. `sortIndex`.
- **By time** — ordered by each habit's nudge time.
- **Smart** — ordered by when you actually tend to log each habit.

Smart ordering is computed entirely on-device: keep a rolling window of the last ~60 log timestamps per habit, take the *circular* median of the local hour (circular because a habit logged at 23:40 and 00:20 has a median near midnight, not near noon), and sort by it. Habits with fewer than ten logs fall back to their nudge time, then to manual order. Recomputed once daily.

**The now line.** A hairline across the list marking the current time. Habits above it are ones you'd usually have done by now; below it is what's still ahead. It is deliberately *not* a deadline — nothing above the line is styled as late, overdue, or red. It's a horizon, not a scoreboard. This is the subtlest piece of the design and the easiest to accidentally turn into a nag, so it's worth protecting in review.

---

## 6. Pausing: two different tools

These solve different problems and shouldn't be merged.

**Vacation Mode** — planned, dated, per-trip. Pick habits (pre-ticked from `vacationByDefault`), set an end date, and it resumes itself. The end date is the point: you can't come home and stay accidentally paused for a month.

**Gentle Mode** — unplanned, undated, one switch. Each habit carries a *Gentle Mode enabled* checkbox that you set once, in calmer weather, choosing which habits are the ones that can safely rest. When a hard week arrives, one global toggle rests all of them at once — no dates, no selection, no decisions on the day you least want to make any. It stays on until you turn it off. Habits you didn't flag carry on untouched.

Both write `Pause` records, so both produce dashes rather than empty squares, and neither damages a streak. Paused habits leave the Today list but stay loggable — from search, from the habit's own screen, from a widget, from a tag. Doing one is extra credit, never an obligation reappearing.

**The one risk in Gentle Mode is that it's open-ended** — someone flips it during a rough fortnight and finds it still on in November. The mitigation must not violate the no-nagging rule, so: no notification, ever. Instead, after 14 continuous days, a quiet line appears in-app under the Today header — *"Gentle Mode has been on for two weeks."* Stated, not asked. Dismissible. That's the whole intervention.

---

## 7. NFC without a domain

**Short answer to "can it be done on-device": the universal-link version cannot, but a better version can.**

iOS background tag reading only acts on a specific set of URL schemes — `http`/`https`, `mailto`, `tel`, `sms`, `facetime`, Apple Maps links, and HomeKit's `X-HM`. Custom URL schemes are ignored. So launching *your* app from a background tap requires an `https` URL on a domain you own, with an associated-domains entitlement and an `apple-app-site-association` file. There is no on-device substitute for that specific mechanism.

**So we use a different mechanism.** Shortcuts personal automations include an NFC trigger, and it matches tags by their **hardware UID** — the tag's contents are irrelevant. Our app exposes a `LogHabitIntent` App Intent, which appears in Shortcuts as an action. The user creates one automation per tag: *When this tag is scanned → Log "Drink water"*. Crucially, turning off **Ask Before Running** makes it fire with no confirmation and no notification.

The comparison is not close:

| | Universal link | Shortcuts automation |
|---|---|---|
| Domain + hosting | Required, forever | None |
| Recurring cost | ~$12/yr, and every tag dies if it lapses | Zero |
| On tap | Banner, always. Never silent | **Silent** |
| Setup per tag | One in-app step | Three steps, guided, first time only |
| Fails if | Server down, cert expired, AASA malformed | Nothing external to fail |

For a free-forever app the domain route is strictly worse: it adds a permanent liability whose failure mode is *every tag anyone ever stuck to anything stops working*. The Shortcuts route trades a one-time setup walkthrough for zero infrastructure and a better tap.

**What the app does:** writes a plain identifier to a blank tag via `NFCNDEFReaderSession` (needs only the `com.apple.developer.nfc.readersession.formats` entitlement — no domain), then walks the user through the automation with a deep link to Shortcuts. It also offers in-app foreground scanning for people who'd rather not use Shortcuts at all.

**Honest limitations:**

- **We cannot verify the automation exists.** The app never sees the tag UID — Shortcuts owns that. So `tagNickname` is a label for the user's benefit, and the setup screen is instructional rather than confirmatory. The walkthrough must therefore be genuinely clear, since we cannot detect a half-finished setup.
- iPhone XS or later. Requires the phone unlocked at least once since boot, airplane mode off, and no camera, Apple Pay, or active Core NFC session.
- iPhone only. No third-party NFC on Watch, iPad, or Mac.
- Hardware: NTAG213 is ample and costs pennies. Metal surfaces — a bottle, a fridge — need ferrite-backed tags or they won't read.
- Dedupe repeat taps of the same habit within 8 seconds.

---

## 8. Obsidian

Habit stays a habit tracker. Obsidian keeps the writing. The hand-off uses Obsidian's **built-in** URI scheme, which is important — no community plugin is required for the default path.

The built-in scheme supports `open`, `new` and `search`, with `vault`, `file`, `name`, `content`, `append`, `overwrite` and `silent`. That's everything we need:

```
obsidian://new?vault=Commonplace
  &file=Habits%2F2026-08-01
  &content=-%20%5Bx%5D%20Read%20%C2%B7%2021%3A47%0A
  &append=true
  &silent=true
```

### Write to our own file, not the daily note

The default target is `Habits/{{date}}.md` — a file Habit owns exclusively — rather than the user's daily note. This is the design decision that matters most here.

Appending to a daily note that Obsidian may have open, that Obsidian Sync or iCloud may be mid-write on, and that the user may be typing in, is a recipe for conflict copies and lost paragraphs. Writing to a file nothing else touches has none of that risk, and the user gets the integrated result anyway by embedding one line in their daily note template:

```markdown
![[Habits/{{date}}]]
```

Targeting the daily note directly is offered as an option for people who want it, but that route needs the **Advanced URI** community plugin (`obsidian://adv-uri?vault=…&daily=true&mode=append&data=…`), and the UI should say so plainly rather than letting someone discover it by failure.

### Three modes, per habit

- **Append a line** — writes and stays in Habit (default)
- **Open the note** — jumps to today's file for actual writing
- **Nothing** — off, which is the default for a new habit

The line is a user-editable template: `- [x] {{habit}} · {{time}}`, with `{{done}}`/`{{target}}` available for counted habits. Extra-credit logs can be included or excluded.

### Honest limitations

- **On iPhone, opening a URL scheme foregrounds the target app.** `silent=true` stops Obsidian from *navigating* to the note, but iOS will still switch apps for a moment. There's no third-party way around this. On macOS it's far less intrusive.
- Obsidian must be installed and the vault name must match exactly. We can't enumerate vaults, so it's typed once and validated by attempting a write.
- watchOS has no Obsidian, so logs from the Watch queue and write on next iPhone launch.
- A batch of logs in quick succession should coalesce into one append rather than four app switches.

---

## 9. Archive, delete, export

Three states, deliberately.

**Archive** hides a habit from Today and every list, keeps all history, and is fully restorable. This is the right answer for "I don't do this any more" and should be what the app nudges people toward.

**Delete** moves the habit to **Recently Deleted** for 30 days — still restorable, no history lost yet. This is the safety net for the far more common case of a habit added by mistake or a name typo fixed by re-creating.

**Delete now**, from inside Recently Deleted, is the real one: the habit and every `LogEvent` and `Pause` are removed, and the deletion propagates through CloudKit to every device. The confirmation states the cost in days rather than asking "are you sure" — *"This removes 412 logged days, going back to March 2024"* — offers an export first, and puts the safe option under the thumb. It's the only place in the app that uses the word *permanently*; everywhere else, absence is temporary by design.

**Export** is JSON, complete, and available at any time — not only from the delete path. It's also the insurance policy against the SwiftData migration constraint in §4.

One implementation note: the 30-day purge must run from a date comparison at launch, not a scheduled task, since a device that's off for two months should still purge correctly on next open. And the purge must be idempotent across devices — two devices waking on day 31 should not race to delete the same records.

---

## 10. Architecture

One shared Swift package (`HabitKit`: models, day and pause math, ordering, nudge scheduling, formatting) consumed by the iOS/iPadOS app, a native SwiftUI Mac app (not Catalyst — the sidebar layout wants it), the watchOS app, a widget extension, and an App Intents extension.

**One write path.** `LogHabitIntent` serves the widget button, the Shortcuts/NFC route, the Control Center control, the Action button, and Siri. Every `LogEvent` in the system is written by exactly one piece of code.

**Watch sync.** CloudKit reaches watchOS directly but is slow when the watch is alone. Add WatchConnectivity as a fast path for the common case, with CloudKit as source of truth — WatchConnectivity delivers events, CloudKit reconciles them. Never let them race.

**Nudge engine.** Constraints enforced in code, not copy: a hard daily cap (default 3, ceiling 6), quiet hours (default 22:00–08:00), cancellation when the habit is already logged, identical wording on day 1 and day 100, no reference to missed days unless explicitly opted in, and `.passive` interruption level so the screen never lights up. Paused habits schedule nothing. Three tones — *Invitation*, *Plain*, *Silent* — with a small phrase bank per habit so repetition varies without becoming cute.

---

## 11. Accessibility

Several of these change the data model or layout, so they're v1 or they're never.

- **Dynamic Type to AX5** everywhere. Habit rows reflow to two lines; the tab bar falls back to the large-content viewer.
- **VoiceOver on the heat map.** 365 focusable cells is hostile. Cells group by week with a summary ("Week of 14 July, five of seven days, two paused"), individual days reachable by drilling in, plus an `AXChartDescriptor` so a year is available as an audio graph.
- **Differentiate Without Colour** needs no special handling — the encoding is already texture-based. This is the payoff for the monochrome constraint.
- **Increase Contrast** maps to "heavier ink": thicker strokes, darker rules, solid rather than hatched fills.
- **Reduce Motion** removes the check-mark draw-on and the sheet spring.
- **Targets** at 44×44 minimum; heat-map cells get an enlarged touch region and a "larger cells" setting.
- **Voice Control** labels on every control; **Full Keyboard Access** and complete menu-bar commands on Mac; **Switch Control** ordering verified per screen.
- Haptics on log, with an off switch.

---

## 12. Build order

1. **Core loop** — model, Today, binary + counted logging, local only. Usable on day one.
2. **History** — heat map with all three ranges and the full seven-state mark vocabulary, habit detail, Progress.
3. **Pausing** — `Pause` records, Vacation Mode, Gentle Mode, extra-credit and pause-aware streak maths. Early, because it touches every history calculation downstream, and retrofitting it later means re-deriving every stat in the app.
4. **Sync** — CloudKit, with the Production schema deployment in the release checklist from the first build. Test with deliberately conflicting offline edits on two devices before anything else ships.
5. **Ambient** — widgets, App Intents, Watch app and complication.
6. **Nudges** — scheduling engine and settings.
7. **Ordering** — Focus, manual, by-time, then Smart once there's enough history for it to mean anything.
8. **NFC** — tag writing and the Shortcuts walkthrough. No longer blocked on infrastructure, so this can move earlier if you want it sooner.
9. **Obsidian** — file-path append, then the daily-note option. Independent of everything else; can slot in wherever it fits.
10. **Removal** — archive, restore, Recently Deleted, purge, JSON export. Export should arguably come earlier, since it's the escape hatch for every other risk in this document.
11. **Polish** — accessibility audit with VoiceOver on device, Dynamic Type sweep, App Store assets.

---

## 13. Still open

1. **Your vault's daily-note format.** If your daily notes use a template with fixed headings, the `![[Habits/{{date}}]]` embed should point at the right place in it — and if you'd rather Habit append under a specific heading, that's the Advanced URI route rather than the built-in one. Worth deciding before I design the setup flow in detail.
2. **Counted habits in Obsidian.** One line per increment (eight lines for eight glasses) or one line per day, rewritten as the count changes? Rewriting means `overwrite`, which means Habit owning that file absolutely — which it does, so it's viable, just noisier on sync.
3. **Extra credit in the year view.** At year scale a diamond is too small to read. Options are collapsing extra credit to look like an ordinary completion at that zoom, or giving the year view a slightly different treatment. Only visible once there's real data, so it can wait.

---

*Sources for platform claims: Apple's [Core NFC background tag reading](https://developer.apple.com/documentation/corenfc/adding-support-for-background-tag-reading) documentation and [GoToTags'](https://gototags.com/help/ios/nfc/reading/background) summary of supported schemes; Apple's [Shortcuts user guide](https://support.apple.com/en-us/guide/shortcuts/apd602971e63/ios) on personal automation triggers and Ask Before Running; [Obsidian URI](https://obsidian.md/help/Extending+Obsidian/Obsidian+URI) documentation and the [Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri) plugin README; [fatbobman](https://fatbobman.com/en/snippet/why-core-data-or-swiftdata-cloud-sync-stops-working-after-app-store-login/) on CloudKit Production schema deployment; [FractalDev's](https://fractal-dev.com/blog/ios-databases) 2026 iOS database guide on SwiftData maturity.*
