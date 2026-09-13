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

# Get package version from official/configured repos
get_repo_version() {
    local pkg="$1"
    pacman -Si "$pkg" 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}'
}

# Get package version from AUR via yay or paru
get_aur_version() {
    local pkg="$1"
    local helper="$2"
    if [[ "$helper" == "yay" ]]; then
        yay -Si "aur/$pkg" 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}' || \
            yay -Si "$pkg" 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}'
    elif [[ "$helper" == "paru" ]]; then
        paru -Si "aur/$pkg" 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}' || \
            paru -Si "$pkg" 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}'
    fi
}

# Check if official core/extra repos provide the package
pkg_in_official_arch_repos() {
    local pkg="$1"
    pacman -Si "core/$pkg" &>/dev/null || pacman -Si "extra/$pkg" &>/dev/null || pacman -Si "multilib/$pkg" &>/dev/null
}

pkg_install() {
    local to_install_repo=()
    local to_install_aur=()
    local aur_helper
    aur_helper="$(get_aur_helper)"

    for pkg in "$@"; do
        if pkg_is_installed "$pkg"; then
            # If already installed, verify if an AUR helper can provide a newer version (e.g. AUR vs older 3rd-party repo)
            if [[ -n "${aur_helper}" ]]; then
                local installed_ver aur_ver
                installed_ver="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')"
                aur_ver="$(get_aur_version "$pkg" "$aur_helper" || true)"
                if [[ -n "${installed_ver}" && -n "${aur_ver}" ]] && command -v vercmp >/dev/null 2>&1; then
                    if [[ "$(vercmp "${aur_ver}" "${installed_ver}")" -gt 0 ]]; then
                        log_info "Package '$pkg' has a newer version in AUR (${aur_ver} > ${installed_ver}). Queueing AUR update..."
                        to_install_aur+=("$pkg")
                        continue
                    fi
                fi
            fi
            log_debug "Package '$pkg' already installed."
        elif pkg_in_official_arch_repos "$pkg"; then
            # Priority 1: Official Arch repositories (core/extra/multilib)
            to_install_repo+=("$pkg")
        elif [[ -n "${aur_helper}" ]]; then
            # If in 3rd-party repos (e.g. cachyos) vs AUR, prefer AUR or newer version
            local repo_ver aur_ver
            repo_ver="$(get_repo_version "$pkg" || true)"
            aur_ver="$(get_aur_version "$pkg" "$aur_helper" || true)"

            if [[ -n "${aur_ver}" && -n "${repo_ver}" ]] && command -v vercmp >/dev/null 2>&1; then
                if [[ "$(vercmp "${aur_ver}" "${repo_ver}")" -gt 0 ]]; then
                    log_info "Preferring AUR for '$pkg' (${aur_ver}) over repo version (${repo_ver})."
                    to_install_aur+=("$pkg")
                else
                    to_install_repo+=("$pkg")
                fi
            elif [[ -n "${aur_ver}" ]]; then
                to_install_aur+=("$pkg")
            elif pkg_in_repos "$pkg"; then
                to_install_repo+=("$pkg")
            else
                to_install_aur+=("$pkg")
            fi
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
