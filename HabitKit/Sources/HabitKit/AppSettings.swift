import Foundation
import SwiftData

/// Cross-device app settings — named generally because it is the eventual
/// home for `dayStartHour` and the nudge settings, not because it's meant to
/// grow speculative fields ahead of need. This run adds only Gentle Mode's
/// global switch state, moved out of `UserDefaults` (which doesn't sync)
/// into SwiftData (which will, once CloudKit is on) — see
/// `docs/cloudkit-audit.md` for why leaving it in `UserDefaults` would have
/// let one device silently undo another's `Pause` records.
///
/// Every property carries a stored default, per `Migration.swift`'s "Adding
/// a field" step 1.
@Model
public final class AppSettings {
    public var id: UUID = UUID()
    public var gentleModeStartedAtDayKey: Int = 0
    public var gentleModeSafeguardDismissedForDayKey: Int = 0

    public init(
        id: UUID = UUID(),
        gentleModeStartedAtDayKey: Int = 0,
        gentleModeSafeguardDismissedForDayKey: Int = 0
    ) {
        self.id = id
        self.gentleModeStartedAtDayKey = gentleModeStartedAtDayKey
        self.gentleModeSafeguardDismissedForDayKey = gentleModeSafeguardDismissedForDayKey
    }
}

/// The merge CloudKit's lack of a single-row guarantee forces on every read:
/// two devices can each create an `AppSettings` row while offline, and both
/// are legitimate, so the result has to be computed from *all* rows rather
/// than picking one. Pure and order-independent — merging any subset of
/// rows, in any order, any number of times, gives the same answer — which is
/// what makes it safe to call from a live, reactive `@Query` in a view as
/// well as from `AppSettingsAccessor`'s own persistence path, without the
/// two ever disagreeing.
///
/// The two rules are asymmetric on purpose, not accidentally: a stale "off"
/// arriving late would close `Pause` records and turn a day that should read
/// paused into one that reads missed — invariant 3 forbids that outright. A
/// stale "on" arriving late only means the switch flips back on until every
/// device is back online, which is annoying, never destructive. So:
///
/// - `gentleModeStartedAtDayKey`: the smallest non-zero value across rows —
///   on wins over off, and the earliest start wins. Zero (off) only if every
///   row is zero.
/// - `gentleModeSafeguardDismissedForDayKey`: the merged started-at key, if
///   any row's dismissal matches it — dismissed on one device is dismissed
///   everywhere for that on-period. Otherwise zero.
public func mergedGentleModeState(
    _ rows: [AppSettings]
) -> (startedAtDayKey: Int, safeguardDismissedForDayKey: Int) {
    let nonZeroStarts = rows.map(\.gentleModeStartedAtDayKey).filter { $0 != 0 }
    let mergedStartedAt = nonZeroStarts.min() ?? 0
    let mergedDismissed = rows.contains { $0.gentleModeSafeguardDismissedForDayKey == mergedStartedAt }
        ? mergedStartedAt
        : 0
    return (mergedStartedAt, mergedDismissed)
}

/// The one write path for `AppSettings` (the same "one write path" principle
/// as `LogHabitIntent` — CLAUDE.md invariant 5 — applied to settings state).
/// No view fetches or mutates `AppSettings` directly; every write in the app
/// goes through one of these functions, and all three route through
/// `existingOrSeededRows(modelContext:)` first so the fetch/create/seed
/// logic lives in exactly one place.
///
/// Views may still read `AppSettings` reactively via an *unsorted*
/// `@Query<AppSettings>` (see `GentleModeView`'s comment on why unsorted
/// matters) and compute the displayed value with `mergedGentleModeState`
/// directly — that mirrors this same merge rule without duplicating it, and
/// is what keeps a toggle in one view reflected immediately in another, on
/// one device, with no sync involved at all.
public enum AppSettingsAccessor {
    /// Fetches all `AppSettings` rows and returns the single canonical one:
    /// none → create and seed one from the legacy `UserDefaults` keys; one →
    /// use it as-is (no write — this is the common case and must not incur
    /// a save on every call); more than one → merge them and write the
    /// result into the row with the lowest `id` (a deterministic,
    /// cross-device-stable choice — compared as `uuidString` rather than
    /// relying on `UUID`'s own ordering, which nothing else here depends
    /// on), leaving every other row's *own* value as it was rather than
    /// overwriting it too. A delete race between devices is worse than an
    /// inert extra row, and every read already merges regardless of how
    /// many rows exist — reaping the extras can be decided later.
    public static func current(modelContext: ModelContext) -> AppSettings {
        let rows = existingOrSeededRows(modelContext: modelContext)
        guard rows.count > 1 else { return rows[0] }

        let canonical = rows.min { $0.id.uuidString < $1.id.uuidString }!
        let merged = mergedGentleModeState(rows)
        canonical.gentleModeStartedAtDayKey = merged.startedAtDayKey
        canonical.gentleModeSafeguardDismissedForDayKey = merged.safeguardDismissedForDayKey
        try? modelContext.save()
        return canonical
    }

    /// Turns Gentle Mode on or off globally — pass `today`'s `dayKey` to
    /// turn on, `0` to turn off, matching what the switch itself means.
    ///
    /// Applies to *every* row this device can currently see, not just the
    /// canonical one — a row already sitting in the local store is current
    /// state this write is entitled to overwrite, not stale data to
    /// protect against. `mergedGentleModeState`'s "on wins" rule exists to
    /// protect a stale "off" arriving *later*, from a device that hasn't
    /// caught up yet — not to protect a row already visible right now. A
    /// write that only touched the canonical row would leave any other
    /// row's old value in place, and the very next merge would read that
    /// stale non-zero start as still-on, making the switch impossible to
    /// turn off once more than one row exists.
    public static func setGentleModeStartedAtDayKey(_ newValue: Int, modelContext: ModelContext) {
        for row in existingOrSeededRows(modelContext: modelContext) {
            row.gentleModeStartedAtDayKey = newValue
        }
        try? modelContext.save()
    }

    /// Dismisses the "Gentle Mode has been on for two weeks" line for the
    /// current on-period, applied to every row for the same reason as
    /// `setGentleModeStartedAtDayKey` above. A no-op, safely, if Gentle Mode
    /// is currently off.
    public static func dismissGentleModeSafeguard(modelContext: ModelContext) {
        let rows = existingOrSeededRows(modelContext: modelContext)
        let startedAtDayKey = mergedGentleModeState(rows).startedAtDayKey
        for row in rows {
            row.gentleModeSafeguardDismissedForDayKey = startedAtDayKey
        }
        try? modelContext.save()
    }

    /// Every `AppSettings` row currently in the store — creating and
    /// seeding exactly one, from the legacy `UserDefaults` keys, if the
    /// store has none yet. The shared base every function above builds on,
    /// so "fetch, and create-and-seed if empty" exists in exactly one
    /// place.
    ///
    /// KNOWN LIMITATION, not solved here: this only seeds when the store
    /// has zero rows. Once CloudKit is on, a row can arrive from another
    /// device before this device's first call here — the store then has
    /// one row (the remote one) and this branch never runs, silently
    /// dropping this device's own `UserDefaults` state. Mostly benign under
    /// "on wins" (an arriving "on" just confirms this device's own state),
    /// but not always: if this device was genuinely on and the arriving row
    /// says off, the on state is lost and pauses close. Left for the sync
    /// run.
    private static func existingOrSeededRows(modelContext: ModelContext) -> [AppSettings] {
        let rows = (try? modelContext.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard rows.isEmpty else { return rows }

        let settings = AppSettings()
        seedFromLegacyUserDefaults(into: settings)
        modelContext.insert(settings)
        try? modelContext.save()
        return [settings]
    }

    /// The one-time seed: an existing user may have Gentle Mode on right
    /// now, entirely in `UserDefaults`. If a freshly created `AppSettings`
    /// row started at its stored defaults instead, their switch would read
    /// off, `reconcileGentleMode` would close their open pauses, and the
    /// update would silently end their Gentle Mode and damage their
    /// history. `UserDefaults.integer(forKey:)` already returns `0` for a
    /// key that was never set, which is exactly this model's own default,
    /// so a brand-new user seeds to the same zeros they'd have gotten
    /// anyway. Called only when `existingOrSeededRows` finds the store
    /// empty, so it can never re-seed over a row that already exists —
    /// idempotent by construction, not by an extra check. The
    /// `UserDefaults` keys themselves are left in place afterwards, unread.
    private static func seedFromLegacyUserDefaults(into settings: AppSettings) {
        let defaults = UserDefaults.standard
        settings.gentleModeStartedAtDayKey = defaults.integer(forKey: GentleModeStorage.startedAtDayKeyDefaultsKey)
        settings.gentleModeSafeguardDismissedForDayKey = defaults.integer(
            forKey: GentleModeStorage.safeguardDismissedDefaultsKey
        )
    }
}
