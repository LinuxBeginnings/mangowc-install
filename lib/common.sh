#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

export MANGO_DOTS_VERSION="0.0.2"

# Output formatting & colors
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    OK="$(tput setaf 2)[OK]$(tput sgr0)"
    ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
    NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
    INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
    WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
    CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
    MAGENTA="$(tput setaf 5)"
    YELLOW="$(tput setaf 3)"
    GREEN="$(tput setaf 2)"
    BLUE="$(tput setaf 4)"
    CYAN="$(tput setaf 6)"
    RESET="$(tput sgr0)"
else
    OK="[OK]"
    ERROR="[ERROR]"
    NOTE="[NOTE]"
    INFO="[INFO]"
    WARN="[WARN]"
    CAT="[ACTION]"
    MAGENTA=""
    YELLOW=""
    GREEN=""
    BLUE=""
    CYAN=""
    RESET=""
fi

# Logging configuration
LOG_DIR="${SCRIPT_DIR}/Install-Logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

log_info() {
    local msg="$*"
    echo -e "${INFO} ${msg}" | tee -a "${LOG_FILE}"
}

log_ok() {
    local msg="$*"
    echo -e "${OK} ${msg}" | tee -a "${LOG_FILE}"
}

log_warn() {
    local msg="$*"
    echo -e "${WARN} ${msg}" | tee -a "${LOG_FILE}"
}

log_err() {
    local msg="$*"
    echo -e "${ERROR} ${msg}" | tee -a "${LOG_FILE}" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" || "${DEBUG:-false}" == "true" ]]; then
        local msg="$*"
        echo -e "${CYAN}[DEBUG]${RESET} ${msg}" | tee -a "${LOG_FILE}"
    fi
}

# Preflight validation
preflight_checks() {
    log_info "Running preflight environment checks..."

    if [[ "$(id -u)" -eq 0 ]]; then
        log_err "Do not run this script as root. Run as a regular user with sudo access."
        exit 1
    fi

    if ! sudo -n true 2>/dev/null; then
        echo -e "${NOTE} Sudo privileges required. You may be prompted for your password."
        if ! sudo -v; then
            log_err "Failed to authenticate with sudo. Exiting."
            exit 1
        fi
    fi

    # Keep sudo credentials alive in the background
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
    SUDO_KEEP_ALIVE_PID=$!
    trap 'kill "${SUDO_KEEP_ALIVE_PID:-}" 2>/dev/null || true' EXIT

    log_ok "Preflight checks passed."
}

# Backup helper for directories and files
# Usage: backup_path "/path/to/target" "backup-suffix-or-name"
backup_path() {
    local target="$1"
    local custom_name="${2:-}"
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"

    if [[ -e "${target}" || -L "${target}" ]]; then
        local parent_dir
        parent_dir="$(dirname "${target}")"
        local base_name
        base_name="$(basename "${target}")"

        local backup_dest
        if [[ -n "${custom_name}" ]]; then
            backup_dest="${parent_dir}/${custom_name}-${timestamp}"
        else
            backup_dest="${parent_dir}/${base_name}-mangowc-${timestamp}"
        fi

        log_info "Backing up existing '${target}' -> '${backup_dest}'"
        mv "${target}" "${backup_dest}"
        log_ok "Backup created at: ${backup_dest}"
    else
        log_debug "No existing path at '${target}' to backup."
    fi
}

# Check and configure default rustup toolchain to ensure cargo works
check_rustup_cargo() {
    if command -v rustup >/dev/null 2>&1; then
        if ! command -v cargo >/dev/null 2>&1 || ! cargo --version >/dev/null 2>&1; then
            log_info "Configuring default Rust toolchain via 'rustup default stable' to finish Cargo installation..."
            rustup default stable 2>&1 | tee -a "${LOG_FILE}" || true
        fi

        if command -v cargo >/dev/null 2>&1 && cargo --version >/dev/null 2>&1; then
            log_ok "Cargo verified ($(cargo --version 2>/dev/null | head -n1))."
        else
            log_warn "Cargo is not functional. Please run 'rustup default stable' to finish setup."
        fi
    elif command -v cargo >/dev/null 2>&1; then
        log_ok "Cargo verified ($(cargo --version 2>/dev/null | head -n1))."
    fi
}
