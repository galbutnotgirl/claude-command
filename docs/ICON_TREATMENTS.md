# Command Icon Treatments

Shareable visual reference for active menu-bar states. Use this when reviewing whether recording, capture, or background activity is visible enough on busy macOS menu bars.

## Current Recording Direction

The current active dictation state uses a compact solid-purple voice-lines icon: a menu-bar-sized purple rounded square with animated white bars. It is intentionally close to macOS microphone and camera status controls, but avoids the earlier wide badge, microphone glyph, live dot, and pulse ring.

Design goals:

- Visible on dark, light, and translucent menu-bar backgrounds.
- White-forward contrast, no black icon treatment.
- White carries only the moving voice bars; purple stays pure and solid.
- Motion should say "recording is active" without feeling noisy.

## Animated Previews

- [Bolder active-state treatments](icon-treatment-bold-animated.svg)
- [Original animated options](icon-treatment-options-animated.svg)
- [Static option sheet](icon-treatment-options.svg)

## Options

| Option | Best For | Tradeoff |
|---|---|---|
| System mic/camera beacon | Most obvious app-branded state, closest to macOS mic/camera controls. | Most visual weight in menu bar. |
| White mic-style badge | Most similar to macOS recording status. | Less unique to Command. |
| Camera-style capture | Screenshot/capture state. | Too specific for dictation. |
| Bold waveform pill | Highest live voice visibility. | Least subtle. |

## Implementation Notes

Runtime drawing lives in `agent/MenuBar.swift`. The installed app currently uses a compact active width, pure purple rounded-square backing, and four white voice bars driven by recorder audio level.

For where users enable dictation sounds and menu-bar visibility, see [SETTINGS_REFERENCE.md](SETTINGS_REFERENCE.md).
