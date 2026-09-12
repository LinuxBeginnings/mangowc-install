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

    # Configure ButterRepo (provides mangowc, quickshell)
    local butter_url="https://apt.justaguy.dev"
    local butter_key="/usr/share/keyrings/butterrepo.gpg"
    local butter_list="/etc/apt/sources.list.d/butterrepo.list"
    local butter_line="deb [arch=amd64 signed-by=${butter_key}] ${butter_url} stable main"

    local needs_key=0
    if [[ ! -f "${butter_key}" ]]; then
        needs_key=1
    fi

    if [[ "${needs_key}" -eq 1 || ! -f "${butter_list}" ]] || ! apt-cache policy butterrepo-keyring 2>/dev/null | grep -qE "butterrepo|justaguy"; then
        log_info "Configuring ButterRepo repository for mangowc and quickshell..."
        sudo apt-get install -y curl gnupg 2>&1 | tee -a "${LOG_FILE}"
        if curl -fsSL "${butter_url}/key.asc" | sudo gpg --dearmor --yes -o "${butter_key}"; then
            echo "${butter_line}" | sudo tee "${butter_list}" >/dev/null
            log_ok "ButterRepo repository configured at ${butter_list}."
        else
            log_warn "Failed to download ButterRepo signing key."
        fi
    else
        log_ok "ButterRepo already configured."
    fi

    log_info "Updating package lists..."
    sudo apt-get update -y 2>&1 | tee -a "${LOG_FILE}"
}

distro_setup() {
    configure_ubuntu_repos
}
