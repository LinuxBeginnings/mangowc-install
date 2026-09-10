#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

configure_fedora_dnf() {
    log_info "Configuring DNF performance settings..."

    local dnf_conf="/etc/dnf/dnf.conf"
    if [[ ! -f "${dnf_conf}" ]]; then
        log_warn "${dnf_conf} not found. Skipping DNF optimization."
        return 0
    fi

    if grep -q "^max_parallel_downloads" "${dnf_conf}" 2>/dev/null && \
       grep -q "^defaultyes=True" "${dnf_conf}" 2>/dev/null; then
        log_ok "DNF already configured for parallel downloads. Skipping."
        return 0
    fi

    sudo cp "${dnf_conf}" "${dnf_conf}.bak.$(date +%Y%m%d%H%M%S)"

    sudo python3 - <<'PYEOF'
import configparser
conf_path = "/etc/dnf/dnf.conf"
config = configparser.ConfigParser()
config.optionxform = str
config.read(conf_path)

if not config.has_section("main"):
    config.add_section("main")

updates = {
    "installonly_limit": "3",
    "max_parallel_downloads": "10",
    "defaultyes": "True"
}

for k, v in updates.items():
    config.set("main", k, v)

with open(conf_path, "w") as f:
    config.write(f)
PYEOF

    log_ok "DNF configuration updated with parallel downloads."
}

add_fedora_repositories() {
    log_info "Configuring Fedora repositories (RPM Fusion & Terra)..."

    # RPM Fusion Free & Non-Free
    if rpm -q rpmfusion-free-release &>/dev/null && rpm -q rpmfusion-nonfree-release &>/dev/null; then
        log_ok "RPM Fusion repositories already active."
    else
        log_info "Installing RPM Fusion..."
        local fedora_ver
        fedora_ver="$(rpm -E %fedora)"
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm" \
            2>&1 | tee -a "${LOG_FILE}" || log_warn "RPM Fusion installation encountered a warning."
    fi

    # Terra Repository (provides mangowm and noctalia builds for Fedora)
    if rpm -q terra-release &>/dev/null; then
        log_ok "Terra repository already active."
    else
        log_info "Installing Terra repository..."
        sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release -y \
            2>&1 | tee -a "${LOG_FILE}" || log_warn "Terra repository installation returned a warning."
    fi

    log_info "Refreshing package metadata..."
    sudo dnf check-update || true
    log_ok "Fedora repositories initialized."
}

distro_setup() {
    configure_fedora_dnf
    add_fedora_repositories
}
