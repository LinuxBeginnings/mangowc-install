#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

# Check if noctalia-greeter-session is installed
is_noctalia_greeter_installed() {
    command -v noctalia-greeter-session >/dev/null 2>&1 || \
    [[ -x /usr/local/bin/noctalia-greeter-session || -x /usr/bin/noctalia-greeter-session ]]
}

# Check if greetd and noctalia-greeter are available
check_greeter_binaries() {
    local missing=0
    if ! command -v greetd >/dev/null 2>&1; then
        log_warn "greetd binary is not found in PATH."
        missing=1
    fi

    if ! is_noctalia_greeter_installed; then
        log_warn "noctalia-greeter-session binary is not found."
        missing=1
    fi

    return $missing
}

# Resolve greeter user (usually 'greetd' or 'greeter')
resolve_greetd_user() {
    if id -u greetd >/dev/null 2>&1; then
        echo "greetd"
    elif id -u greeter >/dev/null 2>&1; then
        echo "greeter"
    else
        sudo useradd -r -s /usr/bin/nologin -d /var/lib/noctalia-greeter greeter 2>/dev/null || true
        echo "greeter"
    fi
}

install_noctalia_greeter() {
    log_info "Configuring greetd with noctalia-greeter..."

    # Ensure greetd and noctalia-greeter packages are installed first
    if ! command -v greetd >/dev/null 2>&1 || ! is_noctalia_greeter_installed; then
        log_info "Required greeter packages missing. Installing..."
        if declare -f install_greeter_packages >/dev/null 2>&1; then
            install_greeter_packages || true
        fi
    fi

    # Explicitly verify noctalia-greeter was installed
    if ! is_noctalia_greeter_installed; then
        log_err "noctalia-greeter ('noctalia-greeter-session') is NOT installed."
        log_warn "greetd configuration aborted to protect your existing display manager and prevent login lockout."
        return 1
    fi

    if ! command -v greetd >/dev/null 2>&1; then
        log_err "greetd binary is NOT installed or not found in PATH."
        log_warn "greetd configuration aborted."
        return 1
    fi

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
    elif [[ -x /usr/bin/noctalia-greeter-session ]]; then
        session_bin="/usr/bin/noctalia-greeter-session"
    fi

    if [[ -z "${session_bin}" ]]; then
        log_err "Could not resolve valid executable path for noctalia-greeter-session."
        return 1
    fi

    # Detect exact desktop session name (e.g. "Mango")
    local session_name="Mango"
    if command -v noctalia-greeter >/dev/null 2>&1; then
        local detected_session
        detected_session="$(noctalia-greeter sessions 2>/dev/null | grep -iE '^mango$' | head -n 1 || true)"
        if [[ -n "${detected_session}" ]]; then
            session_name="${detected_session}"
        fi
    fi

    # Ensure greeter state directory exists
    local state_dir="/var/lib/noctalia-greeter"
    sudo mkdir -p "${state_dir}"
    if id -u "${greeter_user}" >/dev/null 2>&1; then
        sudo usermod -a -G video,input "${greeter_user}" 2>/dev/null || true
        sudo chown -R "${greeter_user}:${greeter_user}" "${state_dir}" || true
        sudo chmod 0750 "${state_dir}" || true
    fi

    local target_vt=1
    if [[ "${DETECTED_DISTRO:-}" =~ debian|ubuntu ]]; then
        target_vt=7
    fi

    # Write greetd configuration
    log_info "Writing /etc/greetd/config.toml pointing to ${session_bin} (${session_name}) on vt ${target_vt}..."
    sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = ${target_vt}

[default_session]
command = "${session_bin} -- --session ${session_name}"
user = "${greeter_user}"
EOF

    log_ok "/etc/greetd/config.toml updated successfully."

    # Configure greetd service environment override and PAM
    sudo mkdir -p /etc/systemd/system/greetd.service.d
    local hw_cursor_env=""
    if declare -f needs_software_cursors >/dev/null 2>&1 && needs_software_cursors; then
        hw_cursor_env="Environment=\"WLR_NO_HARDWARE_CURSORS=1\""
    fi
    sudo tee /etc/systemd/system/greetd.service.d/override.conf >/dev/null <<EOF
[Service]
EnvironmentFile=-/etc/environment
${hw_cursor_env}
EOF

    if [[ -f /etc/pam.d/greetd ]]; then
        sudo tee /etc/pam.d/greetd >/dev/null <<'EOF'
#%PAM-1.0
-auth       optional    pam_gnome_keyring.so
@include common-auth
-account    optional    pam_gnome_keyring.so
@include common-account
session     required    pam_env.so readenv=1
session     required    pam_env.so readenv=1 envfile=/etc/default/locale
@include common-session
-session    optional    pam_gnome_keyring.so auto_start
EOF
    fi

    if [[ -f /etc/pam.d/greetd-greeter ]]; then
        sudo tee /etc/pam.d/greetd-greeter >/dev/null <<'EOF'
#%PAM-1.0
session     required    pam_env.so readenv=1
session     required    pam_env.so readenv=1 envfile=/etc/default/locale
@include common-auth
@include common-account
@include common-session
EOF
    fi

    # Disable competing display managers (lightdm, sddm, gdm, lxdm)
    # Note: Do NOT use --now here, as stopping the active display manager immediately
    # kills the current session and terminates the running install script.
    for dm in lightdm sddm gdm lxdm; do
        if systemctl list-unit-files "${dm}.service" 2>/dev/null | grep -q "${dm}"; then
            if systemctl is-enabled "${dm}.service" &>/dev/null; then
                log_info "Disabling competing display manager: ${dm}.service..."
                sudo systemctl disable "${dm}.service" 2>&1 | tee -a "${LOG_FILE}" || true
            fi
        fi
    done
    sudo systemctl disable display-manager.service 2>/dev/null || true

    # Configure Polkit rules for Noctalia greeter appearance sync
    if [[ -d /etc/polkit-1/rules.d ]]; then
        log_info "Installing Polkit rule for Noctalia greeter appearance sync..."
        sudo tee /etc/polkit-1/rules.d/50-noctalia-greeter.rules >/dev/null <<'POLKIT_RULE'
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel") || subject.isInGroup("sudo")) {
        if (action.id == "org.noctalia.greeter.sync-appearance" ||
            action.id == "org.freedesktop.systemd1.manage-units") {
            return polkit.Result.YES;
        }
    }
});
POLKIT_RULE
        log_ok "Polkit rule installed at /etc/polkit-1/rules.d/50-noctalia-greeter.rules"
    fi

    # Enable greetd systemd service if systemd is active
    # Note: Never use --now with greetd during install to avoid closing the active session prematurely.
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        log_info "Enabling greetd.service via systemctl..."
        if sudo systemctl enable --force greetd.service 2>&1 | tee -a "${LOG_FILE}"; then
            sudo systemctl set-default graphical.target 2>&1 | tee -a "${LOG_FILE}" || true
            log_ok "greetd.service enabled successfully as default display manager (takes effect on reboot)."
        else
            log_err "Failed to enable greetd.service."
            return 1
        fi
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

    # Remove Polkit rule if installed
    if [[ -f /etc/polkit-1/rules.d/50-noctalia-greeter.rules ]]; then
        sudo rm -f /etc/polkit-1/rules.d/50-noctalia-greeter.rules
        log_ok "Removed /etc/polkit-1/rules.d/50-noctalia-greeter.rules."
    fi

    if [[ -n "${latest_bak}" && -f "${latest_bak}" ]]; then
        log_info "Restoring previous configuration from ${latest_bak}..."
        sudo cp -p "${latest_bak}" /etc/greetd/config.toml
        log_ok "Restored /etc/greetd/config.toml from ${latest_bak}."
    elif [[ -f /etc/greetd/config.toml ]]; then
        log_info "No backup found. Removing /etc/greetd/config.toml..."
        sudo rm -f /etc/greetd/config.toml
        log_ok "Removed /etc/greetd/config.toml."
    fi

    # Restore alternative display manager if present
    for dm in lightdm sddm gdm; do
        if systemctl list-unit-files "${dm}.service" 2>/dev/null | grep -q "${dm}"; then
            log_info "Re-enabling ${dm}.service..."
            sudo systemctl enable "${dm}.service" 2>&1 | tee -a "${LOG_FILE}" || true
            break
        fi
    done

    log_ok "Noctalia greeter setup removed successfully."
}

prompt_greeter_action() {
    echo ""
    echo -e "${INFO} Noctalia Greeter (Login Manager Setup):"
    if is_noctalia_greeter_installed; then
        echo -e "  Current status: ${GREEN}noctalia-greeter is installed${RC}"
    else
        echo -e "  Current status: ${YELLOW}noctalia-greeter is NOT installed${RC}"
    fi
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
