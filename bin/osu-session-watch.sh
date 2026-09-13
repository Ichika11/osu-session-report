#!/usr/bin/env bash
# Waits for osu! to exit, then builds the session report and opens it.
# Autostarted from ~/.config/caelestia/hypr-user.conf; loops forever.

REPORT="$HOME/.local/bin/osu-report"
DATA="$HOME/.local/share/osu-tracker"
LOG="$DATA/watch.log"
LOCK="$DATA/watch.lock"

# How the report appears when osu! closes. Override by exporting the variable,
# or just change the default here.
#   browser  full HTML dashboard in a new Firefox window
#   term     ANSI dashboard in a foot window (fast, no browser)
#   image    the report drawn inline in the terminal (slowest, pixel-exact)
MODE="${OSU_REPORT_MODE:-term}"

# osu! lazer's AppImage shows up as `osu!`; the other two cover stable/wine.
PATTERN='osu!|osu\.AppImage|osu\.exe'

mkdir -p "$DATA"

# One watcher at a time — a Hyprland reload re-runs exec-once.
exec 9>"$LOCK"
flock -n 9 || exit 0

# Which terminal to open for term/image mode. $TERMINAL wins if you set it;
# otherwise take the first one actually installed. All of these accept -e.
pick_terminal() {
    if [ -n "${TERMINAL:-}" ] && command -v "$TERMINAL" >/dev/null 2>&1; then
        printf '%s' "$TERMINAL"; return
    fi
    for t in foot kitty ghostty wezterm alacritty konsole gnome-terminal \
             xfce4-terminal tilix urxvt xterm; do
        if command -v "$t" >/dev/null 2>&1; then printf '%s' "$t"; return; fi
    done
}

log() {
    printf '%s  %s\n' "$(date '+%F %T')" "$*" >>"$LOG"
    # keep the log from growing without bound
    if [ "$(wc -l <"$LOG" 2>/dev/null || echo 0)" -gt 600 ]; then
        tail -n 300 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi
}

log "watcher started (pid $$)"

while true; do
    # wait for osu! to start
    until pgrep -f "$PATTERN" >/dev/null 2>&1; do sleep 20; done
    start=$(date +%s)
    log "osu! detected"

    # wait for it to stop
    while pgrep -f "$PATTERN" >/dev/null 2>&1; do sleep 20; done

    # round the window up to whole hours, minimum 1
    elapsed=$(( ($(date +%s) - start + 3599) / 3600 ))
    [ "$elapsed" -lt 1 ] && elapsed=1
    log "osu! exited; session window ${elapsed}h"

    sleep 60   # let the last score submit

    # --copy leaves the Markdown digest on the clipboard, ready to paste
    # straight into Claude without touching the file manager
    case "$MODE" in
        term|image)
            term=$(pick_terminal)
            if [ -z "$term" ]; then
                log "no terminal emulator found; falling back to the browser"
                "$REPORT" --hours "$elapsed" --notify --copy >>"$LOG" 2>&1
            else
                # explicitly bash, not the login shell, so `read -n1` behaves
                "$term" -e bash -c \
                    "'$REPORT' --hours $elapsed --$MODE --notify --copy; \
                     printf '\n  press any key to close '; read -n1 -s" \
                    >>"$LOG" 2>&1 \
                    && log "report shown in $term ($MODE), brief copied" \
                    || log "$term report failed (exit $?)"
            fi
            ;;
        *)
            "$REPORT" --hours "$elapsed" --notify --copy >>"$LOG" 2>&1 \
                && log "report opened in browser, brief copied" \
                || log "report failed (exit $?)"
            ;;
    esac
done
