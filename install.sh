#!/usr/bin/env bash
# osu-session-report installer.
#
# Safe to re-run: it skips anything already done and never overwrites your
# config. Nothing here needs root.

set -uo pipefail

BIN="$HOME/.local/bin"
CFG_DIR="$HOME/.config/osu-tracker"
CFG="$CFG_DIR/config.json"
DATA="$HOME/.local/share/osu-tracker"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bold=$'\e[1m'; dim=$'\e[2m'; grn=$'\e[32m'; red=$'\e[31m'; ylw=$'\e[33m'; off=$'\e[0m'
ok()   { printf '  %s✓%s %s\n' "$grn" "$off" "$1"; }
warn() { printf '  %s!%s %s\n' "$ylw" "$off" "$1"; }
err()  { printf '  %s✗%s %s\n' "$red" "$off" "$1"; }
step() { printf '\n%s%s%s\n' "$bold" "$1" "$off"; }

printf '\n%s  osu! session report — installer%s\n' "$bold" "$off"
printf '%s  builds a visual dashboard when you close osu!%s\n' "$dim" "$off"

# ---------------------------------------------------------------- python --
step "1. Checking Python"
if ! command -v python3 >/dev/null; then
    err "python3 not found. Install it first:"
    echo "      Arch:   sudo pacman -S python python-pip"
    echo "      Ubuntu: sudo apt install python3 python3-pip"
    echo "      Fedora: sudo dnf install python3 python3-pip"
    exit 1
fi
PYV=$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')
if ! python3 -c 'import sys;sys.exit(0 if sys.version_info>=(3,9) else 1)'; then
    err "Python $PYV is too old; 3.9 or newer is needed."
    exit 1
fi
ok "Python $PYV"

# ------------------------------------------------------------ python deps --
step "2. Installing Python packages"
# Arch and other "externally managed" installs reject a plain pip --user, so
# fall back to the documented override rather than failing.
pip_install() {
    python3 -m pip install --user --quiet --upgrade "$@" 2>/dev/null \
        || python3 -m pip install --user --quiet --upgrade --break-system-packages "$@"
}
MISSING=()
python3 -c 'import ossapi'     2>/dev/null || MISSING+=(ossapi)
python3 -c 'import circleguard' 2>/dev/null || MISSING+=(circleguard)
python3 -c 'import PIL'        2>/dev/null || MISSING+=(pillow)
if [ ${#MISSING[@]} -eq 0 ]; then
    ok "ossapi, circleguard, pillow already present"
else
    echo "     installing: ${MISSING[*]}  (this can take a minute)"
    if pip_install "${MISSING[@]}"; then
        ok "installed ${MISSING[*]}"
    else
        err "pip failed. Try manually:"
        echo "      python3 -m pip install --user ossapi circleguard pillow"
        exit 1
    fi
fi

# ------------------------------------------------------------------ files --
step "3. Installing scripts to ~/.local/bin"
mkdir -p "$BIN" "$DATA"
for f in osu-report osu-stats osu-session-watch.sh; do
    install -m 755 "$SRC/bin/$f" "$BIN/$f" && ok "$f"
done

case ":$PATH:" in
    *":$BIN:"*) ok "~/.local/bin is on your PATH" ;;
    *)  warn "~/.local/bin is NOT on your PATH. Add this to your shell config:"
        echo "      bash/zsh  ->  export PATH=\"\$HOME/.local/bin:\$PATH\"   (~/.bashrc or ~/.zshrc)"
        echo "      fish      ->  fish_add_path ~/.local/bin"
        ;;
esac

# ----------------------------------------------------------------- config --
step "4. osu! API credentials"
mkdir -p "$CFG_DIR"; chmod 700 "$CFG_DIR"

if [ -f "$CFG" ]; then
    ok "config already exists at $CFG (left untouched)"
else
    cat <<'GUIDE'
     You need two things from https://osu.ppy.sh/home/account/edit

     A) OAuth application  (scroll to "OAuth")
        - click "New OAuth Application"
        - Application Name:  anything, e.g. session report
        - Application Callback URL:  http://localhost:8727/
          ^ this must match EXACTLY, including the trailing slash
        - click Register, then note the Client ID and Client Secret

     B) Legacy API key  (scroll to "Legacy API")
        - click "New Legacy API Key", give it any name
        - this one is used to fetch beatmaps for the UR calculation

GUIDE
    read -rp "     Your osu! username: " OSU_USER
    read -rp "     Client ID: " OSU_ID
    read -rsp "     Client Secret (hidden): " OSU_SECRET; echo
    read -rsp "     Legacy API key (hidden, optional - press Enter to skip): " OSU_KEY; echo

    umask 077
    cat >"$CFG" <<JSON
{
  "client_id": "${OSU_ID}",
  "client_secret": "${OSU_SECRET}",
  "username": "${OSU_USER}",
  "mode": "osu",
  "api_key": "${OSU_KEY}",
  "redirect_uri": "http://localhost:8727/",
  "replay_dir": ""
}
JSON
    chmod 600 "$CFG"
    ok "wrote $CFG (permissions 600 — only you can read it)"
fi

# -------------------------------------------------------------- autostart --
step "5. Run automatically when you close osu!?"
echo "     The watcher sits in the background, notices osu! exit, and builds"
echo "     the report. You can also skip this and run osu-report by hand."
echo
echo "       1) Hyprland   (adds an exec-once line)"
echo "       2) systemd    (a user service, works on most desktops)"
echo "       3) Skip"
read -rp "     Choose [1/2/3]: " CHOICE

case "${CHOICE:-3}" in
 1)
    HYPR_USER="$HOME/.config/hypr/custom.conf"
    for c in "$HOME/.config/caelestia/hypr-user.conf" "$HOME/.config/hypr/custom.conf"; do
        [ -f "$c" ] && HYPR_USER="$c" && break
    done
    mkdir -p "$(dirname "$HYPR_USER")"
    if grep -q "osu-session-watch" "$HYPR_USER" 2>/dev/null; then
        ok "already present in $HYPR_USER"
    else
        {
          echo ""
          echo "# osu! session report — builds a dashboard when osu! closes"
          echo "exec-once = env OSU_REPORT_MODE=browser $BIN/osu-session-watch.sh"
          echo "bind = Super+Shift, O, exec, $BIN/osu-report --hours 6"
          echo "bind = Super+Shift, B, exec, $BIN/osu-report --brief --copy --fast --notify"
        } >>"$HYPR_USER"
        ok "added to $HYPR_USER"
        warn "reload Hyprland (hyprctl reload) or log out and back in"
    fi
    ;;
 2)
    UNIT="$HOME/.config/systemd/user/osu-session-watch.service"
    mkdir -p "$(dirname "$UNIT")"
    cat >"$UNIT" <<UNITEOF
[Unit]
Description=osu! session report watcher
After=graphical-session.target

[Service]
Type=simple
Environment=OSU_REPORT_MODE=browser
ExecStart=$BIN/osu-session-watch.sh
Restart=on-failure
RestartSec=30

[Install]
WantedBy=default.target
UNITEOF
    systemctl --user daemon-reload
    systemctl --user enable --now osu-session-watch.service \
        && ok "systemd service enabled and started" \
        || warn "could not start the service; check: systemctl --user status osu-session-watch"
    ;;
 *) ok "skipped — run 'osu-report' yourself whenever you like" ;;
esac

# ------------------------------------------------------------------- done --
step "Done"
cat <<EOF
     Try it now:

       osu-report            full dashboard, opens in your browser
       osu-report --term     same data drawn in the terminal
       osu-report --brief    a Markdown summary for feeding to an AI

     The first run downloads a few replays, so give it a moment.
     Reports are written to $DATA/reports/

EOF
