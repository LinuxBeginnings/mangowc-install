#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Mango Autostart Script
# ==================================================

set +e

# Project version
export MANGO_DOTS_VERSION="0.0.4"

# Import environment for systemd user session & D-Bus
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE MANGO_DOTS_VERSION MANGO_INSTANCE_SIGNATURE WLR_NO_HARDWARE_CURSORS
fi
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE MANGO_DOTS_VERSION MANGO_INSTANCE_SIGNATURE WLR_NO_HARDWARE_CURSORS
fi

# Stop competing Hyprland background daemons that fail under Mango
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user stop hyprpolkitagent.service hyprpaper.service hyprsunset.service hypridle.service swaync.service 2>/dev/null || true
fi
pkill -x hyprpolkitagent 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true
pkill -x hyprsunset 2>/dev/null || true
pkill -x swaync 2>/dev/null || true

# Clean up stale Hyprland instance signatures so Noctalia connects to Mango
unset HYPRLAND_INSTANCE_SIGNATURE

# Start polkit authentication agent for MangoWM if not already running
if ! pgrep -x xfce-polkit >/dev/null 2>&1; then
    if [[ -x /usr/libexec/xfce-polkit ]]; then
        /usr/libexec/xfce-polkit >/dev/null 2>&1 &
    elif [[ -x /usr/lib/xfce-polkit/xfce-polkit ]]; then
        /usr/lib/xfce-polkit/xfce-polkit >/dev/null 2>&1 &
    elif command -v xfce-polkit >/dev/null 2>&1; then
        xfce-polkit >/dev/null 2>&1 &
    fi
fi

# Set GTK dark mode preference
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
fi

# Start Noctalia Shell (handles bar, launcher, wallpapers, notifications, dock)
if command -v noctalia >/dev/null 2>&1; then
    mkdir -p "${HOME}/.local/state/noctalia"
    noctalia > "${HOME}/.local/state/noctalia/noctalia.log" 2>&1 &
fi

# Waybar kept as an optional fallback bar (commented out)
# if command -v waybar >/dev/null 2>&1; then
#     waybar > "${HOME}/.local/state/waybar.log" 2>&1 &
# fi
