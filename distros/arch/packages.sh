#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

distro_setup() {
    log_info "Arch Linux setup..."
    log_ok "Arch package databases ready."
}

get_aur_helper() {
    if command -v yay >/dev/null 2>&1; then
        echo "yay"
    elif command -v paru >/dev/null 2>&1; then
        echo "paru"
    else
        echo ""
    fi
}

pkg_is_installed() {
    pacman -Qq "$1" &>/dev/null
}

pkg_in_repos() {
    pacman -Si "$1" &>/dev/null
}

pkg_install() {
    local to_install_repo=()
    local to_install_aur=()
    local aur_helper
    aur_helper="$(get_aur_helper)"

    for pkg in "$@"; do
        if pkg_is_installed "$pkg"; then
            log_debug "Package '$pkg' already installed."
        elif pkg_in_repos "$pkg"; then
            to_install_repo+=("$pkg")
        else
            to_install_aur+=("$pkg")
        fi
    done

    if [[ ${#to_install_repo[@]} -gt 0 ]]; then
        log_info "Installing official repository packages: ${to_install_repo[*]}"
        sudo pacman -S --needed --noconfirm "${to_install_repo[@]}" 2>&1 | tee -a "${LOG_FILE}"
    fi

    if [[ ${#to_install_aur[@]} -gt 0 ]]; then
        if [[ -n "${aur_helper}" ]]; then
            log_info "Installing AUR packages using ${aur_helper}: ${to_install_aur[*]}"
            "${aur_helper}" -S --needed --noconfirm "${to_install_aur[@]}" 2>&1 | tee -a "${LOG_FILE}"
        else
            log_warn "AUR helper (yay/paru) not found. Could not install AUR packages: ${to_install_aur[*]}"
            log_warn "Please install them manually using your preferred AUR helper."
        fi
    fi
}

install_core_packages() {
    log_info "Installing core packages for mangowc + noctalia + kitty..."

    local core_pkgs=(
        # Base tools & Wayland prerequisites
        git curl wget rsync xorg-xwayland wl-clipboard wl-mirror wlr-randr
        grim slurp gpu-screen-recorder xdg-desktop-portal-wlr xdg-desktop-portal-gtk

        # Terminal & system info
        kitty fastfetch yazi thunar eza htop btop zoxide

        # Quickshell & Qt6 dependencies
        quickshell qt6-5compat qt6-declarative qt6-wayland qt6-svg qt6-multimedia
        socat jq

        # Compositor & Shell
        # On Arch/CachyOS/AUR, the compositor package is 'mangowm' (provides mangowc)
        mangowm
        noctalia
    )

    pkg_install "${core_pkgs[@]}"

    if pkg_is_installed "mangowm" || pkg_is_installed "mangowc" || command -v mango >/dev/null 2>&1 || command -v mangowc >/dev/null 2>&1; then
        log_ok "Mango compositor verified."
    else
        log_warn "mangowm / mangowc executable not found. Ensure mangowm is installed."
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
