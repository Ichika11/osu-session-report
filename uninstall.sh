#!/usr/bin/env bash
# Removes osu-session-report. Data and credentials are kept unless --purge.

set -uo pipefail
BIN="$HOME/.local/bin"
DATA="$HOME/.local/share/osu-tracker"
CFG_DIR="$HOME/.config/osu-tracker"
grn=$'\e[32m'; ylw=$'\e[33m'; off=$'\e[0m'
ok()   { printf '  %s✓%s %s\n' "$grn" "$off" "$1"; }
warn() { printf '  %s!%s %s\n' "$ylw" "$off" "$1"; }

echo
echo "Removing osu-session-report..."

# stop the watcher by pid — `pkill -f` would also match this script's own
# command line and kill the uninstaller partway through
for pid in $(pgrep -f "osu-session-watch\.sh" 2>/dev/null); do
    [ "$pid" != "$$" ] && kill "$pid" 2>/dev/null && ok "stopped watcher (pid $pid)"
done

if systemctl --user list-unit-files osu-session-watch.service >/dev/null 2>&1; then
    systemctl --user disable --now osu-session-watch.service 2>/dev/null
    rm -f "$HOME/.config/systemd/user/osu-session-watch.service"
    systemctl --user daemon-reload 2>/dev/null
    ok "removed systemd service"
fi

for c in "$HOME/.config/caelestia/hypr-user.conf" "$HOME/.config/hypr/custom.conf"; do
    if [ -f "$c" ] && grep -q "osu-session-watch\|osu-report" "$c"; then
        cp "$c" "$c.bak"
        sed -i '/osu! session report/,+4d; /osu-session-watch/d; /osu-report/d' "$c"
        ok "cleaned $c (backup at $c.bak)"
    fi
done

for f in osu-report osu-stats osu-session-watch.sh; do
    [ -e "$BIN/$f" ] && rm -f "$BIN/$f" && ok "removed $f"
done

if [ "${1:-}" = "--purge" ]; then
    rm -rf "$DATA" "$CFG_DIR"
    ok "purged data and credentials"
else
    warn "kept your data:        $DATA"
    warn "kept your credentials: $CFG_DIR"
    echo "       re-run with --purge to delete them too"
fi
echo
