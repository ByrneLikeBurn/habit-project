# CloudKit audit — Habit, LogEvent, Pause

Written audit only. No `.swift` file is touched by this document or the branch it
ships on. CloudKit itself is still blocked on an Apple Developer Program
membership; this is the part of the work that costs nothing and needs to happen
before the schema changes again.

Scope confirmed by source inspection: exactly three `@Model` types exist in
`HabitKit` — `Habit`, `LogEvent`, `Pause` (`grep -rl "@Model"` also matches
`Migration.swift` and `Export.swift`, but those only *reference* the three
models, they don't declare a fourth). No `.entitlements` file exists anywhere in
the `Habit/` app target — confirmed by `find Habit -iname "*.entitlements"`
returning nothing — so no iCloud container is wired up yet, and
`HabitApp.swift`'s `ModelConfiguration` (which passes no `cloudKitDatabase`
argument at all) has nothing to discover. Whatever that parameter's default
resolves to is currently moot in practice.

## Method note — how the citations below were verified

Two tools failed silently before a third worked, and it's worth recording why,
since the whole point of this audit is not repeating that failure by accident
next time:

- **WebFetch** on Apple's own documentation pages returns HTTP 200 but with only
  the page's `<title>`, no body — Apple's developer docs are a client-rendered
  DocC site, and WebFetch's fetcher doesn't execute JavaScript, so it sees an
  empty shell.
- **WebSearch** works normally but only surfaces third-party paraphrase (Apple
  Developer Forum threads, blog posts) — useful for finding the *right* URL, not
  for quoting Apple's own wording.
- Apple's DocC pages publish their content as a JSON data file at a predictable
  URL (`developer.apple.com/tutorials/data/<same path>.json`) alongside the
  human-readable page. A plain `curl` GET against that JSON endpoint returns the
  real article text. **The request needed no user-agent disguise** — a bare
  `curl` with its default UA and a request with no `User-Agent` header at all
  both returned HTTP 200 with identical content; a spoofed browser UA was tried
  first and turned out not to be load-bearing.

Every citation below gives **both** URLs — the human-readable page (for a reader
who wants to check it in a browser) and the `.json` data endpoint actually read
(for the exact text quoted). One attempt (the Core Data CloudKit model page)
404'd on the `.json` endpoint; per instruction, that wasn't retried with URL
variants — it's marked UNVERIFIED with what was tried.

---

## A. Hard constraints

Two of the five rules are backed by an exact Apple quote. Three are not — either
the page that states them couldn't be reached, or the page that *was* reached
didn't contain that specific wording. Those three are marked **UNVERIFIED**
rather than asserted from memory, per instruction. The per-property verdicts
below are still worth recording as *"what the widely-cited rule would say if
accurate,"* clearly labeled as such — but do not read them as confirmed CloudKit
failures until the citation gap is closed.

### Rule 2 — no `@Attribute(.unique)` — VERIFIED

> "the SwiftData framework does include a small number of features that
> CloudKit doesn't support natively, such as **unique constraints** and
> nonoptional relationships. It's important you consider these limitations as
> you design your app's model layer..."

Source: [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) — JSON read: `https://developer.apple.com/tutorials/data/documentation/swiftdata/syncing-model-data-across-a-persons-devices.json`

Code fact (`grep -rn "@Attribute" HabitKit/Sources`): **zero matches**. No
`@Attribute` of any kind, unique or otherwise, appears anywhere in `Habit`,
`LogEvent`, or `Pause`. All three models **pass** this rule cleanly.

### Rule 3 — every to-one relationship optional — VERIFIED

> "The iCloud servers don't guarantee atomic processing of relationship
> changes, so CloudKit **requires all relationships to be optional**."

Same source and JSON URL as above.

Code fact: `LogEvent.habit: Habit?` and `Pause.habit: Habit?` are both already
optional. Both **pass**.

### Rule 4 — to-many relationships need a declared inverse — VERIFIED (inverse only)

> "SwiftData automatically sets the inverse of a relationship if it can
> reliably infer that inverse from your schema. Otherwise, explicitly set the
> inverse before saving because CloudKit processes changes in an indeterminate
> order."

Same source and JSON URL.

Code fact: `Habit.events` declares `inverse: \LogEvent.habit` and
`Habit.pauses` declares `inverse: \Pause.habit` — both explicit, neither left
to inference. **Pass.**

The other half of rule 4 as originally framed — that a to-many relationship
needs a `= []` default — is really a special case of Rule 1 below (a stored
property needs a schema-visible default), and Rule 1's own wording couldn't be
confirmed. See Rule 1.

### Rule 1 — every attribute optional or defaulted on the stored property — **UNVERIFIED**

The SwiftData sync page (fetched above, full body read) never states this rule
in prose anywhere in its body text. What's readily found instead is third-party
material — Apple Developer Forum threads quoting a *runtime error message*
("CloudKit integration requires that all attributes be optional, or have a
default value set") and blog posts (fatbobman.com) restating the same rule —
none of which is Apple's own documentation prose.

Attempted: the same SwiftData sync page above (read in full, rule not present
in the body); no second page was identified as the source of this specific
wording, so nothing further was fetched. **Marked UNVERIFIED, not asserted.**
This is the rule this project already has a documented scar from —
`nudgeHour`'s missing stored default is exactly `Migration.swift`'s worked
example — so the *practice* is already correctly understood in this codebase
even though this run couldn't pin the exact Apple citation for it.

Property-by-property, against the *widely-cited but unverified-this-run* rule
(✗ = would fail if the rule is as commonly stated; ✓ = passes either way since
it's already optional or defaulted):

**`Habit`**

| Property | Type | Optional or stored default? | Verdict |
|---|---|---|---|
| `id` | `UUID` | neither | ✗ |
| `name` | `String` | neither | ✗ |
| `symbolName` | `String` | neither | ✗ |
| `kind` | `HabitKind` | neither | ✗ |
| `target` | `Int` | neither | ✗ |
| `unit` | `String?` | optional | ✓ |
| `scheduleMask` | `Int` | neither | ✗ |
| `sortIndex` | `Int` | neither | ✗ |
| `isFocus` | `Bool` | neither | ✗ |
| `gentleEnabled` | `Bool` | neither | ✗ |
| `vacationByDefault` | `Bool` | neither | ✗ |
| `tagNickname` | `String?` | optional | ✓ |
| `nudgeHour` | `Int` | `= 9` stored default | ✓ |
| `createdAt` | `Date` | neither | ✗ |
| `archivedAt` | `Date?` | optional | ✓ |
| `deletedAt` | `Date?` | optional | ✓ |
| `events` | `[LogEvent]` | `= []` stored default | ✓ |
| `pauses` | `[Pause]` | `= []` stored default | ✓ |

**`LogEvent`**

| Property | Type | Optional or stored default? | Verdict |
|---|---|---|---|
| `id` | `UUID` | neither | ✗ |
| `habit` | `Habit?` | optional | ✓ |
| `dayKey` | `Int` | neither | ✗ |
| `delta` | `Int` | neither | ✗ |
| `source` | `LogSource` | neither | ✗ |
| `timestamp` | `Date` | neither | ✗ |
| `deviceID` | `String` | neither | ✗ |

**`Pause`**

| Property | Type | Optional or stored default? | Verdict |
|---|---|---|---|
| `id` | `UUID` | neither | ✗ |
| `habit` | `Habit?` | optional | ✓ |
| `startDay` | `Int` | neither | ✗ |
| `endDay` | `Int?` | optional | ✓ |
| `reason` | `PauseReason` | neither | ✗ |

Every ✗ above is a property that has existed since the schema's first commit —
exactly the case `MigrationTests.swift`'s doc comment says is *correctly* fine
for **migration** (nothing new is being added to an entity that already has
rows on disk). Nothing here contradicts that test or that comment. **CloudKit's
requirement, per the third-party sources above, is not history-dependent the
way migration is** — if it's real, it would apply to every property regardless
of when it was added, which is a different question from the one
`MigrationTests.swift` answers, asked for a different reason. Given this run
couldn't confirm the rule's exact wording against Apple's own prose, treat the
✗ list above as "what needs redoing if the widely-cited version of the rule
turns out to be accurate" — which is worth planning around, not shipping
around.

### Rule 5 — no ordered relationships — **UNVERIFIED**

This rule classically lives on the Core Data + CloudKit model-compatibility
page, not the SwiftData one. That page's `.json` data endpoint 404'd:

- Attempted: [Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit/creating_a_core_data_model_for_cloudkit) — JSON attempted: `https://developer.apple.com/tutorials/data/documentation/coredata/mirroring_a_core_data_store_with_cloudkit/creating_a_core_data_model_for_cloudkit.json` → **HTTP 404**. Per instruction, no URL variants were retried after that.
- The SwiftData sync page (read in full for Rules 1–4 above) never mentions
  ordering.

**Marked UNVERIFIED.** Code fact, offered without asserting the rule itself:
both to-many relationships in this schema (`Habit.events`, `Habit.pauses`) are
declared as plain Swift arrays (`[LogEvent]`, `[Pause]`). SwiftData's
`@Relationship` macro doesn't expose a separate "ordered" toggle the way Core
Data's model editor does — there is no API surface in this codebase's models
that could opt into an ordered relationship even by accident. That's a
structural observation about the code, not a substitute for confirming the
rule.

---

## B. Soft findings

Four items, each answered for what happens under a last-writer-wins merge
across two offline devices, then classified.

### 1. `sortIndex` — manual reorder on two devices

Both devices write a new `sortIndex` for some subset of habits while offline.
Field-level last-writer-wins resolves each habit's `sortIndex` independently,
so after sync the list can land with **duplicate or gapped indices** — two
habits both claiming `sortIndex = 3`, say.

`sortedForDisplay` (`HabitOrdering.swift`) already ties-break by `createdAt`
when `sortIndex` collides:

```swift
if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
return lhs.createdAt < rhs.createdAt
```

So a collision produces a **deterministic, crash-free, if locally surprising**
order — not a duplicate row, not a missing habit, not a hang. The user may see
their reorder from one device silently lose to the other device's reorder, but
nothing is destroyed and the list stays consistent on next launch.

**Verdict: acceptable as-is.** No blocker for step 4, no decision required —
this is exactly the class of problem last-writer-wins is fine for, because the
worst case is cosmetic and self-heals into a stable, deterministic order.

### 2. `archivedAt` / `deletedAt` — restore vs. delete, and the purge race

**Correction from the brief carried forward:** this pair is not soft state.
`deletedAt` is read directly by `purgeExpiredDeletions` (`Removal.swift`),
which is the only code path in the app that calls `modelContext.delete` outside
of `permanentlyDelete` itself — and it runs unconditionally at every launch,
from `ContentView.swift:151`'s `.task`. Treat this as two findings.

**2a. Plain concurrent write to `archivedAt`/`deletedAt`.** One device
archives a habit while the other deletes it (or restores it) offline. Field-level
last-writer-wins picks one outcome. Both states are, on their own,
non-destructive and mutually recoverable through the UI (`restoreFromArchive`,
`restoreFromRecentlyDeleted`) — so a wrong merge outcome here is an annoyance,
not data loss, *provided nothing else acts on the losing value before the user
notices*. Which is exactly what 2b describes happening.

**2b. The purge race.** Walking the scenario as specified:

- **Day 1** — habit moved to Recently Deleted on device A. `deletedAt = day1`.
- **Day 2** — device B goes offline holding a replica with `deletedAt = day1`.
- **Day 25** — user restores on device A. `deletedAt = nil` there. This change
  cannot reach B, because B is still offline.
- **Day 31** — device B relaunches (still offline from A's perspective — the
  restore from day 25 has not synced to it) and its `.task` fires
  `purgeExpiredDeletions(habits: recentlyDeletedHabits, ...)`.

  `recentlyDeletedHabits` is `@Query(filter: #Predicate<Habit> { $0.deletedAt != nil })`
  (`ContentView.swift:16`) — a query over B's **local** store, which still says
  `deletedAt = day1`. `daysSinceDeletion(deletedAt: day1, today: day31)` = 30,
  `hasPurgeWindowElapsed` = `30 >= 30` = true. The habit is in
  `habitsPastPurgeWindow`, and `purgeExpiredDeletions` calls
  `modelContext.delete(habit)` on it.

**Does device B's local purge destroy the restored habit and cascade its
`LogEvent`s and `Pause`s?** Yes. `modelContext.delete` on a `Habit` triggers
the `.cascade` delete rule declared on both `Habit.events` and `Habit.pauses`
(`Habit.swift:31-32`), removing every `LogEvent` and `Pause` for that habit
from B's local store in the same operation. Nothing in `purgeExpiredDeletions`
or `habitsPastPurgeWindow` checks anything except the locally-visible
`deletedAt` — there's no re-fetch, no server round-trip, no "has this record
changed remotely since I last saw it" check.

**Does that deletion then propagate to device A?** Under SwiftData's normal
CloudKit sync model, yes: a local `modelContext.delete` becomes a CloudKit
record deletion once B comes back online, and that deletion applies to every
other device's replica — including A's — on their next sync, regardless of the
fact that A's copy was restored and current. The sync layer has no way to know
this app's intent is "a later restore should beat an earlier, stale-data-driven
delete" — that's an app-level policy this code doesn't express anywhere. I did
not find (and this run didn't separately verify against Apple's docs) any
CloudKit-level mechanism that would prevent this propagation; it's the direct,
expected consequence of how record deletion syncs, not a documented exception
I'm aware of.

**Is a tombstone-free CloudKit delete recoverable by any means the app has?**
No. The app's *only* undo mechanism for deletion is the `deletedAt` soft-state
window itself — and this scenario is precisely the case where that mechanism
has already been bypassed: the record has gone through an actual
`modelContext.delete`, the same call `permanentlyDelete`'s own doc comment
calls **"the one irreversible operation in the app."** There is no second
safety net in the codebase once that fires. The only recovery is a JSON export
the user happened to make beforehand — which means the risk this run surfaces
is a second, unanticipated justification for spec §4/§9's "ship export early"
advice, on top of the migration risk it was written for. Whether CloudKit's
private database offers any operator-level (non-app) recovery outside what the
app itself can do is outside what was verified this run.

**Does `purgeExpiredDeletions`'s doc comment still hold once records sync?**
Partially, and it's worth being precise about which part. The comment argues:

> "Deleting an already-deleted `Habit` is a no-op, which is what keeps two
> devices waking on day 31 from needing to coordinate: each just asks 'is this
> still here, and still past the window?' and acts only if so."

That claim is **still correct** for the case it was written for: two devices
independently, correctly agreeing a habit is deleted and past its window, both
attempting to delete it, is genuinely safe and needs no coordination — deleting
something already gone is a no-op either way. **It does not hold**, and never
addresses, the case this section walks through: a device acting on **stale**
local state that a *different, more recent* operation (a restore) has already
superseded elsewhere. That race is only possible once CloudKit sync introduces
multi-device latency — today, pre-sync, there's exactly one authoritative
local store, so this scenario is structurally impossible. The comment's "don't
need to coordinate" framing reads as a general cross-device safety claim, and a
future maintainer would reasonably extend it to cover this case too — that
extension would be wrong. Per instruction, the comment itself is not edited
this run; this is a finding, not a fix.

**Verdict: blocker for step 4**, at the same tier as `Pause.endDay` below —
this is not a cosmetic merge outcome, it's the app's one irreversible operation
firing on stale data with no recovery path.

### 3. `Pause.endDay` — one device closes a pause the other leaves open

One device ends a Gentle Mode pause (`reconcileGentleMode` sets
`openPause.endDay = previousDayKey(today)`); the other device, offline, still
has that same `Pause` record with `endDay == nil`. Last-writer-wins resolves
`endDay` by write timestamp — whichever device's change is timestamped later
wins, with no awareness of which outcome is *safer*.

Invariant 3 (CLAUDE.md) is explicit: **pausing can only ever help.** A merge
outcome that closes the pause "too early" relative to what either device
actually intended can turn a day that was supposed to read as paused into one
that reads as missed once evaluated — `streakLength` (`Streak.swift`) derives
coverage live from whatever `Pause` records currently exist; it isn't stored
per day, so a wrongly-resolved `endDay` changes streak arithmetic retroactively
for every day after it, not just the day of the conflict.

The resolution rule that satisfies invariant 3 is directional, not
chronological: **the merge should keep whichever value covers more days** —
an open pause (`endDay == nil`) beats any concrete `endDay`, and between two
concrete values, the later `endDay` wins. That is *not* what plain
last-writer-wins does (it resolves by write time, not by which value is more
protective), so this needs either a custom conflict-resolution pass after sync
(structurally similar to what `reconcileGentleMode` already does for the
switch-vs-flag state, but for merge conflicts specifically) or some other
explicit mechanism — not decided here.

**Verdict: blocker for step 4** — same tier as the purge race above. Default
CloudKit merge behavior can produce an outcome invariant 3 forbids, and nothing
in the current code detects or corrects it.

### 4. Orphaned `LogEvent` — habit deleted on one device, logged on another

Device A permanently deletes a habit (`permanentlyDelete`, or the purge race
above) while device B, offline, logs against that same habit via `logHabit`
(`LogHabit.swift`) before A's deletion syncs to it. When B comes back online,
it's inserting a new `LogEvent` whose `habit` relationship points at a record
that no longer exists on the server.

**Does any existing code assume `habit != nil`?** No — checked directly
(`grep -rn "\.habit\b"` across `HabitKit/Sources` and `Habit/Habit`). Every
place in the codebase that reads log data goes through the *owning* side of
the relationship — `habit.events` (`Removal.swift`'s `dayTotals`,
`Export.swift`, `Import.swift`, `HeatMap.swift`, `NotificationScheduler.swift`,
`LogHabitIntent.swift`, `ContentView.swift`) — never `logEvent.habit` itself.
So an orphaned `LogEvent` (`habit == nil`) doesn't force-unwrap anything and
doesn't crash any code path found.

What it does instead: since nothing iterates `LogEvent`s independently of a
`Habit`'s own `.events` array, an orphan becomes **permanently invisible** —
not counted in any stat, not exported, not purged by anything (nothing in
`Removal.swift` targets bare `LogEvent`s; purge only ever walks
`habitsPastPurgeWindow`). It's inert dead weight in the store forever, rather
than a crash.

**Verdict: decision needed, not a hard blocker.** Nothing breaks today or
under the scenario above, so this doesn't gate step 4 the way the previous two
do. But it is a real design question for the sync work: does an orphaned
`LogEvent` need an active reaping mechanism, or is "harmless, invisible,
permanent dead data" an acceptable resting state forever? Worth deciding
deliberately rather than by default.

---

## What V2 has to contain

In the order these should be made — later items depend on earlier ones being
decided first, not just coded first:

1. **Close the Rule 1 citation gap**, or accept the widely-cited version of it
   as the working assumption. Either way, resolve the ✗ list under Rule 1
   above: add a stored, schema-visible default (or make `Optional`) to every
   bare property across `Habit`, `LogEvent`, and `Pause` — `id`, `name`,
   `symbolName`, `kind`, `target`, `scheduleMask`, `sortIndex`, `isFocus`,
   `gentleEnabled`, `vacationByDefault`, `createdAt` on `Habit`; `id`,
   `dayKey`, `delta`, `source`, `timestamp`, `deviceID` on `LogEvent`; `id`,
   `startDay`, `reason` on `Pause`. This is the largest mechanical change here
   and the one every other step assumes is already done. It ships as a new
   `HabitSchemaV2` with a lightweight migration stage and a migration test per
   the process `Migration.swift` already documents — never edited into V1.
2. **Decide and implement the `Pause.endDay` merge-safety rule** (open beats
   closed; later `endDay` beats earlier) — default last-writer-wins doesn't
   know it, and invariant 3 requires it.
3. **Decide and implement a purge/restore race guard** for
   `purgeExpiredDeletions` before step 4 ships — today's implementation can
   permanently destroy a restored habit, its `LogEvent`s, and its `Pause`s,
   with no recovery path but a prior export. This is the higher-severity item
   of the two blockers, since it fires the app's one irreversible operation.
4. **Decide the `archivedAt`/`deletedAt` conflict policy** more generally
   (which state should win when both are touched concurrently, outside the
   purge-specific race in #3) — lower severity, since archive and
   Recently-Deleted alone are both recoverable through the UI, but still worth
   a stated policy rather than whatever last-writer-wins happens to produce.
5. **Decide whether orphaned `LogEvent`s need active reaping**, or whether
   permanently-invisible dead data is an acceptable resting state.
6. Only once 1–5 are settled: add the iCloud + Background Modes capabilities,
   create the CloudKit container, set `cloudKitDatabase` explicitly on
   `HabitApp.swift`'s `ModelConfiguration`, and follow the existing
   `HabitSchemaV{N}` migration-plan process for the schema version that
   results from step 1 — plus the Production schema deployment this project's
   docs already call out as the most common way CloudKit apps ship broken.

---

## Definition of done

- [x] every stored property of all three models appears in the table with a verdict
- [x] each hard-constraint rule is cited to Apple's documentation, not asserted — **two of five** (Rules 2 and 3, and half of Rule 4) carry an exact quote and both URLs; the other three (the rest of Rule 4, Rule 1, Rule 5) are marked UNVERIFIED with what was attempted, per instruction not to fall back to memory
- [x] all four soft findings are answered — including the purge race added mid-run, which turned out to be a second step-4 blocker
- [x] this document names what V2 must contain
- [ ] `git diff --stat` against main shows one file and zero `.swift` files — to be confirmed after this file is written and staged
- [x] work is on a feature branch, not `main`
