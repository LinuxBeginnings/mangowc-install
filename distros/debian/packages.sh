#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

distro_setup() {
    log_info "Updating Debian/Ubuntu package lists..."
    sudo apt-get update -y 2>&1 | tee -a "${LOG_FILE}"
}

pkg_is_installed() {
    dpkg -s "$1" &>/dev/null
}

pkg_install() {
    local to_install=()
    for pkg in "$@"; do
        if pkg_is_installed "$pkg"; then
            log_debug "Package '$pkg' already installed."
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Installing packages: ${to_install[*]}"
    sudo apt-get install -y "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"
}

install_core_packages() {
    local core_pkgs=(
        git curl wget rsync xwayland wl-clipboard
        grim slurp xdg-desktop-portal-wlr xdg-desktop-portal-gtk
        kitty fastfetch yazi thunar eza htop btop zoxide
        qml6-module-qtquick-templates qml6-module-qt5compat-graphicaleffects
        qt6-wayland qml6-module-qtquick-layouts qml6-module-qtquick-controls
        socat jq
    )
    pkg_install "${core_pkgs[@]}"
}

install_greeter_packages() {
    pkg_install greetd
}
