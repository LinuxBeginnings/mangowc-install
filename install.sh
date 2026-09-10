#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

export MANGO_DOTS_VERSION="0.0.1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

# Default option flags
DEBUG=0
GREETER_ACTION="prompt"   # prompt, install, remove, skip
DOWNLOAD_WALLPAPERS=1    # 1=prompt, 0=skip

print_usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  -d, --debug             Enable verbose debug output and detailed logging
  --install-greeter       Install and configure noctalia-greeter with greetd
  --remove-greeter        Remove / restore previous greeter configuration
  --skip-greeter          Skip greeter configuration entirely
  --no-wallpapers         Skip wallpaper download prompt
  -h, --help              Show this help message and exit

Examples:
  ./install.sh                      # Standard interactive install
  ./install.sh --debug              # Run with debug logging enabled
  ./install.sh --install-greeter    # Install core desktop and configure greetd
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug)
            DEBUG=1
            export DEBUG
            ;;
        --install-greeter)
            GREETER_ACTION="install"
            ;;
        --remove-greeter)
            GREETER_ACTION="remove"
            ;;
        --skip-greeter)
            GREETER_ACTION="skip"
            ;;
        --no-wallpapers)
            DOWNLOAD_WALLPAPERS=0
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
    shift
done

# Source shared libraries
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/detect.sh
source "${SCRIPT_DIR}/lib/detect.sh"
# shellcheck source=lib/greeter.sh
source "${SCRIPT_DIR}/lib/greeter.sh"
# shellcheck source=lib/wallpapers.sh
source "${SCRIPT_DIR}/lib/wallpapers.sh"

if [[ "${DEBUG}" == "1" ]]; then
    set -x
    log_debug "Debug mode enabled."
fi

print_banner() {
    echo -e "${MAGENTA}"
    cat <<'BANNER'
    __  ______    _   __________  _       ______
   /  |/  /   |  / | / / ____/ / | |     / / ____/
  / /|_/ / /| | /  |/ / / __/ /  | | /| / / /     
 / /  / / ___ |/ /|  / /_/ / /___| |/ |/ / /___   
/_/  /_/_/  |_/_/ |_/\____/_____/|__/|__/\____/   
   MangoWC - (2026) | LinuxBeginnings
BANNER
    echo -e "${RESET}"
}

deploy_dotfiles() {
    log_info "Deploying configurations to ~/.config/..."

    local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
    mkdir -p "${config_home}"

    # 1. Modular application configs: kitty, ghostty, btop, fastfetch, yazi
    local app_configs=(
        "kitty"
        "ghostty"
        "btop"
        "fastfetch"
        "yazi"
    )

    for app in "${app_configs[@]}"; do
        local src_dir="${SCRIPT_DIR}/configs/${app}"
        local dst_dir="${config_home}/${app}"

        if [[ -d "${src_dir}" ]]; then
            if [[ -d "${dst_dir}" && ! -L "${dst_dir}" ]]; then
                backup_path "${dst_dir}" "${app}-mangowc"
            fi
            mkdir -p "${dst_dir}"
            cp -rf "${src_dir}/"* "${dst_dir}/"
            log_ok "Deployed ${app} config to ${dst_dir}"
        fi
    done

    # 2. Mangowc compositor config
    local mangowc_dst="${config_home}/mangowc"
    if [[ -d "${mangowc_dst}" && ! -L "${mangowc_dst}" ]]; then
        backup_path "${mangowc_dst}" "mangowc-backup"
    fi

    # Check for legacy ~/.config/mango directory
    local mango_legacy="${config_home}/mango"
    if [[ -e "${mango_legacy}" && ! -L "${mango_legacy}" ]]; then
        backup_path "${mango_legacy}" "mango-legacy-backup"
    elif [[ -L "${mango_legacy}" ]]; then
        rm -f "${mango_legacy}"
    fi

    mkdir -p "${mangowc_dst}"
    cp -rf "${SCRIPT_DIR}/configs/mangowc/"* "${mangowc_dst}/"

    # Sync default layout from env.conf to tag.conf
    local def_layout
    def_layout="$(grep -E '^env=MANGO_DEFAULT_LAYOUT,' "${mangowc_dst}/env.conf" | cut -d',' -f2 | tr -d ' ' || echo "scroller")"
    if [[ -n "${def_layout}" ]]; then
        sed -i -E "s/layout_name:[a-zA-Z0-9_]+/layout_name:${def_layout}/g" "${mangowc_dst}/tag.conf"
    fi

    chmod +x "${mangowc_dst}/autostart.sh" 2>/dev/null || true
    chmod +x "${mangowc_dst}/bin/"* 2>/dev/null || true
    log_ok "Deployed mangowc dotfiles to ${mangowc_dst}"

    # Create relative symlink ~/.config/mango -> mangowc for upstream mango compatibility
    ln -sfn "mangowc" "${mango_legacy}"
    log_ok "Linked ${mango_legacy} -> mangowc"
}

main() {
    print_banner
    preflight_checks
    detect_distro

    # Check for Virtual Machine and apply cursor & guest optimizations
    if is_virtual_machine; then
        setup_vm_environment
    fi

    local distro_dir="${SCRIPT_DIR}/distros/${DETECTED_DISTRO}"
    if [[ ! -d "${distro_dir}" ]]; then
        log_err "Configuration directory for distro '${DETECTED_DISTRO}' not found at ${distro_dir}."
        exit 1
    fi

    # Load distro-specific modules
    if [[ -f "${distro_dir}/setup.sh" ]]; then
        # shellcheck source=/dev/null
        source "${distro_dir}/setup.sh"
        distro_setup
    fi

    if [[ -f "${distro_dir}/packages.sh" ]]; then
        # shellcheck source=/dev/null
        source "${distro_dir}/packages.sh"
        install_core_packages
    fi

    # Deploy configs and backups
    deploy_dotfiles

    # Greeter setup
    case "${GREETER_ACTION}" in
        install)
            if declare -f install_greeter_packages >/dev/null 2>&1; then
                install_greeter_packages
            fi
            install_noctalia_greeter
            ;;
        remove)
            remove_noctalia_greeter
            ;;
        prompt)
            prompt_greeter_action
            ;;
        skip)
            log_info "Skipping greeter configuration per flag."
            ;;
    esac

    # Wallpaper download
    if [[ "${DOWNLOAD_WALLPAPERS}" -eq 1 ]]; then
        prompt_wallpapers
    else
        log_info "Skipping wallpaper download per flag."
    fi

    echo ""
    log_ok "Installation complete!"
    log_info "Mango window manager dotfiles are installed at: ${HOME}/.config/mangowc"
    log_info "Fastfetch config installed at: ${HOME}/.config/fastfetch/config.jsonc"
    log_info "To start Mango, log out and select Mango from your display manager, or run 'mango' from TTY."
    echo ""
}

main "$@"
