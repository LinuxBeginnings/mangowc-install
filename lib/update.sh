#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

get_installed_noctalia_version() {
    if command -v noctalia >/dev/null 2>&1; then
        noctalia --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-zA-Z0-9.]+)?' | head -n1 || echo "unknown"
    else
        echo "not installed"
    fi
}

get_installed_greeter_version() {
    local bin=""
    if command -v noctalia-greeter >/dev/null 2>&1; then
        bin="$(command -v noctalia-greeter)"
    elif [[ -x /usr/local/bin/noctalia-greeter ]]; then
        bin="/usr/local/bin/noctalia-greeter"
    elif [[ -x /usr/bin/noctalia-greeter ]]; then
        bin="/usr/bin/noctalia-greeter"
    fi

    if [[ -n "${bin}" ]]; then
        "${bin}" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-zA-Z0-9.]+)?' | head -n1 || echo "unknown"
    else
        echo "not installed"
    fi
}

get_latest_noctalia_version() {
    local ver=""
    ver="$(curl -fsSL --max-time 5 "https://api.github.com/repos/noctalia-dev/noctalia/releases/latest" 2>/dev/null | grep -m1 '"tag_name":' | cut -d'"' -f4 | sed 's/^v//' || true)"
    if [[ -z "${ver}" ]]; then
        ver="$(git ls-remote --tags --refs https://github.com/noctalia-dev/noctalia.git 2>/dev/null | grep -v 'beta' | tail -n1 | sed 's#.*refs/tags/v\?##' || true)"
    fi
    echo "${ver:-unknown}"
}

get_latest_greeter_version() {
    local ver=""
    ver="$(curl -fsSL --max-time 5 "https://api.github.com/repos/noctalia-dev/noctalia-greeter/tags" 2>/dev/null | grep -m1 '"name":' | cut -d'"' -f4 | sed 's/^v//' || true)"
    if [[ -z "${ver}" ]]; then
        ver="$(git ls-remote --tags --refs https://github.com/noctalia-dev/noctalia-greeter.git 2>/dev/null | tail -n1 | sed 's#.*refs/tags/v\?##' || true)"
    fi
    echo "${ver:-unknown}"
}

is_newer_version() {
    local installed="$1"
    local latest="$2"
    if [[ -z "$installed" || "$installed" == "none" || "$installed" == "not installed" || "$installed" == "unknown" ]]; then
        return 0
    fi
    if [[ "$installed" == "$latest" || "$latest" == "unknown" ]]; then
        return 1
    fi
    local lowest
    lowest="$(printf '%s\n%s\n' "$installed" "$latest" | sort -V | head -n1)"
    if [[ "$lowest" != "$latest" ]]; then
        return 0
    fi
    return 1
}

upgrade_noctalia_components() {
    local upgrade_shell="$1"
    local upgrade_greeter="$2"

    case "${DETECTED_DISTRO:-}" in
        ubuntu|debian)
            if [[ "${upgrade_shell}" -eq 1 ]]; then
                if declare -f install_noctalia_shell >/dev/null 2>&1; then
                    install_noctalia_shell 1
                fi
            fi
            if [[ "${upgrade_greeter}" -eq 1 ]]; then
                if declare -f install_noctalia_greeter_pkg >/dev/null 2>&1; then
                    install_noctalia_greeter_pkg 1
                fi
            fi
            ;;
        arch)
            local aur_helper=""
            if declare -f get_aur_helper >/dev/null 2>&1; then
                aur_helper="$(get_aur_helper)"
            fi
            local pkgs=()
            [[ "${upgrade_shell}" -eq 1 ]] && pkgs+=("noctalia-shell")
            [[ "${upgrade_greeter}" -eq 1 ]] && pkgs+=("noctalia-greeter")
            if [[ ${#pkgs[@]} -gt 0 ]]; then
                if [[ -n "${aur_helper}" ]]; then
                    "${aur_helper}" -S --needed --noconfirm "${pkgs[@]}"
                else
                    log_warn "No AUR helper found to upgrade: ${pkgs[*]}"
                fi
            fi
            ;;
        fedora)
            local pkgs=()
            [[ "${upgrade_shell}" -eq 1 ]] && pkgs+=("noctalia")
            [[ "${upgrade_greeter}" -eq 1 ]] && pkgs+=("noctalia-greeter")
            if [[ ${#pkgs[@]} -gt 0 ]]; then
                sudo dnf upgrade -y "${pkgs[@]}"
            fi
            ;;
        *)
            log_warn "No automated upgrade routine for distro '${DETECTED_DISTRO:-unknown}'."
            ;;
    esac
}

check_and_update_noctalia() {
    log_info "Checking for Noctalia & Noctalia Greeter updates..."

    local installed_noctalia
    installed_noctalia="$(get_installed_noctalia_version)"
    local latest_noctalia
    latest_noctalia="$(get_latest_noctalia_version)"

    local installed_greeter
    installed_greeter="$(get_installed_greeter_version)"
    local latest_greeter
    latest_greeter="$(get_latest_greeter_version)"

    local status_noctalia="Up to date"
    local update_noctalia_avail=0
    if is_newer_version "${installed_noctalia}" "${latest_noctalia}"; then
        status_noctalia="Update available"
        update_noctalia_avail=1
    fi

    local status_greeter="Up to date"
    local update_greeter_avail=0
    if is_newer_version "${installed_greeter}" "${latest_greeter}"; then
        status_greeter="Update available"
        update_greeter_avail=1
    fi

    echo ""
    printf "%-20s %-20s %-20s %-20s\n" "Component" "Installed Version" "Updated Version" "Status"
    printf "%s\n" "--------------------------------------------------------------------------------"
    printf "%-20s %-20s %-20s %-20s\n" "Noctalia Shell" "${installed_noctalia}" "${latest_noctalia}" "${status_noctalia}"
    printf "%-20s %-20s %-20s %-20s\n" "Noctalia Greeter" "${installed_greeter}" "${latest_greeter}" "${status_greeter}"
    echo ""

    local prompt_msg="Would you like to upgrade? (Y/n): "
    if [[ "${update_noctalia_avail}" -eq 0 && "${update_greeter_avail}" -eq 0 ]]; then
        prompt_msg="Both components are up to date. Would you like to reinstall/rebuild? (y/N): "
    fi

    echo -ne "${CAT} ${prompt_msg}"
    read -r reply

    if [[ "${update_noctalia_avail}" -eq 0 && "${update_greeter_avail}" -eq 0 ]]; then
        case "${reply}" in
            [Yy]*)
                log_info "Reinstalling Noctalia components..."
                upgrade_noctalia_components 1 1
                log_ok "Reinstallation complete!"
                ;;
            *)
                log_info "No changes made."
                ;;
        esac
    else
        reply="${reply:-Y}"
        case "${reply}" in
            [Yy]*)
                log_info "Upgrading Noctalia components..."
                upgrade_noctalia_components "${update_noctalia_avail}" "${update_greeter_avail}"
                log_ok "Upgrade complete!"
                ;;
            *)
                log_info "Upgrade skipped."
                ;;
        esac
    fi
}
