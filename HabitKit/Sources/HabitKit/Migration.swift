import Foundation
import SwiftData

/// Version 1 of the persisted schema — `Habit`, `LogEvent` and `Pause` as
/// they stood at this file's first commit. This is the first schema ever
/// declared formally as a `VersionedSchema`; every store that predates this
/// file had no version at all, just whatever the three `@Model` classes
/// happened to look like at build time. SwiftData compares a store's actual
/// on-disk shape against `HabitSchemaV1.models` regardless of how that store
/// came to exist, so V1 is also what an old, unversioned store migrates
/// forward into — the fix for the crash this file was written to close out
/// was making `nudgeHour` lightweight-migratable (a real default on the
/// stored property, not just in `init`); V1 exists so the next field never
/// gets to repeat that mistake silently.
public enum HabitSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Habit.self, LogEvent.self, Pause.self]
    }
}

/// Version 2 — adds `AppSettings`, the cross-device home for Gentle Mode's
/// global switch state (previously `UserDefaults`, which doesn't sync; see
/// `docs/cloudkit-audit.md`). `Habit`, `LogEvent` and `Pause` are unchanged
/// from V1; this version exists purely to add the new model type to the
/// schema.
public enum HabitSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Habit.self, LogEvent.self, Pause.self, AppSettings.self]
    }
}

/// The migration plan every `ModelContainer` in the app must be built with
/// (see `HabitApp.swift`) — never a bare `Schema`. SwiftData handles the
/// transition from an old, unversioned store into V1 using the same
/// lightweight machinery a declared stage would use, which is why there's no
/// stage before V1 despite V1 itself needing none to be *reached*.
///
/// ## Adding a field, step by step
///
/// 1. Add the property to the model in HabitKit with a real default on the
///    stored property — `var thing: Int = 0`, not just `init(thing: Int =
///    0)` — or make it `Optional`. An `init`-only default is a Swift-level
///    convenience; SwiftData never sees it, and it does nothing to backfill
///    rows that already exist on disk. This exact gap is what broke
///    `nudgeHour` and crashed the app on launch.
/// 2. Declare a new `HabitSchemaV{N}` here with an incremented
///    `versionIdentifier` and the updated `models` list.
/// 3. Add `.lightweight(fromVersion: HabitSchemaV{N-1}.self, toVersion:
///    HabitSchemaV{N}.self)` to `stages`, and add `HabitSchemaV{N}` to
///    `schemas`, below.
/// 4. Add a test to `MigrationTests.swift` proving a store written under the
///    old version still opens under the new plan with the new field at its
///    default. There is no blanket scan to fall back on — one was tried and
///    removed, because SwiftData can't tell "always been here" from "just
///    added", so it flagged every original field (see the comment on
///    `nudgeHourHasASwiftDataVisibleDefault`). The per-change test is the
///    whole safety net; copy that test's shape to assert the new attribute's
///    `defaultValue != nil`.
/// 5. Never rename or retype an existing field (CLAUDE.md). If one must be
///    replaced, add the new one and leave the old one in place, ignored.
/// 6. Before the next release ships, deploy the updated schema to the
///    CloudKit Production environment from the CloudKit Console — Xcode's
///    Development environment creates schema just-in-time, Production does
///    not, and skipping this ships an app that syncs in Xcode and nowhere
///    else.
public enum HabitMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [HabitSchemaV1.self, HabitSchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: HabitSchemaV1.self, toVersion: HabitSchemaV2.self)]
    }
}
