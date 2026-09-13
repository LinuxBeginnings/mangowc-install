#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

configure_debian_repos() {
    log_info "Configuring Debian repositories..."

    local codename="${DETECTED_CODENAME:-}"
    if [[ -z "${codename}" ]]; then
        codename="$(grep -E '^(VERSION_CODENAME|DEBIAN_CODENAME)=' /etc/os-release | cut -d= -f2 | tr -d '"' | head -n1 || echo "")"
    fi

    # Debian Trixie (13): Configure ButterRepo (provides prebuilt mangowc 0.14.4 against wlroots 0.19 and scenefx 0.4)
    # and ensure trixie-backports is available (for uwsm, quickshell, etc.)
    if [[ "${codename}" == "trixie" || "${DETECTED_VERSION_ID:-}" == "13" ]]; then
        log_info "Detected Debian 13 (Trixie). Configuring ButterRepo & backports..."

        local butter_key="/usr/share/keyrings/butterrepo.gpg"
        local butter_list="/etc/apt/sources.list.d/butterrepo.list"

        if [[ ! -f "${butter_key}" ]]; then
            log_info "Fetching ButterRepo signing key..."
            sudo mkdir -p /usr/share/keyrings
            if curl -fsSL "https://apt.justaguy.dev/key.asc" | sudo gpg --dearmor --yes -o "${butter_key}" 2>&1 | tee -a "${LOG_FILE}"; then
                log_ok "Installed ButterRepo key to ${butter_key}."
            else
                log_warn "Failed to install ButterRepo GPG key."
            fi
        fi

        if [[ ! -f "${butter_list}" ]]; then
            log_info "Adding ButterRepo APT repository..."
            echo "deb [arch=amd64 signed-by=${butter_key}] https://apt.justaguy.dev stable main" | sudo tee "${butter_list}" >/dev/null
            log_ok "ButterRepo configured at ${butter_list}."
        else
            log_ok "ButterRepo already configured."
        fi

        # Ensure trixie-backports is configured on Debian (for uwsm and newer backports)
        if ! grep -rq "trixie-backports" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
            log_info "Enabling trixie-backports for dependencies (e.g. uwsm)..."
            echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free-firmware non-free" | sudo tee /etc/apt/sources.list.d/trixie-backports.list >/dev/null
        fi
    else
        # Debian Forky (14) / Sid (unstable):
        # Isolate from Trixie. ButterRepo packages are compiled for Trixie (Qt 6.8 / libdisplay-info2)
        # and conflict with newer Forky/Sid Wayland stacks.
        local butter_list="/etc/apt/sources.list.d/butterrepo.list"
        if [[ -f "${butter_list}" ]]; then
            log_warn "Disabling Debian Trixie ButterRepo on Debian ${codename:-newer} to prevent ABI conflicts..."
            sudo rm -f "${butter_list}"
            sudo apt-get update -y 2>&1 | tee -a "${LOG_FILE}"
        fi
        log_info "Debian ${codename:-Forky/Sid} detected. Using standard repositories and building MangoWC from source."
    fi

    log_info "Updating package lists..."
    sudo apt-get update -y 2>&1 | tee -a "${LOG_FILE}"
}

distro_setup() {
    configure_debian_repos
}
