# Usage

[← back to README](../README.md)

## Commands

```bash
osu-report                  # full dashboard, opens in your browser
osu-report --term           # draw it in the terminal instead
osu-report --brief          # Markdown digest to stdout
osu-report --brief --copy   # ...and straight onto your clipboard
osu-report --hours 3        # narrow the session window (default 6)
osu-report --fast           # skip replay downloads, use what's cached
osu-report --offline        # no network at all; render from local logs
osu-report --embed-font     # inline the webfont so the file travels
osu-report --sixel          # draw the report inline as sixel graphics (Linux)
```

`osu-stats` is the older text-only summary. It still works if you prefer it.

---

## Keyboard shortcuts

If you chose the Hyprland option during install:

| Key | Does |
|---|---|
| `Super+Shift+O` | build and open a report now |
| `Super+Shift+B` | copy the AI digest to your clipboard |

---

## The automatic report

A small watcher runs in the background:

1. polls every 20 seconds for an osu! process
2. waits 60 seconds after it exits, so the last score can submit
3. builds the report and opens it

It holds a lock, so it can't accidentally start twice.

### Changing how it appears

| Mode | Result |
|---|---|
| `browser` | HTML dashboard in a new browser window (default) |
| `term` | the ANSI dashboard in a terminal window |
| `sixel` | the HTML report drawn inline as sixel graphics (Linux only) |

**Linux** — edit `MODE` at the top of `~/.local/bin/osu-session-watch.sh`, or
set `OSU_REPORT_MODE`.

**Windows** — set `OSU_REPORT_MODE` as a user environment variable, or edit
`$Mode` at the top of `osu-session-watch.ps1`.

### Restart the watcher after changing it

Bash reads a script as it runs, so an edit doesn't reach the running process:

```bash
pkill -f osu-session-watch.sh; setsid ~/.local/bin/osu-session-watch.sh &>/dev/null &
```

On Windows, end the `powershell` process running the watcher in Task Manager,
then run the shortcut in your Startup folder again.

---

## The AI digest

```bash
osu-report --brief --copy
```

Puts a Markdown report on your clipboard. Paste it into Claude or ChatGPT and
ask where to focus.

It breaks your performance down by star rating, BPM, approach rate, overall
difficulty and circle size — plus the caveats needed to read those numbers
correctly, so the model doesn't draw the wrong conclusion.

---

## Where things live

### Linux

```
~/.local/bin/osu-report              the dashboard generator
~/.local/bin/osu-stats               text summary (also the shared API layer)
~/.local/bin/osu-session-watch.sh    the background watcher
~/.config/osu-tracker/config.json    your credentials (chmod 600)
~/.local/share/osu-tracker/
├── history.jsonl                    profile snapshots over time
├── score-ur.jsonl                   computed unstable rates, cached
├── beatmaps/                        beatmap cache used for UR
├── images/                          avatar and cover, cached
└── reports/                         generated reports
    ├── latest.html                  most recent dashboard
    └── latest-brief.md              most recent AI digest
```

### Windows

| | |
|---|---|
| Programs | `%LOCALAPPDATA%\Programs\osu-session-report\` |
| Config | `%APPDATA%\osu-tracker\` |
| Data & reports | `%LOCALAPPDATA%\osu-tracker\` |

Reports rotate automatically — the last 5 HTML files and 40 digests are kept.
Total disk use settles around 3 MB.

---

## Uninstall

```bash
./uninstall.sh                  # Linux
```
```powershell
.\uninstall.ps1                 # Windows
```

Removes the scripts and the autostart entry. Your data and config are left
alone unless you pass `--purge`.
