#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

gentoo_compatibility_warning() {
    if [[ "${GENTOO_WARNED:-0}" -eq 1 ]]; then
        return 0
    fi

    local bold red yellow green cyan magenta white reset
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        bold="$(tput bold 2>/dev/null || echo "")"
        red="$(tput setaf 1 2>/dev/null || echo "")"
        yellow="$(tput setaf 3 2>/dev/null || echo "")"
        green="$(tput setaf 2 2>/dev/null || echo "")"
        cyan="$(tput setaf 6 2>/dev/null || echo "")"
        magenta="$(tput setaf 5 2>/dev/null || echo "")"
        white="$(tput setaf 7 2>/dev/null || echo "")"
        reset="$(tput sgr0 2>/dev/null || echo "")"
    else
        bold="" red="" yellow="" green="" cyan="" magenta="" white="" reset=""
    fi

    echo ""
    echo -e "${red}${bold}╔══════════════════════════════════════════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red}${bold}║  🚨  ⚠️   ATTENTION: GENTOO LINUX INSTALLATION NOTICE & DEPENDENCY WARNING   ⚠️   🚨           ║${reset}"
    echo -e "${red}${bold}╚══════════════════════════════════════════════════════════════════════════════════════════════════╝${reset}"
    echo -e "${yellow}${bold}  [!] EXPERIMENTAL CONFIGURATION NOTICE:${reset}"
    echo -e "      ${bold}This installer is tested with my personal Gentoo configuration.${reset}"
    echo -e "      Because Gentoo installations vary greatly (custom profiles, USE flags, masks, keywords),"
    echo -e "      ${red}${bold}you will likely have to resolve package dependency issues before installing.${reset}"
    echo ""
    echo -e "${cyan}${bold}  📦 EXPECTED REPOSITORIES (OVERLAYS) REQUIRED:${reset}"
    echo -e "      • ${bold}::gentoo${reset}  (Official Gentoo repository)"
    echo -e "      • ${bold}::guru${reset}    (Gentoo User Repository - required for Noctalia, Quickshell,"
    echo -e "                  Scenefx, Bibata cursors, Yazi, wl-mirror, and wlr-randr)"
    echo ""
    echo -e "${magenta}${bold}  ⚙️  MINIMUM COMPONENT VERSIONS & PREREQUISITES:${reset}"
    echo -e "      • ${bold}gui-libs/wlroots:0.20${reset}     >= 0.20.2 (wlroots 0.20 API required)"
    echo -e "      • ${bold}gui-libs/scenefx:0.5${reset}      >= 0.5.0 (from GURU overlay)"
    echo -e "      • ${bold}gui-wm/mangowc${reset}            v0.17.0 (compiled from source by this installer)"
    echo -e "      • ${bold}gui-apps/noctalia${reset}         >= 5.0.0 (from GURU overlay)"
    echo -e "      • ${bold}gui-apps/quickshell${reset}       Git master (from GURU overlay)"
    echo -e "      • ${bold}dev-libs/wayland-protocols${reset} >= 1.45 (for ext-background-effect protocol)"
    echo -e "      • ${bold}media-video/ffmpeg${reset}        Requires ${yellow}USE=\"vulkan\"${reset} for gpu-screen-recorder"
    echo -e "      • ${bold}ACCEPT_KEYWORDS${reset}          ${yellow}~amd64${reset} required for packages residing in GURU"
    echo ""
    echo -e "${green}${bold}  📖 COMPLETE PACKAGE LIST & MANUAL RESOLUTION GUIDE:${reset}"
    echo -e "      Please refer to: ${bold}${cyan}distros/gentoo/Gentoo-Packages-Needed.md${reset}"
    echo -e "      for the complete list of packages, USE flags, keywords, and manual build steps"
    echo -e "      should this automated script fail on your specific Gentoo setup."
    echo ""
    echo -e "${red}${bold}════════════════════════════════════════════════════════════════════════════════════════════════════${reset}"
    echo ""
    echo -e "${yellow}${bold}  ⚠️  CONFIRMATION REQUIRED:${reset}"
    echo -e "      Do you want to proceed with installation on Gentoo?"
    echo -n "      Type ${bold}Yes${reset} (case-sensitive) to continue [default: No]: "
    read -r gentoo_confirm

    if [[ "${gentoo_confirm}" != "Yes" ]]; then
        echo ""
        log_warn "Installation cancelled. You must enter exact 'Yes' (case-sensitive) to proceed on Gentoo."
        log_info "Default answer is No. Exiting without modifying your system."
        log_info "Please consult ${SCRIPT_DIR}/distros/gentoo/Gentoo-Packages-Needed.md for manual steps."
        exit 0
    fi

    GENTOO_WARNED=1
    export GENTOO_WARNED
    echo ""
    log_ok "Confirmation accepted ('Yes'). Continuing Gentoo setup..."
}

configure_gentoo_repos() {
    log_info "Configuring Gentoo repositories & overlays..."

    # 1. Ensure GURU overlay is enabled (provides noctalia, quickshell, noctalia-greeter, etc.)
    local has_guru=0
    if [[ -d /var/db/repos/guru ]]; then
        has_guru=1
        log_ok "GURU repository is already configured."
    elif [[ -f /etc/portage/repos.conf/guru.conf ]] || grep -rq '\[guru\]' /etc/portage/repos.conf 2>/dev/null; then
        has_guru=1
        log_ok "GURU repository definition found in repos.conf."
    fi

    if [[ "${has_guru}" -eq 0 ]]; then
        log_info "GURU repository not found. Enabling GURU overlay..."
        if command -v eselect >/dev/null 2>&1 && eselect repository list &>/dev/null; then
            if ! eselect repository list -i 2>/dev/null | grep -q 'guru'; then
                sudo eselect repository enable guru 2>&1 | tee -a "${LOG_FILE}" || log_warn "Failed to enable GURU via eselect-repo."
            fi
            log_info "Syncing GURU overlay..."
            sudo emaint sync -r guru 2>&1 | tee -a "${LOG_FILE}" || log_warn "Failed to sync GURU repository."
        else
            log_info "Creating /etc/portage/repos.conf/guru.conf..."
            sudo mkdir -p /etc/portage/repos.conf
            sudo tee /etc/portage/repos.conf/guru.conf >/dev/null <<'EOF'
[guru]
location = /var/db/repos/guru
sync-type = git
sync-uri = https://github.com/gentoo-mirror/guru.git
auto-sync = yes
EOF
            log_info "Syncing GURU repository via emaint..."
            sudo emaint sync -r guru 2>&1 | tee -a "${LOG_FILE}" || log_warn "Failed to sync GURU overlay."
        fi
    fi

    # 2. Check for testing keywords (~amd64 / ~arch)
    # Not all users have ACCEPT_KEYWORDS="~amd64" globally enabled in make.conf.
    # Packages from GURU and bleeding-edge packages require keyword acceptance.
    local arch="amd64"
    if command -v portageq >/dev/null 2>&1; then
        arch="$(portageq envvar ARCH 2>/dev/null || echo "amd64")"
    fi

    local has_global_testing=0
    if grep -qE '^ACCEPT_KEYWORDS=.*~' /etc/portage/make.conf 2>/dev/null; then
        has_global_testing=1
        log_ok "Global testing keywords (~${arch}) are already enabled in /etc/portage/make.conf."
    fi

    if [[ "${has_global_testing}" -eq 0 ]]; then
        log_info "Configuring package.accept_keywords for MangoWC and GURU packages..."
        local kw_dir="/etc/portage/package.accept_keywords"
        local kw_file=""

        if [[ -d "${kw_dir}" ]]; then
            kw_file="${kw_dir}/mangowc"
        else
            kw_file="${kw_dir}"
        fi

        local packages_needing_keywords=(
            "gui-wm/mangowm"
            "gui-apps/noctalia"
            "gui-apps/noctalia-greeter"
            "gui-apps/quickshell"
            "gui-apps/wl-mirror"
            "gui-apps/wlr-randr"
            "media-video/gpu-screen-recorder"
            "x11-themes/bibata-xcursors"
            "app-misc/yazi"
            "gui-libs/scenefx"
        )

        for pkg in "${packages_needing_keywords[@]}"; do
            if ! grep -qs "^${pkg}" "${kw_file}" 2>/dev/null; then
                echo "${pkg} ~${arch}" | sudo tee -a "${kw_file}" >/dev/null
            fi
        done
        log_ok "Added testing keywords (~${arch}) to ${kw_file}."
    fi

    # 3. Configure package.use requirements (e.g. ffmpeg[vulkan] for gpu-screen-recorder)
    local use_dir="/etc/portage/package.use"
    local use_file=""
    if [[ -d "${use_dir}" ]]; then
        use_file="${use_dir}/mangowc"
    else
        use_file="${use_dir}"
    fi

    if ! grep -qs "media-video/ffmpeg.*vulkan" "${use_file}" 2>/dev/null; then
        log_info "Configuring package.use for ffmpeg (vulkan USE flag for gpu-screen-recorder)..."
        echo "media-video/ffmpeg vulkan" | sudo tee -a "${use_file}" >/dev/null
        log_ok "Added 'media-video/ffmpeg vulkan' to ${use_file}."
    fi
}

distro_setup() {
    gentoo_compatibility_warning
    configure_gentoo_repos
}
