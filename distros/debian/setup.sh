#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

configure_debian_repos() {
    log_info "Configuring Debian repositories..."

    log_info "Updating package lists..."
    sudo apt-get update -y 2>&1 | tee -a "${LOG_FILE}"
}

distro_setup() {
    configure_debian_repos
}
