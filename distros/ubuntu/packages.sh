#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

# Check if a package is installed via dpkg
pkg_is_installed() {
    dpkg -s "$1" &>/dev/null
}

# Check if a package exists and has an installable candidate in apt
pkg_in_repos() {
    local candidate
    candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
    [[ -n "${candidate}" && "${candidate}" != "(none)" ]]
}

# Install missing packages using apt
pkg_install() {
    local to_install=()
    local unavailable=()

    for pkg in "$@"; do
        if pkg_is_installed "${pkg}"; then
            log_debug "Package '${pkg}' is already installed."
        elif pkg_in_repos "${pkg}"; then
            to_install+=("${pkg}")
        else
            unavailable+=("${pkg}")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 && ${#unavailable[@]} -eq 0 ]]; then
        log_ok "All requested packages are already installed."
        return 0
    fi

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing packages: ${to_install[*]}"
        sudo apt-get install -y "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"
    fi

    if [[ ${#unavailable[@]} -gt 0 ]]; then
        log_warn "Packages not found in active repositories (skipping): ${unavailable[*]}"
    fi
}

install_core_packages() {
    log_info "Installing core packages for mangowc + quickshell + kitty..."

    local core_pkgs=(
        # Base tools & Wayland prerequisites
        git
        curl
        wget
        rsync
        xwayland
        wl-clipboard
        wl-mirror
        wlr-randr
        grim
        slurp
        gpu-screen-recorder
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk

        # Terminal & system info
        kitty
        fastfetch
        yazi
        thunar
        eza
        htop
        btop
        zoxide

        # Theming & Appearance
        bibata-cursor-theme
        qt5ct
        qt6ct
        fonts-noto-color-emoji

        # Polkit Authentication Agent
        xfce-polkit

        # Quickshell & Qt6/QML Runtime Dependencies
        quickshell
        qml6-module-qtquick-templates
        qml6-module-qt5compat-graphicaleffects
        qt6-wayland
        qml6-module-qtquick-layouts
        qml6-module-qtquick-controls
        qml6-module-qtquick-shapes
        socat
        jq

        # Compositor & Shell
        mangowc
        noctalia
    )

    pkg_install "${core_pkgs[@]}"

    if pkg_is_installed "mangowc" || pkg_is_installed "mangowm" || command -v mango >/dev/null 2>&1 || command -v mangowc >/dev/null 2>&1; then
        log_ok "Mango compositor verified."
    else
        log_warn "mangowc executable not found. Ensure mangowc is installed."
    fi
}

install_greeter_packages() {
    log_info "Checking / installing greetd and noctalia-greeter packages..."
    local greeter_pkgs=(
        greetd
        noctalia-greeter
    )
    pkg_install "${greeter_pkgs[@]}"
}
