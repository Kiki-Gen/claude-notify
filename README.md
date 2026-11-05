# claude-notify

A home-manager module that plays a sound the moment Claude Code needs you —
a permission dialog, an idle prompt, an agent waiting on input.

The whole point is *the moment*. Claude Code's `Notification` event is debounced
and arrives roughly 5–6 seconds after the permission dialog is already on
screen, which is long enough that the sound stops being useful. The
`PermissionRequest` hook fires *before* the dialog is drawn, so that is the path
this module uses for permissions, and `Notification` is left to cover the events
that have no earlier hook (idle prompt, agent needs input, elicitation dialogs).

## Install

Add the flake as an input:

```nix
{
  inputs.claude-notify.url = "github:Kiki-Gen/claude-notify";
}
```

Import the module wherever your home-manager config lives, and turn it on:

```nix
{
  imports = [ inputs.claude-notify.homeModules.default ];

  programs.claude-code.enable = true;
  programs.claude-code.notifySound.enable = true;
}
```

Without flakes, `imports = [ /path/to/claude-notify/module.nix ];` works the
same way.

Then `home-manager switch` (or rebuild, if home-manager runs as a NixOS
module) and restart Claude Code so it re-reads `settings.json`.

Requires `programs.claude-code` from home-manager (release-25.11 or newer) and,
by default, PipeWire's `pw-play`. See `player` below for other sound servers.

## Options

All under `programs.claude-code.notifySound`:

| Option | Default | What it does |
| --- | --- | --- |
| `enable` | `false` | Install the hook and wire it into `settings.json`. |
| `sound` | bundled `assets/claude_notify.wav` | The clip to play. |
| `player` | `${pkgs.pipewire}/bin/pw-play` | Command that plays it, with the sound appended as its only argument. Must be an absolute path — the hook can run without a `PATH`. |
| `onPermissionRequest` | `true` | Fire from the `PermissionRequest` hook (the fast path). |
| `notificationTypes` | `idle_prompt`, `agent_needs_input`, `elicitation_dialog`, `elicitation_url_dialog` | Which `Notification` types also play the sound. `[ ]` skips the `Notification` hook entirely. |
| `timeout` | `15` | Seconds Claude Code waits on the hook. |
| `hookName` | `notify-sound.sh` | File name under `~/.claude/hooks/`. |
| `logFile` | `~/.claude/notify-sound.log` | One line per event, or `null` for no logging. |

`permission_prompt` is deliberately absent from `notificationTypes`: with
`onPermissionRequest` on, including it plays the sound twice for one dialog.

### Not using PipeWire

```nix
programs.claude-code.notifySound.player = "${pkgs.pulseaudio}/bin/paplay";
# or "${pkgs.alsa-utils}/bin/aplay"
```

### Your own sound

```nix
programs.claude-code.notifySound.sound = ./my-clip.wav;
```

The bundled clip is trimmed to peak at −25 dB, which is audible without being
startling on a quiet desk. `assets/claude_notify_master.wav` is the untouched
−1.2 dB trim, kept so the level can be re-dialled on a fresh machine:

```sh
ffmpeg -i assets/claude_notify_master.wav -af volume=-23.8dB \
  -c:a pcm_s16le assets/claude_notify.wav
```

## How it works

The module generates `~/.claude/hooks/notify-sound.sh` and registers it for
both the `PermissionRequest` and `Notification` events, with no tool matcher, so
every tool is covered. The hook runs `async`, so playback never delays the
dialog it is announcing.

The script reads the JSON payload from stdin and matches it as plain text —
no `jq` — because hooks can run with an empty environment. For the same reason
it uses bash builtins for the timestamp and the UID, resolves the player by
Nix store path, and falls back to `/run/user/$UID` when `XDG_RUNTIME_DIR` is
unset (without it, `pw-play` cannot find the PipeWire socket).

## Nothing played?

`logFile` records every event the hook saw, whether or not it played:

```sh
tail -f ~/.claude/notify-sound.log
```

- `SKIP payload=…` — the hook ran but the event was not one it plays. Check
  `notificationTypes` against the `notification_type` in the payload.
- `PLAY rc=0 … err=none` — the hook played it; the problem is downstream
  (output device, volume, `pw-play` picking the wrong sink).
- `PLAY rc≠0` — `err=` has the player's own complaint.
- Nothing at all — Claude Code is not running the hook. Confirm
  `~/.claude/settings.json` is the store symlink this module wrote, and that
  Claude Code was restarted after the switch.

Taking over `programs.claude-code.settings` makes `~/.claude/settings.json` a
read-only store symlink, so anything you previously set from `/config` (model,
theme, …) has to move into Nix too.

Playing the hook by hand, the way Claude Code would:

```sh
printf '{"hook_event_name":"PermissionRequest"}' | bash ~/.claude/hooks/notify-sound.sh
```

## License

Not declared. The Nix code here is free to reuse; `assets/*.wav` ships as-is
and its provenance has not been checked, so swap in your own clip before
redistributing.
