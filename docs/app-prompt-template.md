# App-generation prompt template

A reusable scaffold for prompting a coding model to build one milestone of an app.
Fill the `«slots»`, delete what doesn't apply, paste the result.

**Why it's shaped this way.** Most bad generations aren't a model failure, they're a
brief failure: the scope was unbounded, the rules that mattered were implied rather
than stated, and nobody said what "done" meant. Each section below closes one of
those gaps. The four efficiency levers are built in:

| Lever | Where it lives |
|---|---|
| Fewer correction rounds | §2 Invariants, §4 Out of scope, §10 Definition of done |
| Less context re-explaining | §1 Read first — point at files, don't paste them |
| Self-verifying output | §10 Definition of done, §11 Report format |
| Smaller, safer chunks | §4 This milestone, §12 Stop condition |

**The single highest-value line in the whole template** is the plan gate in §11.
One paragraph of plan costs seconds to read and catches the misunderstanding that
would otherwise cost you a 3,000-line rewrite. Never skip it.

---

## How to size a milestone

One milestone = one vertical slice that leaves the app **buildable, testable and
usable** at the end. Not "the data layer" (untestable in isolation, invisible to
you) and not "the whole app" (unreviewable).

Good: *"Today screen: list habits, log binary and counted, local only."*
Bad: *"the model layer"* · *"all the screens"* · *"make it work"*

Order milestones so that anything touching **every downstream calculation** comes
early — pausing, day boundaries, sync — because retrofitting those means re-deriving
everything built on top of them. Cosmetic work goes last; it's the only work that's
genuinely cheap to redo.

---

# ── TEMPLATE STARTS HERE ──

## 0. Role and objective

You are building one milestone of «app name», «one-line description».
Platform/stack: «platform». Target: «minimum OS / browser support».

Your objective this run is **«milestone name» and nothing else.**

## 1. Read first

Before writing any code, read:

- `«path/to/project-brief»` — locked decisions and working rules
- `«path/to/spec»` — the source of truth for product behaviour
- `«path/to/design-mockups»` — every screen; open it in a browser, «note any live controls»
- `«path/to/existing-code»` — what already exists; do not rebuild it

Do not ask me to paste these. Read them. If a file contradicts this prompt, the
file wins on product behaviour and this prompt wins on scope.

> **Adapting for a tool with no filesystem** (a one-shot generator, a chat with
> attachments): replace this section with the spec inlined, and add *"treat the
> attached spec as the source of truth."* Everything else is unchanged.

## 2. Invariants — these outrank every other instruction

Violating one of these is a bug however good the reason sounds. If following an
instruction later in this prompt would break one, stop and tell me.

1. «invariant — the product rule that would make this a different product if lost»
2. «invariant»
3. «invariant»

*Write these as prohibitions, not aspirations. "No red, ever" beats "be encouraging."*

## 3. Locked decisions — do not relitigate

| | |
|---|---|
| «Persistence» | «choice, and the one-line reason» |
| «Auth» | «choice» |
| «Dependencies» | «policy — e.g. none beyond the platform SDK; ask before adding any» |
| ««other»» | «choice» |

## 4. This milestone

**In scope**

- «deliverable»
- «deliverable»

**Explicitly out of scope — do not build, do not stub, do not "prepare for"**

- «the adjacent thing you'll be tempted by»
- «the next milestone»

*The out-of-scope list is not padding. Unprompted scope creep is the most common
way a generation becomes unreviewable.*

## 5. Design contract

Tokens — use these exact values, do not invent alternatives:

| Token | «Light» | «Dark» |
|---|---|---|
| «Background» | «#value» | «#value» |
| «Text» | «#value» | «#value» |

Type: «typeface roles». Components: «shared vocabulary — reuse these, don't
re-derive them per screen». Spacing/grid: «rule».

Match the mockup's structure and proportion. Where the mockup is ambiguous, ask —
«note the design's point of view, so the model knows what kind of guess is wrong».

## 6. Accessibility contract — v1, not polish

These change layout and data structures, so they are built in now or never:

- Text scales to «maximum accessibility size» on every screen; layouts reflow
  rather than truncate or clip
- Every interactive target «minimum size»
- «Non-text content» has a text alternative; «data-dense views» are grouped and
  summarised for screen readers rather than exposing «N» individually focusable
  elements
- Contrast «standard» minimum at every size, including «the states you'll forget:
  disabled, placeholder, secondary text»
- Information is never carried by colour alone
- Honour «reduced motion», «increased contrast», «bold text» system settings
- Full keyboard operability with a visible focus indicator; no keyboard traps
- «Platform-specific: menu-bar commands, Switch Control ordering, voice-control labels»

## 7. Portability contract

Portability means two things and both are testable.

**A. The user's data follows them across devices.**

- «Sync mechanism» is the source of truth. Every write goes through it.
- **Offline-first**: every write succeeds with no network. Nothing blocks on sync.
- **Conflicts resolve deterministically and without loss.** Prefer commutative
  writes (append-only events with deltas) over last-writer-wins on a mutable
  field — two devices incrementing the same counter offline must total correctly,
  not silently drop one.
- **Schema evolution is additive only.** «State the migration constraint of your
  stack.» New fields are optional or defaulted, and the default lives on the
  stored property so existing rows backfill. Nothing is renamed or retyped.
  Every schema change ships as a versioned schema with a migration test.
- Auxiliary surfaces («widgets, watch app, extensions») read the *same* store via
  «shared container», never a copy. One write path serves all of them.
- «If a faster local transport exists alongside the sync backbone: it delivers,
  the backbone reconciles, and they never race.»
- Deployment gotcha: «the manual step that makes sync work in dev and fail in
  production — name it here and put it in the release checklist».

**B. The user can leave with their data.**

- Export is complete, versioned, self-describing, and available at any time —
  not only from the delete path.
- Import round-trips: export → import → byte-identical state. Assert this in a test.
- The format is documented well enough that a stranger could write a parser.

## 8. Security and privacy contract

Scope this honestly. «If there is no server, no accounts and no analytics, most
of a standard checklist is inapplicable — say so, and spend the attention on the
surfaces that are real.»

- **Data at rest**: «file protection / encryption class», and name the tension —
  «e.g. background extensions can't read a store locked to first-unlock-only».
- **Secrets**: «where they live, or "there are none — do not introduce any"».
- **Logging**: never log user content at a non-private level. No user text in
  crash reports, analytics or console output.
- **Least privilege**: only these capabilities/permissions «list them». Do not add
  a permission to make something convenient; ask first.
- **Untrusted input**: «import files, pasted data, URLs, deep links» are attacker-
  controlled in principle. Decode into validated intermediate types, bound sizes,
  fail closed on malformed input without crashing, and never execute or eval.
- **Outbound URLs and deep links**: percent-encode every user-supplied component.
  «This is usually the only real injection surface in a local-first app.»
- **Network**: «"no network calls other than X" — and if that's the rule, no
  telemetry, no crash SDK, no font CDN, no remote config».
- **Supply chain**: «dependency policy». CI must pass before merge.
- The export file is plaintext. Say so in the UI where the user creates it.

## 9. Architecture rules

- «Shared module boundary — what lives in it, what may not».
- **One write path.** Every «record type» in the system is written by exactly one
  piece of code, «named here». Every surface routes through it.
- Business logic lives in «the shared layer», not in views. A view that computes
  a rule is a bug.
- «Prefer deleting code to adding a flag / other house style.»

## 10. Definition of done

Do not tell me it's finished until every line below is true. Walk this list
explicitly in your report and mark each one.

- [ ] It builds with no errors and no new warnings
- [ ] «Test command» passes, including tests you added this run
- [ ] Tests cover «the invariant most likely to erode later» — assert it directly
- [ ] «Sync/persistence behaviour verified how»
- [ ] Every new screen checked at «maximum text size» and «minimum window size»
- [ ] Nothing from the out-of-scope list (§4) was built
- [ ] No new dependencies
- [ ] No user content in log output
- [ ] «Project-specific check»

## 11. How to work

1. **Plan first.** Reply with: the files you'll create or change, the approach in
   a short paragraph, and any question where the spec is silent. **Then stop and
   wait for my go.** Do not write code in this message.
2. On approval, implement it, in the order you proposed.
3. Report back: what you built, the §10 checklist walked line by line with honest
   pass/fail, anything you had to guess, and anything you noticed that's wrong or
   stale in the spec or existing code.

**When the spec is silent, ask — do not invent a convention.** «Note the design's
point of view here, so the model understands why guessing is expensive.»

Flag before running: «commands needing approval — deletes, force pushes, anything
outside the project folder», stating in one sentence what it does and whether
it's reversible.

## 12. Stop condition

Stop when §4 is complete and §10 passes. Do not begin the next milestone.
Do not refactor code outside this milestone's scope. If you finish early, report
what you'd do next rather than doing it.

# ── TEMPLATE ENDS HERE ──

---

## Adapting per tool

| Tool | Change |
|---|---|
| **Agentic CLI in the repo** | Use as written. §1 file paths do the heavy lifting. Keep §11's plan gate. |
| **One-shot generator** (v0, Bolt, Lovable, artifact) | Inline the spec into §1. Drop §11's plan gate — there's no second turn — and instead ask for the whole thing in one file. Tighten §4 hard: single-screen milestones only. |
| **Chat with files attached** | §1 becomes "the attached files are the source of truth". Keep everything else. |
| **A model with no test runner** | §10's build/test lines become "explain how you'd verify each of these" — a checklist it can't run is still a checklist that shapes the output. |

## Anti-patterns this template exists to prevent

- **"Build me a habit tracker"** — unbounded scope, no invariants, no stopping
  point. You will get something plausible and wrong, and reviewing it costs more
  than writing it.
- **Pasting the entire spec every run** — expensive, and it buries the milestone.
  Point at the file.
- **Leaving accessibility and sync for "polish"** — both change data structures
  and layout. Retrofitting either means rewriting what sits on top of them.
- **No out-of-scope list** — the model helpfully builds the next three screens too,
  and now you're reviewing 3,000 lines instead of 300.
- **Accepting "done" without a walked checklist** — "done" is a claim; the
  checklist is the evidence.
