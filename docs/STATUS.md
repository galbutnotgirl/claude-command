# ClaudeCommand — Status Log

Running log of what's been built, current state, and what's next. Written so a fresh
agent (human or AI — Codex, Claude, whoever) can pick up this project cold. Update this
file at the end of any substantial work session; don't let it go stale.

Repo: `galbutnotgirl/claude-command`. Current version: **1.2.0-alpha.6**
(`git checkout checkpoint-before-trigger-refactor` rolls back to just before the biggest
recent change if something in there needs undoing).

## What this app is

A native macOS menu-bar agent (`agent/*.swift`, SwiftUI/AppKit, not Electron) that:
- Captures a text selection, screenshot, typed popup, or dictated voice input via global
  hotkey and either pastes a rendered prompt into the Claude desktop app, or runs it as a
  background `claude -p` handoff (no window) via a vendored Electron-free Node core
  (`vendor/claude-command-capture/`).
- Also does clipboard history (`clipwatch.py` daemon) and on-device dictation (Parakeet
  TDT via FluidAudio).

See `docs/BACKGROUND_TRIGGER_INTEGRATION.md` for the background-handoff architecture in
detail — that doc is current as of alpha.6 and is the one to read before touching that code.

## Session timeline (chronological, oldest first)

1. **release.sh hardening** (`cfb58f7`) — pre-flight guards (clean tree, on main, tag not
   already published) + `--publish` flag to automate tag/push/`gh release create`.
2. **In-app bug reporting** (`f34e235`) — About tab "Report a Bug" opens a pre-filled
   GitHub issue (version/macOS/repro template).
3. **Context Rules path-prefix matching** (`a54041a`) — Google Docs/Sheets/Slides all live
   on `docs.google.com`; added `pathPrefix` so a rule can require e.g. `/document/` to
   distinguish them (previously any of the three matched the same generic rule).
4. **Handoff lifecycle features** (`1894a2e`, `8655a87`, `b85442a`) — Retry for failed
   submissions, retention/auto-cleanup (default 7 days, mirrors clipboard history), and
   stalled-run recovery ("mark as failed" for a run stuck at `running` because the CLI
   process died without the record ever getting rewritten).
5. **Custom Handoffs born** (`05df652`) — the old fixed "Skill Handoff"/"Screenshot
   Handoff" actions (one shared global skill+template) became user-configurable: any
   Custom Action gained an `isHandoff` toggle + `skill` field, each with its own prompt.
   A few false starts along the way (`1b4bd69`/`a3b1529` — moved Custom Actions into the
   Handoffs tab, then reverted after the user clarified they wanted Handoffs *grouped
   under* Shortcuts, not living in their own tab) and a dark-mode contrast fix (`a338f39`
   — `.bordered` button text was unreadable purple-on-dark-gray; made the accent color
   appearance-aware).
6. **"Handoff History" naming + retention tuning** (`09bbd51`, `46ec09b`) — renamed the
   Handoffs tab to match "Clipboard History" naming, defaulted retention to match
   clipboard's 7 days, and folded the last of the old Custom Handoffs section directly
   into Custom Actions (one list, not two).
7. **Daily auto-update check** (`240d2ca`) — background `Updater.shared.check()` once a
   day (or on launch if overdue), system notification if a newer build's available on
   your channel. Doesn't auto-install.
8. **Real test coverage, from zero** (`5a58a4b`) — the Swift app had no automated tests at
   all outside the vendored Node core. Split pure logic (key formatting, the action/hotkey
   catalog, version/channel comparison, template rendering, handoff staleness math) into a
   new `ClaudeCommandCore` SPM library target so it's actually unit-testable — the
   executable can't be, since its top-level code has real side effects (`NSApplication`,
   socket bind, global hotkeys). Added 58 Swift tests + 17 shell tests (extracted
   `send-to-claude.sh`'s inline Python/expand_template into standalone testable files:
   `match-enrich-rule.py`, `send-to-claude-lib.sh`). **Found and fixed 2 real bugs in the
   process**: `Updater.swift`'s `isNewer` used `latest != cur` instead of a real
   newer-than check (a locally-built dev version ahead of the latest tag would be offered
   as a "downgrade"); the Templates preview picker only used a rule's friendly
   `displayName` when `pathPrefix` was set, so most rules showed a raw host instead
   ("mail.google.com" not "Gmail").
9. **CI** (`511a52a`, `c264235`) — GitHub Actions runs all three suites (Swift/Node/shell)
   on every push+PR. First run failed: macos-14's default Xcode ships Swift 5.10, but the
   FluidAudio dependency needs Swift 6 tools even though the tests themselves don't touch
   it (package resolution still walks the whole graph). Fixed with
   `maxim-lobanov/setup-xcode@latest-stable`.
10. **Structured-output result surfacing** (`8016648`) — if a background `claude -p` run's
    last non-empty stdout line matches `KEY=value` (the same contract a hand-rolled
    Shortcuts-style intake script would use), it's now picked up automatically as the
    submission's `result` — shown in the finish notification, the Handoff History row, and
    the menu-bar submenu title. No config needed, it's a convention. `runner.js`'s
    `extractResult()`.
11. **Real-world validation: "Post To Do"** — the user had an existing Apple Shortcut
    (`~/.claude/hooks/intake.sh`) that took freeform text → `claude -p` with a structured
    prompt → POSTed a task to a personal project-tracker API. Rebuilt that exact workflow
    as a Custom Handoff inside ClaudeCommand. Along the way: diagnosed that `claude` CLI
    was logged out (fixed via `claude /login` — separate from any of this app's code);
    discovered the intake script's hardcoded sync token was stale; discovered the *right*
    fix was registering the user's already-built `project-tracker` MCP server
    (`~/Claude-Code-Projects/claude-project-tracker/mcp-server`) with the local
    `claude` CLI (`claude mcp add project-tracker --scope user ...`) instead of curling the
    API directly with a token at all. This is now a real, working, tested Custom Handoff
    (F9, `isHandoff: true`, calls `mcp__project-tracker__create_task`).
12. **Custom Actions trigger-kind unification** (`6926cd3`) — `CustomAction.isShot: Bool`
    became `kind: ActionKind` (`text | screenshot | popup | voice`). Added two new trigger
    types: **popup** (`CustomActionTextEntryPanel` — a floating type-and-⌘⏎ box, replacing
    the old fixed "Text Handoff" action's own dedicated panel) and **voice** (routes
    through the same press/hold/double-tap state machine the built-in Dictate actions use;
    `DictMode.customAction(id:)`, `DictationOverlay.dispatchCustomAction`). The old fixed
    "Text Handoff" action, its settings-window fields, and the menu bar's "Text Entry…"
    item are gone — folded into `kind: .popup`.
13. **Shared body + multiple triggers** (`65bbbaf`) — one more layer of unification, driven
    directly by user feedback: "I'd want the same prompt to have multiple versions —
    popup, voice, screenshot — configured once." `CustomAction.kind` (a single trigger)
    became `triggers: [ActionTrigger]` — one prompt/skill/delivery config, any number of
    ways to fire it. Each trigger can optionally override auto-submit/session-mode/
    include-source (nil = inherit the action's default). Dispatch string format became
    `customtrigger:<actionID>:<triggerID>` (`triggerActionID`/`parseTriggerActionID`) —
    replaced the old 4-way `custom:`/`customshot:`/`customhandoff:`/`customshothandoff:`
    prefix explosion with one prefix, dispatch reads `trigger.kind` off the loaded record.
    `checkpoint-before-trigger-refactor` tag marks the commit right before this — a clean
    rollback point since it touched the hotkey dispatch code path everything else depends on.

## Current state (alpha.6)

- **Test suites**: 63 Swift (`cd agent && swift test`), 48 Node
  (`cd vendor/claude-command-capture && node --test`), 17 shell (`./test/test-shell.sh`).
  All green. CI runs all three on push/PR (`.github/workflows/test.yml`).
- **Custom Actions** (Settings ▸ Shortcuts ▸ Custom Actions): each has a name, prompt,
  optional skill + `isHandoff`, and a list of triggers (kind + hotkey + optional overrides).
  Two real ones exist on this dev machine right now: "Update Doc" (⌘F6, paste-mode) and
  "Post To Do" (F9, handoff-mode, calls the project-tracker MCP).
- **Built-ins untouched**: add/comment/go/shotadd/shotcomment/shotgo/cliphistory/dictate/
  dictateadd are still the old flat `HotkeyBinding` model (one action = one keycode), not
  yet folded into the trigger system. See "Next up" below.
- **Voice trigger**: built and wired (compiles, dispatches, unit-tested for the dual-ID
  scheme), but **never actually confirmed working with real speech** — only verified via
  code review + a synthetic key-press test that showed the *popup* trigger opening a real
  window. The equivalent live check for voice (hold key, speak, confirm transcript
  dispatches) hasn't happened yet.
- **Known gaps, not yet built**:
  - No UI to configure the `TASK_ID=`/`ERROR=` result-parsing *action* — the app surfaces
    the parsed line (notification/row/menu), but doesn't POST anywhere or run a follow-up
    step based on it. Flagged as an intentional scope boundary in
    `docs/BACKGROUND_TRIGGER_INTEGRATION.md`.
  - `capture-handoff.sh` + `send-to-claude.sh`'s `handoff)` case are now dead from
    ClaudeCommand's own UI (everything goes through `submit-cli.js --retry-prompt`
    instead) — kept only because they're still the vendor core's documented non-retry
    contract for other callers. Candidate for removal if nothing else needs that path.
- **Unresolved, blocked on the user**: a "gray circles under Clipboard History" visual bug
  mentioned early in this session — never located in the code across two passes, needs a
  screenshot or repro steps to move on.

## Next up (roughly in the order they came up)

1. **Verify voice trigger with real audio.** Bind a test Custom Action to voice, hold the
   key, actually speak, confirm the transcript dispatches (paste or handoff) correctly.
   This is the one piece of the last two commits that's unverified beyond code review.
2. **Decide on folding add/comment/go/shot\* into the same trigger system.** Explicitly
   deferred (not just skipped) — these are the most-used hotkeys in the app, and folding
   them in means also merging in the Templates tab's separate go/comment/add prompt editor
   (`CommandTemplates.swift`/`TemplatesModel`), which is a second system beyond just the
   hotkey-binding shape. Real win (shotadd/shotcomment/shotgo are literally the screenshot
   trigger of add/comment/go and would collapse from 6 catalog entries to 3), real risk
   (touches core navigation everyone uses constantly). Get explicit sign-off before
   starting, and scope it as its own dedicated pass.
3. **Gray-circles Clipboard History bug** — still needs a screenshot/repro from the user.
4. **Structured-output *action* layer** (optional, explicitly flagged as a gap, not
   started) — today the app shows a parsed `KEY=value` result but doesn't act on it. If
   ever wanted: probably a per-action or per-trigger "on result, do X" config, needs its
   own design pass rather than a bolt-on.
5. Minor cleanup candidate: `capture-handoff.sh`/`send-to-claude.sh`'s `handoff)` case —
   confirm nothing external depends on the non-retry path, then consider removing.

## Working conventions established this session

- **Always run the full verification loop** before calling something done: `swift build`
  → `swift test` → `./build-agent.sh` → `./install-agent.sh` → confirm a fresh PID
  (`pgrep -x ClaudeCommand` before/after) → for anything touching the vendor core, a live
  `node vendor/claude-command-capture/bin/submit-cli.js --retry-prompt` smoke test.
- **`gh auth switch --user galbutnotgirl` before every push** — the active `gh` account
  silently reverts to a different one (`gal-cstk`, no push access) between sessions.
- **Bump `VERSION` and run `./release.sh --publish`** after any user-facing change worth
  shipping — this session cut alpha.1 through alpha.6 incrementally rather than batching.
- **Real functional tests over synthetic ones where possible.** A synthetic
  `osascript key code` press reliably triggers Carbon hotkeys and is good enough to prove
  a *visible* effect (a window opening for the popup trigger); for anything with no visible
  UI (a background handoff), the CLI-level test (`submit-cli.js --retry-prompt` with the
  actual rendered prompt) is the trustworthy one — clean up test tasks created against the
  real project-tracker afterward (`mcp__project-tracker__update_task` → `status: archive`).
- **This file** — update it at the end of a session covering meaningful work, don't let it
  silently go stale.
