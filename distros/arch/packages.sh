#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

distro_setup() {
    log_info "Arch Linux setup..."
    log_ok "Arch package databases synchronized."
}

pkg_is_installed() {
    pacman -Qq "$1" &>/dev/null
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
    sudo pacman -S --needed --noconfirm "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"
}

install_core_packages() {
    local core_pkgs=(
        git curl wget rsync xorg-xwayland wl-clipboard wl-mirror wlr-randr
        grim slurp gpu-screen-recorder xdg-desktop-portal-wlr xdg-desktop-portal-gtk
        kitty fastfetch yazi thunar eza htop btop zoxide
        qt6-5compat qt6-declarative qt6-wayland qt6-svg qt6-multimedia
        socat jq
    )
    pkg_install "${core_pkgs[@]}"
    log_info "Note: mangowc, noctalia, and quickshell can be installed from AUR on Arch."
}

install_greeter_packages() {
    pkg_install greetd
}
