# Troubleshooting

[← back to README](../README.md)

## `osu-report: command not found`

**Linux** — `~/.local/bin` isn't on your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"    # in ~/.bashrc or ~/.zshrc
fish_add_path ~/.local/bin              # fish
```

**Windows** — open a **new** terminal. The installer edits PATH, and terminals
that were already open keep the old copy.

Still failing? Python probably wasn't added to PATH when you installed it.
Re-run the Python installer and choose **Modify**.

---

## Windows: "running scripts is disabled on this system"

Run it exactly as the install step shows, with `-ExecutionPolicy Bypass`. That
applies to the one command only and changes nothing permanently.

---

## Windows: the terminal report shows garbled characters

Use **Windows Terminal**, not the old console window. The braille charts and box
characters need a modern terminal and a font that carries them.

---

## "API v2 auth failed", or replays are skipped

Your OAuth callback URL doesn't match. It must be exactly:

```
http://localhost:8727/
```

Fix it at osu.ppy.sh → account settings → OAuth → Edit. The trailing slash
matters.

---

## Everything shows `–` in the UR column

Either there's no legacy API key in your config, or the maps are unranked.
circlecore fetches beatmaps through the legacy API, which only serves ranked
and approved maps.

---

## The report never appears when I close osu!

Check the watcher is alive, and read its log:

```bash
pgrep -af osu-session-watch
tail ~/.local/share/osu-tracker/watch.log
```

---

## No report, but no errors either

Scores take a few seconds to submit. The watcher waits 60 seconds — if you
closed osu! very fast, the last play may not have registered yet.

Just run `osu-report` again.

---

## UR doesn't match what lazer shows me

That's expected.

- UR here uses the *stable* algorithm, via circlecore
- lazer judges slider heads differently
- lazer reads roughly **15–20% lower** for the same play

The values are consistent with each other, so trends are trustworthy. Just
don't compare them against the in-game figure.

UR is the standard deviation of your hit timing error, ×10. Lower is steadier.
