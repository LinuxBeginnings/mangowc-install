#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

configure_ubuntu_repos() {
    log_info "Configuring Ubuntu repositories..."

    # Ensure universe repository is enabled
    if command -v add-apt-repository >/dev/null 2>&1; then
        sudo add-apt-repository -y universe 2>&1 | tee -a "${LOG_FILE}" || true
    fi

    # Note: ButterRepo debs are compiled for Debian Trixie (Qt 6.8 / libdisplay-info2)
    # and conflict with Ubuntu 26.04's Qt 6.10 / libdisplay-info3 stack.
    # If an incompatible ButterRepo source exists on Ubuntu 26.04, disable it.
    local butter_list="/etc/apt/sources.list.d/butterrepo.list"
    if [[ -f "${butter_list}" ]]; then
        log_warn "Removing incompatible Debian-targeted ButterRepo on Ubuntu 26.04 to prevent ABI conflicts..."
        sudo rm -f "${butter_list}"
    fi

    log_info "Updating package lists..."
    sudo apt-get update -y 2>&1 | tee -a "${LOG_FILE}"
}

distro_setup() {
    configure_ubuntu_repos
}
