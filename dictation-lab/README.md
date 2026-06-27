# Dictation Lab

Standalone test harness for the ClaudeCommand dictation pipeline. Isolates mic
capture + `SFSpeechRecognizer` from the launchd agent so the speech path can be
fixed before integrating back into `agent/`.

## Build + run

```sh
./dictation-lab/build.sh
open dictation-lab/DictationLab.app   # first launch prompts Mic + Speech — approve both
```

Foreground app (own bundle id `com.gal.dictationlab`, normal GUI session — NOT
launchd, NOT LSUIElement). Click **Start** (or Space), speak, watch:

- **Mic level (RMS)** bar + **buffer count** — proves audio buffers are flowing
- **Live / Final transcript** — proves the recognizer works
- **Log** pane — auth status, device, format, per-buffer RMS, task errors

`DictationLab.swift` is one self-contained file. Rebuilds in ~1.7s.

## Diagnosis so far (2026-06-27)

Symptom: ClaudeCommand dictation overlay appears but never transcribes ("no
audio detected").

Two independent root causes found:

### 1. launchd agent cannot capture mic audio (the agent's zero-buffer bug)

- TCC mic + speech grants are fine (`micAuth=3 speechAuth=3`, requestRecordPermission→true).
- In the **launchd-spawned LSUIElement agent**, `AVAudioEngine.inputNode` reports a
  bogus format (3ch from a 1ch mic) and the tap callback **never fires** → zero
  buffers → recognizer gets silence → "No speech detected".
- In this **foreground lab**, the SAME code captures fine: RMS > 0
  (`buf #20 rms=0.0220`), buffers climb. So it's the launchd launch context.
- Partial mitigation already in `agent/SpeechEngine.swift` (commit `6348e86`):
  bind the explicit HAL default input device on the input audio unit
  (`kAudioOutputUnitProperty_CurrentDevice`). Fixed the reported format (now 1ch)
  but **not** the zero-buffer problem in the agent.
- **Fix direction**: run capture in a foreground/GUI-session helper, not the
  launchd agent. The lab is that foreground process and works — fold its approach
  into a helper the agent spawns/activates.

### 2. macOS Dictation toggle gates the recognizer (`kLSRErrorDomain 201`)

- Even with audio flowing, the lab logged
  `task error: kLSRErrorDomain 201 — Siri and Dictation are disabled`.
- The en-US on-device model IS installed
  (`Offline Dictation Status → en-US → Installed = 1`), but the **master
  Dictation toggle** reads disabled at runtime (`"Dictation Enabled"` key absent;
  Siri also off — no `Assistant Enabled`).
- **Fix**: System Settings → Keyboard → **Dictation = ON** (model already present,
  so it arms instantly). Open pane:
  `open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"`
- Open question: with the toggle confirmed ON, does on-device
  (`requiresOnDeviceRecognition = true`) still 201? If so, try the server path and
  check whether Siri specifically must be enabled.

### Other context

- **Hex** (another dictation app, `/Applications/Hex.app`) runs concurrently. The
  terminal probe captured audio with Hex up, so Hex isn't a hard blocker — but rule
  it out if contention appears.
- Default input device: MacBook Pro Microphone (id 78, 1ch). Correct (not BlackHole).
- macOS 26.5.1.

## Next steps

1. Confirm Dictation toggle ON → lab produces a transcript end-to-end.
2. Decide capture architecture for the agent (foreground helper vs other).
3. Port the working approach into `agent/SpeechEngine.swift` + `DictationOverlay.swift`.
4. Re-enable a hotkey binding (currently no default key by design).
