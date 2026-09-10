#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

# Check if a package is installed via rpm
pkg_is_installed() {
    local pkg="$1"
    rpm -q "${pkg}" &>/dev/null
}

# Install list of packages using DNF
pkg_install() {
    local to_install=()

    for pkg in "$@"; do
        if pkg_is_installed "${pkg}"; then
            log_debug "Package '${pkg}' is already installed."
        else
            to_install+=("${pkg}")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_ok "All requested packages are already installed."
        return 0
    fi

    log_info "Installing missing packages: ${to_install[*]}"
    sudo dnf install -y "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"

    local failed=()
    for pkg in "${to_install[@]}"; do
        if ! pkg_is_installed "${pkg}"; then
            if ! command -v "${pkg}" >/dev/null 2>&1; then
                failed+=("${pkg}")
            fi
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_warn "Some packages may not have installed cleanly: ${failed[*]}"
    else
        log_ok "All packages installed successfully."
    fi
}

install_core_packages() {
    log_info "Installing core packages for mangowc + noctalia + kitty..."

    local core_pkgs=(
        # Base tools & Wayland prerequisites
        git
        curl
        wget
        rsync
        xorg-x11-server-Xwayland
        wl-clipboard
        grim
        slurp
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
        google-noto-color-emoji-fonts

        # Quickshell & Qt6/QML Runtime Dependencies
        quickshell
        qt6-qtdeclarative
        qt6-qtwayland
        qt6-qt5compat
        qt6-qtsvg
        qt6-qtmultimedia
        qt6-qtimageformats
        socat
        jq

        # Compositor & Shell
        mangowm
        noctalia
    )

    pkg_install "${core_pkgs[@]}"
}

install_greeter_packages() {
    log_info "Checking / installing greetd packages..."
    local greeter_pkgs=(
        greetd
    )
    pkg_install "${greeter_pkgs[@]}"
}
