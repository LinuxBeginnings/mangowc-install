#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

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
    configure_gentoo_repos
}
