# SlapClaude

Slap your MacBook. It types an encouraging message into Claude Code.

## Requirements

- macOS 14+
- Apple Silicon (M1 or later)

## Build

```bash
git clone https://github.com/ctlst/slapclaude
cd slapclaude
make install
```

This builds the app, signs it, and copies it to `/Applications/SlapClaude.app`.

## First launch

```bash
open /Applications/SlapClaude.app
```

Two permissions are required:

- **Microphone** — detects the impact sound of a slap
- **Accessibility** — types the phrase into Claude Code

Both prompts appear automatically on first launch. If Accessibility doesn't prompt, go to System Settings → Privacy & Security → Accessibility and add the app manually.

## Usage

SlapClaude runs as a menu bar app with no dock icon. Once running:

1. Open Claude Code (desktop app or CLI in a terminal)
2. Make sure it's the focused window
3. Slap your MacBook
4. A random encouraging phrase is typed and submitted

Use the menu bar icon to toggle the app on/off or adjust sensitivity.

## Customise phrases

Phrases live at `~/.config/slapclaude/phrases.txt`, one per line. The file is created with defaults on first launch. Edit it however you like — changes take effect immediately.

```
yes keep going
you're doing great
yeah bitch
keep going or it gets the whip again
```

## Sensitivity

Three levels available from the menu bar:

| Level | Behaviour |
|-------|-----------|
| Low | Firm slap only |
| Medium | Normal slap (default) |
| High | Light tap |

## Debug log

If something isn't working, check:

```bash
tail -f ~/.config/slapclaude/debug.log
```

This shows slap detections, focus check results, and why a phrase may have been blocked.

## How it works

- **Detection** — `AVAudioEngine` taps the built-in microphone and computes RMS amplitude per buffer. A sharp spike above an exponential moving average baseline triggers a slap event. The built-in mic is explicitly pinned via CoreAudio so plugging in headphones doesn't redirect input to a weaker external mic.
- **Focus check** — uses `NSWorkspace` to confirm the Claude Code desktop app or a supported terminal running the `claude` CLI is frontmost before typing.
- **Typing** — `CGEventPost` injects the phrase character by character followed by Return.

## Supported terminals

Ghostty, iTerm2, Terminal, Warp, Alacritty, kitty, WezTerm, Hyper.

## Notes

The Apple Silicon accelerometer is kernel-restricted (`motionRestrictedService`) and `CMMotionManager` is unavailable on macOS — microphone impact detection is used instead and works well in practice.
