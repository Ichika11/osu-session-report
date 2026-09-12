# osu! session report

When you close osu!, this builds a dashboard of how the session went and opens
it — top plays, progress curves, tapping consistency, and a breakdown of where
your accuracy actually falls apart.

Everything runs locally. The only thing that leaves your machine is a request
to osu!'s own API for your own scores.

---

## What you get

**A full HTML dashboard** — your profile banner, headline stats with the change
since the session began, the session's best plays and your all-time top 10 (each
row links to the map), a scatter of every top play over time, progress curves
for pp / rank / accuracy, and rings for your hit and grade composition.

**The same thing in your terminal** — `--term` draws it with truecolour and
braille line charts. No browser, works over SSH.

**A Markdown digest for AI** — `--brief` writes a compact analysis file you can
paste into Claude or ChatGPT and ask "where should I focus?". It reports
performance banded by star rating, BPM, approach rate, OD and circle size, plus
the caveats needed to read those numbers correctly.

---

## Install

You need a Linux machine with Python 3.9+ and osu! (lazer or stable).

```bash
git clone https://github.com/Ichika11/osu-session-report.git
cd osu-session-report
./install.sh
```

The installer walks you through everything, including where to click on the osu!
website to get your API credentials. It is safe to run again later.

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

`osu-session-watch.sh` polls every 20 seconds for an osu! process. When osu!
exits it waits 60 seconds for the last score to submit, then builds the report.
It takes a lock file, so a config reload can't start a second copy.

Change how the report appears by editing `MODE` at the top of
`~/.local/bin/osu-session-watch.sh`, or by setting `OSU_REPORT_MODE`:

| Mode | Result |
|---|---|
| `browser` | HTML dashboard in a new browser window (default) |
| `term` | the ANSI dashboard in a terminal window |
| `sixel` | the HTML report drawn inline as sixel graphics |

**Restart the watcher after changing it.** Bash reads a script as it runs, so an
edit doesn't reach the running process:

```bash
pkill -f osu-session-watch.sh; setsid ~/.local/bin/osu-session-watch.sh &>/dev/null &
```

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

**It will not match the number lazer shows you.** UR here is computed by
circlecore using the *stable* algorithm; lazer judges slider heads differently
and reads roughly 15–20% lower for the same play. The values are consistent with
each other, so they're good for tracking trends — just don't compare them
against the in-game figure.

UR is only available for scores that have a stored replay. osu! keeps **one
replay per map per player** (your best), so a score that didn't beat your
previous best shows `–`.

---

## Troubleshooting

**`osu-report: command not found`**
`~/.local/bin` isn't on your PATH. Add it:
```bash
export PATH="$HOME/.local/bin:$PATH"    # in ~/.bashrc or ~/.zshrc
fish_add_path ~/.local/bin              # fish
```

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
./uninstall.sh
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
