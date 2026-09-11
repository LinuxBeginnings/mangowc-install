#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Mango Autostart Script
# ==================================================

set +e

# Project version
export MANGO_DOTS_VERSION="0.0.1"

# Import environment for systemd user session
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE MANGO_DOTS_VERSION
fi

# If hyprpolkitagent is running or active in systemd, stop it for this mango session
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user stop hyprpolkitagent.service 2>/dev/null || true
fi
pkill -x hyprpolkitagent 2>/dev/null || true

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

# Start xdg-desktop-portal backends
if [[ -x /usr/libexec/xdg-desktop-portal-gtk ]]; then
    /usr/libexec/xdg-desktop-portal-gtk >/dev/null 2>&1 &
elif [[ -x /usr/lib/xdg-desktop-portal-gtk ]]; then
    /usr/lib/xdg-desktop-portal-gtk >/dev/null 2>&1 &
fi

if [[ -x /usr/libexec/xdg-desktop-portal-wlr ]]; then
    /usr/libexec/xdg-desktop-portal-wlr >/dev/null 2>&1 &
elif [[ -x /usr/lib/xdg-desktop-portal-wlr ]]; then
    /usr/lib/xdg-desktop-portal-wlr >/dev/null 2>&1 &
fi

sleep 1

if [[ -x /usr/libexec/xdg-desktop-portal ]]; then
    /usr/libexec/xdg-desktop-portal >/dev/null 2>&1 &
elif [[ -x /usr/lib/xdg-desktop-portal ]]; then
    /usr/lib/xdg-desktop-portal >/dev/null 2>&1 &
fi

# Set GTK dark mode preference
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
fi

# Start Noctalia Shell (handles bar, launcher, wallpapers, notifications, dock)
if command -v noctalia >/dev/null 2>&1; then
    noctalia &
fi
