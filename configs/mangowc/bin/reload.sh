#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Reload script for Mango + Noctalia
# ==================================================

set +e

# Reload mango configuration
if command -v mmsg >/dev/null 2>&1; then
    mmsg -d reload_config 2>/dev/null || true
fi

# Reload Noctalia Shell
if command -v noctalia >/dev/null 2>&1; then
    noctalia msg reload 2>/dev/null || true
fi

notify-send "Config Reloaded" "Mango and Noctalia reloaded successfully" 2>/dev/null || true
