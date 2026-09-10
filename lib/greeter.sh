#!/usr/bin/env bash
# ==================================================
#  MamgoDOTS - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

# Check if greetd and noctalia-greeter are available
check_greeter_binaries() {
    local missing=0
    if ! command -v greetd >/dev/null 2>&1; then
        log_warn "greetd binary is not found in PATH."
        missing=1
    fi

    if ! command -v noctalia-greeter-session >/dev/null 2>&1 && [[ ! -x /usr/local/bin/noctalia-greeter-session && ! -x /usr/bin/noctalia-greeter-session ]]; then
        log_warn "noctalia-greeter-session binary is not found."
        missing=1
    fi

    return $missing
}

# Resolve greeter user (usually 'greeter' or 'greetd')
resolve_greetd_user() {
    if id -u greeter >/dev/null 2>&1; then
        echo "greeter"
    elif id -u greetd >/dev/null 2>&1; then
        echo "greetd"
    else
        echo "greeter"
    fi
}

install_noctalia_greeter() {
    log_info "Configuring greetd with noctalia-greeter..."

    # Ensure greetd directory exists
    sudo mkdir -p /etc/greetd

    # Backup existing /etc/greetd/config.toml if present
    if [[ -f /etc/greetd/config.toml ]]; then
        local timestamp
        timestamp="$(date +%Y%m%d-%H%M%S)"
        log_info "Backing up existing /etc/greetd/config.toml -> /etc/greetd/config.toml.bak.${timestamp}"
        sudo cp -p /etc/greetd/config.toml "/etc/greetd/config.toml.bak.${timestamp}"
    fi

    local greeter_user
    greeter_user="$(resolve_greetd_user)"
    log_debug "Resolved greeter user: ${greeter_user}"

    # Determine exact path to noctalia-greeter-session
    local session_bin=""
    if command -v noctalia-greeter-session >/dev/null 2>&1; then
        session_bin="$(command -v noctalia-greeter-session)"
    elif [[ -x /usr/local/bin/noctalia-greeter-session ]]; then
        session_bin="/usr/local/bin/noctalia-greeter-session"
    else
        session_bin="/usr/bin/noctalia-greeter-session"
    fi

    # Ensure greeter state directory exists
    local state_dir="/var/lib/noctalia-greeter"
    sudo mkdir -p "${state_dir}"
    if id -u "${greeter_user}" >/dev/null 2>&1; then
        sudo chown -R "${greeter_user}:${greeter_user}" "${state_dir}" || true
        sudo chmod 0750 "${state_dir}" || true
    fi

    # Write greetd configuration
    log_info "Writing /etc/greetd/config.toml pointing to ${session_bin}..."
    sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "${session_bin} -- --session mango"
user = "${greeter_user}"
EOF

    log_ok "/etc/greetd/config.toml updated successfully."

    # Enable greetd systemd service if systemd is active
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        log_info "Enabling greetd.service via systemctl..."
        sudo systemctl enable greetd.service 2>&1 | tee -a "${LOG_FILE}" || log_warn "Failed to enable greetd.service."
        log_ok "greetd.service enabled."
    fi

    log_ok "Noctalia greeter + greetd configuration complete."
}

remove_noctalia_greeter() {
    log_info "Removing / restoring greetd & noctalia-greeter configuration..."

    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        log_info "Disabling greetd.service..."
        sudo systemctl disable greetd.service 2>&1 | tee -a "${LOG_FILE}" || true
    fi

    # Look for most recent backup of /etc/greetd/config.toml
    local latest_bak
    latest_bak="$(sudo find /etc/greetd -maxdepth 1 -name 'config.toml.bak.*' 2>/dev/null | sort -V | tail -n 1 || true)"

    if [[ -n "${latest_bak}" && -f "${latest_bak}" ]]; then
        log_info "Restoring previous configuration from ${latest_bak}..."
        sudo cp -p "${latest_bak}" /etc/greetd/config.toml
        log_ok "Restored /etc/greetd/config.toml from ${latest_bak}."
    elif [[ -f /etc/greetd/config.toml ]]; then
        log_info "No backup found. Removing /etc/greetd/config.toml..."
        sudo rm -f /etc/greetd/config.toml
        log_ok "Removed /etc/greetd/config.toml."
    fi

    log_ok "Noctalia greeter setup removed successfully."
}

prompt_greeter_action() {
    echo ""
    echo -e "${INFO} Noctalia Greeter (Login Manager Setup):"
    echo "  1) Install / Configure noctalia-greeter with greetd"
    echo "  2) Remove / Restore previous display manager / greetd config"
    echo "  3) Skip greeter configuration (default)"
    echo -n "${CAT} Enter your choice [1-3] (default 3): "
    read -r choice

    case "${choice}" in
        1)
            install_noctalia_greeter
            ;;
        2)
            remove_noctalia_greeter
            ;;
        3|"")
            log_info "Skipping greeter configuration."
            ;;
        *)
            log_warn "Invalid selection. Skipping greeter configuration."
            ;;
    esac
}
