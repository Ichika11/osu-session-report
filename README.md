# osu! session report

Close osu!, and a dashboard of your session opens by itself.

![The dashboard](docs/dashboard.jpg)

Runs entirely on your machine. Nothing leaves it except a request to osu!'s API
for your own scores.

---

## Install

**You need:** Python 3.9+, and osu! (lazer or stable).

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

The installer changes your PATH. Terminals already open keep the old one.

---

### What the installer asks for

Two things from <https://osu.ppy.sh/home/account/edit>. It tells you where to
click, and it's safe to run again any time.

| | Where | Used for |
|---|---|---|
| **OAuth app** | the "OAuth" section | your profile and scores |
| **Legacy API key** | the "Legacy API" section | unstable rate (optional) |

> ⚠️ Set the OAuth **Callback URL** to exactly `http://localhost:8727/`
> — trailing slash included, or replay downloads fail.

---

## Use it

Close osu! and the report opens on its own. Or run it yourself:

```bash
osu-report
```

| | |
|---|---|
| `osu-report` | dashboard in your browser |
| `osu-report --term` | the same thing in your terminal |
| `osu-report --brief` | a summary you can paste into an AI |

![Terminal report](docs/terminal.jpg)

---

## More

- **[Screenshots](docs/GALLERY.md)** — the rest of the dashboard
- **[Usage](docs/USAGE.md)** — every option, the background watcher, file locations
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** — if something doesn't work

---

Built on [ossapi](https://github.com/tybug/ossapi) and
[circlecore](https://github.com/CircleguardCG/circlecore). The pp-over-time
chart is modelled on [osu!track](https://ameobea.me/osutrack/). MIT licensed.
