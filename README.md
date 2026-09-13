# osu! session report

When you close osu!, this builds a dashboard of how the session went and opens
it — top plays, progress curves, tapping consistency, and a breakdown of where
your accuracy actually falls apart.

Everything runs locally. The only thing that leaves your machine is a request
to osu!'s own API for your own scores.

![The dashboard](docs/dashboard.jpg)

---

## Quick start

```bash
osu-report            # dashboard in your browser
osu-report --term     # the same thing in your terminal
osu-report --brief    # a summary to paste into an AI
```

Close osu! and the dashboard opens on its own. No flags needed.

[Jump to install →](#install)

---

## Three ways to see it

### 1. In your browser

The page takes its colour from your profile banner.

- **Headline row** — what moved while you played
- **Every play links to its map**
- **UR** shown wherever a replay exists

![Top plays](docs/top-plays.jpg)

- **Rings** — the session's judgements and grades
- **Scatter** — all 100 top plays, when you set them against what they were worth
- **Hover** — a crosshair locks to the nearest point and lifts its grade series

![Composition and top plays over time](docs/composition.jpg)

- **Progress curves** — pp, rank, accuracy
- **UR over time** — coloured by star rating
- **UR per difficulty band** — where your tapping falls apart

![Progress and consistency](docs/charts.jpg)

---

### 2. In your terminal

```bash
osu-report --term
```

Instant. No browser. Works over SSH.

![Terminal report](docs/terminal.jpg)

Charts are drawn in braille — 2×4 dots per character cell. That's eight times
the resolution of block sparklines, enough to read the *shape* of a climb.

![Terminal charts](docs/terminal-charts.jpg)

---

### 3. As a summary for an AI

```bash
osu-report --brief --copy
```

Puts a Markdown report on your clipboard. Paste it into Claude or ChatGPT and
ask where to focus.

It breaks your performance down by:

- star rating
- BPM
- approach rate
- overall difficulty
- circle size

...plus the caveats needed to read those numbers correctly, so the AI doesn't
draw the wrong conclusion.

---

## Install

**You need:** Python 3.9+, and osu! (lazer or stable).

The installer asks for your osu! API keys and tells you exactly where to click
to get them. Safe to run again any time.

### Linux

```bash
git clone https://github.com/Ichika11/osu-session-report.git
cd osu-session-report
./install.sh
```

### Windows

**Step 1 — install [Python](https://www.python.org/downloads/).**

> ⚠️ **Tick "Add python.exe to PATH"** in the Python installer.
> It's a small checkbox on the first screen. Nothing works without it.

**Step 2 — run the installer** in PowerShell:

```powershell
git clone https://github.com/Ichika11/osu-session-report.git
cd osu-session-report
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**Step 3 — open a new terminal.**

The installer changes your PATH. Terminals that were already open keep the old
one, so `osu-report` won't be found in them.

No admin rights needed. `-ExecutionPolicy Bypass` applies to that one command
only — it doesn't change any system setting.

> **Windows support is newer and less exercised than Linux.** The Python side is
> platform-aware and the installer follows Windows conventions, but if something
> misbehaves please open an issue — include the output of `osu-report --brief`.

| | Linux | Windows |
|---|---|---|
| Programs | `~/.local/bin/` | `%LOCALAPPDATA%\Programs\osu-session-report\` |
| Config | `~/.config/osu-tracker/` | `%APPDATA%\osu-tracker\` |
| Data & reports | `~/.local/share/osu-tracker/` | `%LOCALAPPDATA%\osu-tracker\` |
| Autostart | Hyprland or systemd | Startup folder |
| Desktop notification | yes | no — the report opening is the signal |
| `--sixel` | yes, with chafa | not supported |

### Getting your credentials

The installer explains this, but for reference — both live at
<https://osu.ppy.sh/home/account/edit>:

| What | Where | Used for |
|---|---|---|
| **OAuth app** (Client ID + Secret) | the "OAuth" section → New OAuth Application | your profile and scores |
| **Legacy API key** | the "Legacy API" section | downloading beatmaps to compute UR |

> **The OAuth callback URL must be exactly `http://localhost:8727/`** — including
> the trailing slash. If it doesn't match, replay downloads fail with an auth
> error. Port 727 (osu!'s usual number) does *not* work: ports below 1024 need
> root, and this runs as you.

The legacy key is optional. Without it you still get everything except unstable
rate.

---

## Using it

```bash
osu-report                  # full dashboard, opens in your browser
osu-report --term           # draw it in the terminal instead
osu-report --brief          # Markdown digest to stdout
osu-report --brief --copy   # ...and straight onto your clipboard
osu-report --hours 3        # narrow the session window (default 6)
osu-report --fast           # skip replay downloads, use what's cached
osu-report --offline        # no network at all; render from local logs
```

`osu-stats` is the older text-only summary and still works if you prefer it.

### Keyboard shortcuts

If you chose the Hyprland option during install:

| Key | Does |
|---|---|
| `Super+Shift+O` | build and open a report now |
| `Super+Shift+B` | copy the AI digest to your clipboard |

---

## How the automatic report works

A small watcher runs in the background:

1. polls every 20 seconds for an osu! process
2. waits 60 seconds after it exits, so the last score can submit
3. builds the report and opens it

It holds a lock, so it can't accidentally start twice.

Change how the report appears by editing `MODE` at the top of
`~/.local/bin/osu-session-watch.sh`, or by setting `OSU_REPORT_MODE`:

| Mode | Result |
|---|---|
| `browser` | HTML dashboard in a new browser window (default) |
| `term` | the ANSI dashboard in a terminal window |
| `sixel` | the HTML report drawn inline as sixel graphics |

On Windows, set `OSU_REPORT_MODE` as a user environment variable, or edit
`$Mode` at the top of `osu-session-watch.ps1`. `sixel` is Linux-only.

**Restart the watcher after changing it.** Bash reads a script as it runs, so an
edit doesn't reach the running process:

```bash
pkill -f osu-session-watch.sh; setsid ~/.local/bin/osu-session-watch.sh &>/dev/null &
```

On Windows, end the `powershell` process running the watcher in Task Manager
and run the shortcut in your Startup folder again.

---

## Where things live

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

Reports rotate automatically — the last 5 HTML files and 40 digests are kept.
Total disk use settles around 3 MB.

---

## Reading unstable rate

UR is the standard deviation of your hit timing error, ×10. Lower is steadier.

**It will not match the number lazer shows you.**

- UR here uses the *stable* algorithm, via circlecore
- lazer judges slider heads differently
- lazer reads roughly **15–20% lower** for the same play

These values are consistent with each other, so trends are trustworthy. Just
don't compare them to the in-game figure.

**Some rows show `–` instead of a number.** osu! keeps one replay per map per
player — your best. A score that didn't beat your previous best has no replay,
so there's nothing to measure.

---

## Troubleshooting

**`osu-report: command not found`**
Linux — `~/.local/bin` isn't on your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"    # in ~/.bashrc or ~/.zshrc
fish_add_path ~/.local/bin              # fish
```
Windows — open a **new** terminal; the installer edits PATH and existing
terminals keep the old copy. If it still fails, Python probably wasn't added to
PATH when you installed it: re-run the Python installer and choose Modify.

**Windows: "running scripts is disabled on this system"**
Run it the way the install line shows, with `-ExecutionPolicy Bypass`. That
affects only that command.

**Windows: the terminal report shows garbled characters**
Use Windows Terminal rather than the old console window. The braille charts and
box characters need a modern terminal and a font that carries them.

**"API v2 auth failed" or replay downloads are skipped**
Your OAuth callback URL doesn't match. It must be `http://localhost:8727/`
exactly. Fix it at osu.ppy.sh → account settings → OAuth → Edit.

**Everything shows `–` in the UR column**
No legacy API key in your config, or the maps are unranked. circlecore fetches
beatmaps through the legacy API, which only serves ranked and approved maps.

**The report never appears when I close osu!**
Check the watcher is alive and read its log:
```bash
pgrep -af osu-session-watch
tail ~/.local/share/osu-tracker/watch.log
```

**No report, but no errors either**
Scores take a few seconds to submit. The watcher waits 60s; if you close osu!
very fast the last play may still be missing. Run `osu-report` again.

---

## Uninstall

```bash
./uninstall.sh                  # Linux
```
```powershell
.\uninstall.ps1                 # Windows
```

Removes the scripts and autostart entry. Your data and config are left alone
unless you pass `--purge`.

---

## Credits

Built on [ossapi](https://github.com/tybug/ossapi) for the osu! API and
[circleguard/circlecore](https://github.com/CircleguardCG/circlecore) for
unstable rate. The pp-over-time chart is modelled on
[osu!track](https://ameobea.me/osutrack/).

MIT licensed.
