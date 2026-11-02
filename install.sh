#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

export MANGO_DOTS_VERSION="0.2.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

# Default option flags
DEBUG=0
GREETER_ACTION="prompt"   # prompt, install, remove, skip
DOWNLOAD_WALLPAPERS=1    # 1=prompt, 0=skip
ACTION="install"         # install, update-noctalia, deps
DRY_RUN=0                # 1=report planned changes and exit without touching the system

print_usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  -d, --debug             Enable verbose debug output and detailed logging
  -u, --uninstall         Uninstall MangoWC, Noctalia, and restore previous configuration
  --install-greeter       Install and configure noctalia-greeter with greetd
  --remove-greeter        Remove / restore previous greeter configuration
  --skip-greeter          Skip greeter configuration entirely
  --no-wallpapers         Skip wallpaper download prompt
  --update-noctalia       Check for Noctalia and Noctalia Greeter updates and prompt to upgrade
  --deps                  Install missing dependencies/packages only (e.g. flatpak, gpu-screen-recorder) without redeploying configs
  --dry-run               Report what would be installed or changed, then exit without touching the system
  -h, --help              Show this help message and exit

Examples:
  ./install.sh                      # Standard interactive install
  ./install.sh --debug              # Run with debug logging enabled
  ./install.sh --uninstall          # Complete uninstallation and cleanup
  ./install.sh --install-greeter    # Install core desktop and configure greetd
  ./install.sh --deps               # Install any missing packages (flatpak, gpu-screen-recorder) only
  ./install.sh --dry-run            # Show what would change, then exit without modifying anything
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug)
            DEBUG=1
            export DEBUG
            ;;
        -u|--uninstall)
            ACTION="uninstall"
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
        --update-noctalia)
            ACTION="update-noctalia"
            ;;
        --deps)
            ACTION="deps"
            ;;
        --dry-run)
            DRY_RUN=1
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
# shellcheck source=lib/update.sh
source "${SCRIPT_DIR}/lib/update.sh"

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
        "noctalia"
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

    # Remove pre-0.18 conf files: mango loads config.conf before config.toml
    rm -f "${mangowc_dst}"/{config,bind,env,monitor,tag,rule,noctalia}.conf

    # Sync default layout from env.toml to tag.toml
    local def_layout
    def_layout="$(grep -E '^"?MANGO_DEFAULT_LAYOUT"?[[:space:]]*=' "${mangowc_dst}/env.toml" 2>/dev/null | cut -d'=' -f2 | tr -d ' \"' || echo "dwindle")"
    if [[ -n "${def_layout}" ]]; then
        sed -i -E "s/^layout_name = \"[a-zA-Z0-9_]+\"/layout_name = \"${def_layout}\"/g" "${mangowc_dst}/tag.toml"
    fi

    chmod +x "${mangowc_dst}/autostart.sh" 2>/dev/null || true
    chmod +x "${mangowc_dst}/bin/"* 2>/dev/null || true
    log_ok "Deployed mangowc dotfiles to ${mangowc_dst}"

    # Create relative symlink ~/.config/mango -> mangowc for upstream mango compatibility
    ln -sfn "mangowc" "${mango_legacy}"
    log_ok "Linked ${mango_legacy} -> mangowc"
}

remove_dotfiles() {
    log_info "Removing deployed configurations from ~/.config/..."
    local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"

    # Remove mangowc and legacy mango symlink
    if [[ -L "${config_home}/mango" ]]; then
        rm -f "${config_home}/mango"
        log_ok "Removed ${config_home}/mango symlink."
    elif [[ -d "${config_home}/mango" ]]; then
        rm -rf "${config_home}/mango"
        log_ok "Removed ${config_home}/mango directory."
    fi

    if [[ -d "${config_home}/mangowc" ]]; then
        rm -rf "${config_home}/mangowc"
        log_ok "Removed ${config_home}/mangowc."
    fi

    restore_latest_backup "${config_home}/mangowc" "mangowc-backup" || true
    restore_latest_backup "${config_home}/mango" "mango-legacy-backup" || true

    # Remove or restore application configs deployed by MangoWC
    local app_configs=("noctalia" "kitty" "ghostty" "btop" "fastfetch" "yazi")
    for app in "${app_configs[@]}"; do
        if restore_latest_backup "${config_home}/${app}" "${app}-mangowc"; then
            :
        else
            if [[ -d "${config_home}/${app}" ]]; then
                if [[ "${app}" == "noctalia" ]]; then
                    rm -rf "${config_home}/noctalia"
                    log_ok "Removed ${config_home}/noctalia."
                fi
            fi
        fi
    done
}

report_dry_run_plan() {
    local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
    local mangowc_dst="${config_home}/mangowc"
    local app app_configs=(kitty ghostty btop fastfetch yazi noctalia)
    local src_dir dst_dir def_layout

    echo ""
    log_info "Dry run: no changes will be made to this system."

    case "${ACTION}" in
        uninstall)
            log_info "Action: uninstall mangowc + noctalia, restore the previous display manager and dotfile backups."
            log_ok "Dry run complete; nothing was changed."
            exit 0
            ;;
        update-noctalia)
            log_info "Action: compare installed and latest Noctalia / Noctalia Greeter releases, then prompt to upgrade."
            log_ok "Dry run complete; nothing was changed."
            exit 0
            ;;
    esac

    log_info "Detected: ${DETECTED_OS_NAME} (${DETECTED_DISTRO}${DETECTED_CODENAME:+, ${DETECTED_CODENAME}})"

    if [[ "${ACTION}" == "deps" ]]; then
        log_info "Action: install missing packages only; dotfiles would be left untouched."
    else
        log_info "Action: full install."
    fi

    log_info "Packages: would run distros/${DETECTED_DISTRO}/setup.sh and install_core_packages from distros/${DETECTED_DISTRO}/packages.sh."

    local component
    for component in mango noctalia quickshell; do
        if command -v "${component}" >/dev/null 2>&1; then
            log_info "Component ${component}: already present at $(command -v "${component}")."
        else
            log_info "Component ${component}: not installed, would be installed."
        fi
    done

    if is_virtual_machine; then
        log_info "Virtual machine detected: would install qemu-guest-agent and apply the VM cursor / Bluetooth tweaks."
    fi

    if [[ "${ACTION}" != "deps" ]]; then
        log_info "Config deployment:"
        for app in "${app_configs[@]}"; do
            src_dir="${SCRIPT_DIR}/configs/${app}"
            dst_dir="${config_home}/${app}"
            [[ -d "${src_dir}" ]] || continue
            if [[ -d "${dst_dir}" && ! -L "${dst_dir}" ]]; then
                log_info "  ${app}: back up ${dst_dir}, then deploy"
            else
                log_info "  ${app}: deploy to ${dst_dir}"
            fi
        done

        if [[ -d "${mangowc_dst}" && ! -L "${mangowc_dst}" ]]; then
            log_info "  mangowc: back up ${mangowc_dst}, then deploy the TOML config"
        else
            log_info "  mangowc: deploy the TOML config to ${mangowc_dst}"
        fi

        if compgen -G "${mangowc_dst}/*.conf" >/dev/null 2>&1; then
            log_info "  mangowc: stale *.conf files would be removed (mango prefers config.conf)"
        fi

        def_layout="$(grep -E '^"?MANGO_DEFAULT_LAYOUT"?[[:space:]]*=' "${SCRIPT_DIR}/configs/mangowc/env.toml" 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || true)"
        log_info "  layouts: all tag rules would be set to '${def_layout:-dwindle}'"
        log_info "  symlink: ${config_home}/mango -> mangowc"

        case "${GREETER_ACTION}" in
            install) log_info "Greeter: would install and configure greetd + noctalia-greeter." ;;
            remove)  log_info "Greeter: would remove the noctalia-greeter configuration." ;;
            skip)    log_info "Greeter: skipped per flag." ;;
            *)       log_info "Greeter: would prompt (install / remove / skip)." ;;
        esac

        if [[ "${DOWNLOAD_WALLPAPERS}" -eq 1 ]]; then
            log_info "Wallpapers: would prompt to download the wallpaper bank."
        else
            log_info "Wallpapers: skipped per flag."
        fi
    fi

    echo ""
    log_ok "Dry run complete; nothing was changed."
}

main() {
    print_banner
    if [[ "${DRY_RUN}" == "1" ]]; then
        log_info "Dry run: skipping sudo preflight checks."
    else
        preflight_checks
    fi
    detect_distro

    local distro_dir="${SCRIPT_DIR}/distros/${DETECTED_DISTRO}"
    if [[ ! -d "${distro_dir}" ]]; then
        log_err "Configuration directory for distro '${DETECTED_DISTRO}' not found at ${distro_dir}."
        exit 1
    fi

    # Load distro-specific modules
    if [[ -f "${distro_dir}/setup.sh" ]]; then
        # shellcheck source=/dev/null
        source "${distro_dir}/setup.sh"
    fi

    if [[ -f "${distro_dir}/packages.sh" ]]; then
        # shellcheck source=/dev/null
        source "${distro_dir}/packages.sh"
    fi

    if [[ "${DRY_RUN}" == "1" ]]; then
        report_dry_run_plan
        exit 0
    fi

    # Gentoo compatibility notice and confirmation check
    if [[ "${DETECTED_DISTRO}" == "gentoo" && "${ACTION}" != "uninstall" && "${ACTION}" != "update-noctalia" ]]; then
        if declare -f gentoo_compatibility_warning >/dev/null 2>&1; then
            gentoo_compatibility_warning
        fi
    fi

    # Check for Virtual Machine and apply cursor & guest optimizations
    if is_virtual_machine; then
        setup_vm_environment
    fi

    if [[ "${ACTION}" == "uninstall" ]]; then
        echo ""
        echo -e "${WARN} You are about to uninstall MangoWC and Noctalia from ${DETECTED_OS_NAME}."
        echo -e "${WARN} This will remove the compositor, shell, greeter configuration, and deployed dotfiles."
        echo -n "${CAT} Are you sure you want to proceed? (y/N): "
        read -r confirm
        case "${confirm}" in
            [Yy]*)
                log_info "Proceeding with uninstallation..."
                ;;
            *)
                log_info "Uninstallation aborted."
                exit 0
                ;;
        esac

        # 1. Restore/remove greeter setup if present
        remove_noctalia_greeter

        # 2. Run distro-specific package/binary uninstallation
        if declare -f uninstall_packages >/dev/null 2>&1; then
            uninstall_packages
        fi

        # 3. Clean up deployed dotfiles and restore prior backups
        remove_dotfiles

        echo ""
        log_ok "MangoWC and Noctalia uninstallation complete."
        exit 0
    fi

    if [[ "${ACTION}" == "update-noctalia" ]]; then
        check_and_update_noctalia
        exit 0
    fi

    if declare -f distro_setup >/dev/null 2>&1; then
        distro_setup
    fi

    # Presence checks before attempting to install
    log_info "Verifying presence of core components before installation..."
    if command -v mango >/dev/null 2>&1 || command -v mangowc >/dev/null 2>&1; then
        local installed_mango
        installed_mango="$(command -v mango 2>/dev/null || command -v mangowc)"
        log_ok "Mango compositor already present at ${installed_mango}."
    else
        log_info "Mango compositor not found. It will be installed."
    fi

    if command -v noctalia >/dev/null 2>&1; then
        log_ok "Noctalia desktop shell already present at $(command -v noctalia)."
    else
        log_info "Noctalia desktop shell not found. It will be installed."
    fi

    if command -v quickshell >/dev/null 2>&1 || command -v qs >/dev/null 2>&1; then
        log_ok "Quickshell toolkit already present ($(command -v quickshell 2>/dev/null || command -v qs))."
    fi

    if declare -f install_core_packages >/dev/null 2>&1; then
        install_core_packages
    fi

    if [[ "${ACTION}" == "deps" ]]; then
        echo ""
        log_ok "Dependency installation complete."
        exit 0
    fi

    # Deploy configs and backups
    deploy_dotfiles

    # Greeter setup
    case "${GREETER_ACTION}" in
        install)
            if ! is_noctalia_greeter_installed || ! command -v greetd >/dev/null 2>&1; then
                if declare -f install_greeter_packages >/dev/null 2>&1; then
                    install_greeter_packages
                fi
            else
                log_ok "greetd and noctalia-greeter are already installed."
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

    # Report greeter installation status
    if command -v noctalia-greeter-session >/dev/null 2>&1 || [[ -x /usr/local/bin/noctalia-greeter-session || -x /usr/bin/noctalia-greeter-session ]]; then
        if systemctl is-enabled greetd.service &>/dev/null; then
            log_ok "Login Manager: noctalia-greeter + greetd enabled."
        else
            log_info "Login Manager: noctalia-greeter is installed (greetd service not enabled)."
        fi
    else
        log_warn "Login Manager: noctalia-greeter was NOT installed."
    fi

    log_info "To start Mango, log out and select Mango from your display manager, or run 'mango' from TTY."
    echo ""
    exit 0
}

main "$@"
exit 0
