# Command Permissions

Use this when macOS asks for access or Set Up shows a red permission.

## Short Version

| Permission | Required for | Needed when |
|---|---|---|
| Accessibility | Global shortcuts, copy, paste, submit, and focus restore. | Always recommended. |
| Screen Recording | Screenshot triggers. | Only if you use screenshots. |
| Microphone | Dictation and voice custom actions. | Only if you use dictation or voice triggers. |

Optional Set Up items are not broken installs. Clipboard History, Screen Recording, Microphone, dictation model, and source-only Quick Actions only need to be OK for workflows you use.

## Accessibility

Command needs Accessibility to respond to global hotkeys, copy selected text, paste rendered prompts, submit when auto-submit is enabled, and restore focus after Go-style actions.

Grant it in **System Settings -> Privacy & Security -> Accessibility**. Enable **Command**.

If hotkeys still do nothing after granting access:

1. Quit and reopen Command.
2. Open **Settings -> Set Up** and confirm Accessibility is green.
3. Confirm the shortcut row is enabled and bound in **Settings -> Shortcuts** or **Dictation Settings**.

## Screen Recording

Screen Recording is only needed for screenshot triggers. Selected text, popup, clipboard history, and dictation can work without it.

Grant it in **System Settings -> Privacy & Security -> Screen Recording**. Enable **Command**, then restart Command.

## Microphone

Microphone access is only needed for Dictate shortcuts and voice custom action triggers.

Grant it in **System Settings -> Privacy & Security -> Microphone**. Enable **Command**. Then open **Settings -> Dictation Settings** and confirm the model is ready.

Dictation runs on-device. See [PRIVACY.md](PRIVACY.md) for local file locations and background CLI caveats.

## Clipboard History

Clipboard History runs inside Command. It is optional and can be disabled.

If Clipboard History is enabled but empty:

1. Confirm Clipboard History is running in **Settings -> Set Up**.
2. Copy normal text from a non-password app.
3. Open **Settings -> Clipboard History** and confirm retention is not set too low.

## Quick Actions

Quick Actions are optional legacy right-click Services for source installs. Global shortcuts do not need them.

Binary installs from GitHub Releases do not need `./install-quick-action.sh`.

## Reset Permissions

If macOS permission state looks stuck, reset one permission from Terminal, then grant it again in System Settings:

```bash
tccutil reset Accessibility com.claudecommand
tccutil reset ScreenCapture com.claudecommand
tccutil reset Microphone com.claudecommand
```

The identifier remains `com.claudecommand` for compatibility with existing alpha installs, even though the visible app name is Command.

Then reopen Command and check **Settings -> Set Up**.

## Diagnostics

Use **Settings -> About -> Copy Diagnostic Info** before filing a bug. It includes app path, bundle ID, version, minimum macOS, update channel/check status, shortcut binding summary, Set Up status, log tails, recent command summaries, Clipboard History errors, and recent dictation previews. Review copied diagnostics before sharing if logs or recent text may include sensitive content.

For tab-by-tab Settings help, see [SETTINGS_REFERENCE.md](SETTINGS_REFERENCE.md). For step-by-step symptoms, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
