#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

detect_distro() {
    log_info "Detecting Linux distribution..."

    if [[ ! -f /etc/os-release ]]; then
        log_err "Cannot find /etc/os-release to detect operating system."
        exit 1
    fi

    local os_id="" os_like="" os_version="" os_name=""
    os_id="$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')"
    os_like="$(grep -E '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '"' || true)"
    os_version="$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' || true)"
    os_name="$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"' || true)"

    log_debug "Raw os-release: ID=${os_id}, ID_LIKE=${os_like}, VERSION_ID=${os_version}"

    local matched_distro=""

    case "${os_id}" in
        fedora)
            matched_distro="fedora"
            ;;
        arch|endeavouros|cachyos|manjaro)
            matched_distro="arch"
            ;;
        debian)
            matched_distro="debian"
            ;;
        ubuntu|pop|linuxmint)
            matched_distro="ubuntu"
            ;;
        opensuse*|suse)
            matched_distro="opensuse"
            ;;
        *)
            if [[ "${os_like}" =~ fedora|rhel ]]; then
                matched_distro="fedora"
            elif [[ "${os_like}" =~ arch ]]; then
                matched_distro="arch"
            elif [[ "${os_like}" =~ debian ]]; then
                matched_distro="debian"
            else
                matched_distro="unsupported"
            fi
            ;;
    esac

    export DETECTED_DISTRO="${matched_distro}"
    export DETECTED_OS_NAME="${os_name:-${os_id}}"
    export DETECTED_VERSION_ID="${os_version}"

    if [[ "${matched_distro}" == "unsupported" ]]; then
        log_warn "Distribution '${os_name}' (ID: ${os_id}) is not directly supported."
        log_warn "Supported distros currently include: Fedora (with Arch/Debian extensible)."
    else
        log_ok "Detected supported distribution: ${DETECTED_OS_NAME} (${DETECTED_DISTRO})"
    fi
}

is_virtual_machine() {
    if hostnamectl 2>/dev/null | grep -qi 'Chassis:.*vm'; then
        return 0
    fi
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt
        virt="$(systemd-detect-virt 2>/dev/null || true)"
        if [[ -n "${virt}" && "${virt}" != "none" ]]; then
            return 0
        fi
    fi
    return 1
}

setup_vm_environment() {
    log_info "Virtual Machine detected. Setting up VM optimizations..."

    # Install qemu-guest-agent / utils
    local qemu_pkg="qemu-guest-agent"
    if declare -f pkg_install >/dev/null 2>&1; then
        pkg_install "${qemu_pkg}" || log_warn "Could not install ${qemu_pkg}."
    fi

    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        sudo systemctl enable --now qemu-guest-agent.service 2>&1 | tee -a "${LOG_FILE}" || true
    fi

    # Fix upside-down mouse pointer in Wayland VMs
    if ! grep -q "^WLR_NO_HARDWARE_CURSORS=" /etc/environment 2>/dev/null; then
        log_info "Configuring WLR_NO_HARDWARE_CURSORS=1 in /etc/environment (fixes upside-down pointer)..."
        echo "WLR_NO_HARDWARE_CURSORS=1" | sudo tee -a /etc/environment >/dev/null
        log_ok "Added WLR_NO_HARDWARE_CURSORS=1 to /etc/environment."
    else
        log_ok "WLR_NO_HARDWARE_CURSORS=1 already set in /etc/environment."
    fi

    export WLR_NO_HARDWARE_CURSORS=1
}
