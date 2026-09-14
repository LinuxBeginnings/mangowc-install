#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

# Check if a package is installed in Gentoo
pkg_is_installed() {
    local pkg="$1"
    # Strip repository or version constraints if present
    local clean_pkg="${pkg%%::*}"
    clean_pkg="${clean_pkg#>=}"
    clean_pkg="${clean_pkg#>}"
    clean_pkg="${clean_pkg#<=}"
    clean_pkg="${clean_pkg#<}"
    clean_pkg="${clean_pkg#=}"

    if command -v qlist >/dev/null 2>&1; then
        qlist -I -e "${clean_pkg}" &>/dev/null && return 0
    fi

    if command -v equery >/dev/null 2>&1; then
        equery list -e "${clean_pkg}" &>/dev/null && return 0
    fi

    if [[ "${clean_pkg}" == */* ]]; then
        compgen -G "/var/db/pkg/${clean_pkg}-[0-9]*" >/dev/null && return 0
    else
        compgen -G "/var/db/pkg/*/${clean_pkg}-[0-9]*" >/dev/null && return 0
    fi

    local bin_name="${clean_pkg##*/}"
    command -v "${bin_name}" >/dev/null 2>&1 && return 0

    return 1
}

# Install missing packages using emerge with binary preference and source fallback
pkg_install() {
    local to_install=()

    for pkg in "$@"; do
        if pkg_is_installed "${pkg}"; then
            log_debug "Package '${pkg}' is already installed."
        else
            to_install+=("${pkg}")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_ok "All requested packages are already installed."
        return 0
    fi

    log_info "Installing packages via emerge (attempting binary packages with source fallback): ${to_install[*]}"
    # Attempt binary packages with fallback to source
    # --getbinpkg=y: use binary packages if available in binhost
    # --binpkg-respect-use=y: respect USE flag configuration
    if sudo emerge --getbinpkg=y --binpkg-respect-use=y "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"; then
        log_ok "Packages installed successfully."
    else
        log_warn "emerge with binary preference encountered an issue, retrying with direct source compilation..."
        if sudo emerge "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"; then
            log_ok "Packages compiled and installed from source successfully."
        else
            log_warn "Some packages failed to install via emerge. Check ${LOG_FILE} and distros/gentoo/Gentoo-Packages-Needed.md for manual steps."
            return 1
        fi
    fi
}

install_xfce_polkit() {
    if command -v xfce-polkit >/dev/null 2>&1 || [[ -x /usr/local/libexec/xfce-polkit || -x /usr/libexec/xfce-polkit ]]; then
        log_ok "xfce-polkit authentication agent already installed."
        return 0
    fi

    log_info "Installing xfce-polkit authentication agent from source..."
    local polkit_build_deps=(
        dev-build/meson
        dev-build/ninja
        virtual/pkgconfig
        sys-devel/gcc
        xfce-base/libxfce4ui
        sys-auth/polkit
        dev-libs/glib
    )
    pkg_install "${polkit_build_deps[@]}"

    local tmp_dir="/tmp/xfce-polkit-install-$$"
    mkdir -p "${tmp_dir}"
    git clone --depth=1 https://github.com/ncopa/xfce-polkit.git "${tmp_dir}/xfce-polkit" 2>&1 | tee -a "${LOG_FILE}"
    cd "${tmp_dir}/xfce-polkit"
    meson setup build --prefix=/usr/local --libexecdir=libexec 2>&1 | tee -a "${LOG_FILE}"
    ninja -C build 2>&1 | tee -a "${LOG_FILE}"
    sudo ninja -C build install 2>&1 | tee -a "${LOG_FILE}"
    cd - >/dev/null

    sudo mkdir -p /usr/libexec
    sudo ln -sfn /usr/local/libexec/xfce-polkit /usr/libexec/xfce-polkit
    sudo ln -sfn /usr/local/libexec/xfce-polkit /usr/local/bin/xfce-polkit
    sudo ln -sfn /usr/local/libexec/xfce-polkit /usr/bin/xfce-polkit 2>/dev/null || true
    rm -rf "${tmp_dir}"
    log_ok "xfce-polkit installed successfully."
}

install_mango() {
    local force="${1:-0}"
    if [[ "${force}" -ne 1 ]] && (command -v mango >/dev/null 2>&1 || command -v mangowc >/dev/null 2>&1); then
        local ver
        ver="$((mango -v 2>&1 || mangowc -v 2>&1 || echo "") | head -n1)"
        if [[ "${ver}" =~ 0\.17 ]]; then
            log_ok "Mango compositor v0.17.0 already installed (${ver})."
            return 0
        fi
    fi

    log_info "Compiling Mango compositor v0.17.0 from source..."
    local build_deps=(
        dev-build/meson
        dev-build/ninja
        virtual/pkgconfig
        dev-vcs/git
        sys-devel/gcc
        dev-libs/wayland
        dev-libs/wayland-protocols
        x11-libs/libxkbcommon
        x11-libs/pixman
        dev-libs/cJSON
        dev-libs/libpcre2
        dev-libs/libinput
        dev-libs/glib
        x11-libs/cairo
        x11-libs/pango
        x11-base/xwayland
        x11-libs/libxcb
        x11-libs/xcb-util-wm
        gui-libs/wlroots:0.20
        gui-libs/scenefx:0.5
    )
    pkg_install "${build_deps[@]}"

    local tmp_dir="/tmp/mango-install-$$"
    mkdir -p "${tmp_dir}"

    log_info "Cloning mango repository (tag 0.17.0)..."
    git clone --depth=1 --branch 0.17.0 https://github.com/mangowm/mango.git "${tmp_dir}/mango" 2>&1 | tee -a "${LOG_FILE}"
    cd "${tmp_dir}/mango"
    meson setup build --prefix=/usr/local 2>&1 | tee -a "${LOG_FILE}"
    ninja -C build 2>&1 | tee -a "${LOG_FILE}"
    sudo ninja -C build install 2>&1 | tee -a "${LOG_FILE}"
    cd - >/dev/null

    # Create session wrapper and desktop entries
    sudo mkdir -p /usr/share/wayland-sessions /usr/local/share/wayland-sessions
    sudo tee /usr/share/wayland-sessions/mango.desktop >/dev/null <<'DESKTOP_EOF'
[Desktop Entry]
Encoding=UTF-8
Name=Mango
DesktopNames=mango;wlroots
Comment=mango WM
Exec=mango-session
Icon=mango
Type=Application
DESKTOP_EOF
    sudo cp -f /usr/share/wayland-sessions/mango.desktop /usr/local/share/wayland-sessions/mango.desktop

    sudo tee /usr/local/bin/mango-session >/dev/null <<'SESSION_EOF'
#!/bin/sh
if [ -z "${WLR_NO_HARDWARE_CURSORS:-}" ]; then
    if (command -v systemd-detect-virt >/dev/null 2>&1 && [ "$(systemd-detect-virt 2>/dev/null)" != "none" ]) || \
       (lspci 2>/dev/null | grep -qi 'nvidia') || (grep -qi 'nvidia' /proc/modules 2>/dev/null); then
        export WLR_NO_HARDWARE_CURSORS=1
    fi
fi
ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/mango/env"
if [ -r "$ENV_FILE" ]; then
    if sh -n "$ENV_FILE" 2>/dev/null; then
        set -a
        . "$ENV_FILE"
        set +a
    fi
fi
if [ -x /usr/local/bin/mango ]; then
    exec /usr/local/bin/mango "$@"
else
    exec /usr/bin/mango "$@"
fi
SESSION_EOF
    sudo chmod +x /usr/local/bin/mango-session

    sudo ln -sfn /usr/local/bin/mango /usr/local/bin/mangowc
    sudo ln -sfn /usr/local/bin/mango /usr/bin/mango
    sudo ln -sfn /usr/local/bin/mangowc /usr/bin/mangowc
    sudo ln -sfn /usr/local/bin/mango-session /usr/bin/mango-session
    sudo ln -sfn /usr/local/bin/mmsg /usr/bin/mmsg 2>/dev/null || true
    sudo ldconfig 2>/dev/null || true
    log_ok "Mango compositor v0.17.0 installed successfully to /usr/local/bin/mango."

    rm -rf "${tmp_dir}"
}

install_gpu_screen_recorder() {
    if command -v gpu-screen-recorder >/dev/null 2>&1 || (command -v flatpak >/dev/null 2>&1 && flatpak info com.dec05eba.gpu_screen_recorder &>/dev/null); then
        log_ok "gpu-screen-recorder already installed."
        return 0
    fi

    log_info "Attempting to install gpu-screen-recorder via Portage..."
    if pkg_install "media-video/gpu-screen-recorder"; then
        log_ok "gpu-screen-recorder installed via Portage."
        return 0
    fi

    log_warn "Portage installation of gpu-screen-recorder failed (likely ffmpeg[vulkan] requirement). Falling back to Flatpak..."
    if ! command -v flatpak >/dev/null 2>&1; then
        log_info "Installing Flatpak..."
        pkg_install sys-apps/flatpak
    fi

    if ! flatpak remotes --system 2>/dev/null | grep -q '^flathub'; then
        log_info "Adding Flathub remote..."
        sudo flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 | tee -a "${LOG_FILE}"
    fi

    log_info "Installing gpu-screen-recorder via Flatpak..."
    sudo flatpak install -y --system flathub com.dec05eba.gpu_screen_recorder 2>&1 | tee -a "${LOG_FILE}"
    log_ok "gpu-screen-recorder installed via Flatpak."
}

install_core_packages() {
    log_info "Installing core packages for Gentoo..."

    local core_pkgs=(
        # Base tools & Wayland prerequisites
        dev-vcs/git
        net-misc/curl
        net-misc/wget
        net-misc/rsync
        x11-base/xwayland
        gui-apps/wl-clipboard
        gui-apps/wl-mirror
        gui-apps/wlr-randr
        gui-apps/grim
        gui-apps/slurp
        gui-apps/uwsm
        gui-libs/xdg-desktop-portal-wlr
        sys-apps/xdg-desktop-portal-gtk

        # Terminal & system info
        x11-terms/kitty
        app-misc/fastfetch
        app-misc/yazi
        xfce-base/thunar
        sys-apps/eza
        sys-process/htop
        sys-process/btop
        app-shells/zoxide
        media-sound/cava

        # Theming & Appearance
        x11-themes/bibata-xcursors
        gui-apps/qt6ct
        media-fonts/noto-emoji

        # Quickshell Desktop Shell Toolkit & Qt6 Dependencies
        gui-apps/quickshell
        dev-qt/qtdeclarative:6
        dev-qt/qtwayland:6
        dev-qt/qt5compat:6
        dev-qt/qtsvg:6
        dev-qt/qtmultimedia:6
        dev-qt/qtimageformats:6
        net-misc/socat
        app-misc/jq

        # Desktop Shell
        gui-apps/noctalia
    )

    # Virtual machine guest utilities
    if is_virtual_machine; then
        core_pkgs+=("app-emulation/qemu-guest-agent")
    fi

    pkg_install "${core_pkgs[@]}"
    install_xfce_polkit
    install_mango
    install_gpu_screen_recorder

    # Verify Noctalia desktop shell
    if command -v noctalia >/dev/null 2>&1; then
        log_ok "Noctalia desktop shell verified."
    else
        log_warn "Noctalia desktop shell binary ('noctalia') not found on PATH."
    fi

    # Verify Quickshell
    if command -v quickshell >/dev/null 2>&1 || command -v qs >/dev/null 2>&1; then
        log_ok "Quickshell installation verified."
    else
        log_warn "Quickshell binary ('quickshell' or 'qs') not found on PATH."
    fi

    # Verify Mango compositor
    if command -v mango >/dev/null 2>&1 || command -v mangowc >/dev/null 2>&1; then
        log_ok "Mango compositor verified."
    else
        log_warn "Mango compositor binary ('mango' or 'mangowc') not found on PATH."
    fi

    # Verify Noctalia greeter
    if command -v noctalia-greeter-session >/dev/null 2>&1 || [[ -x /usr/local/bin/noctalia-greeter-session || -x /usr/bin/noctalia-greeter-session ]]; then
        log_ok "Noctalia greeter verified."
    else
        log_info "Noctalia greeter is NOT installed."
    fi

    # Verify Rustup / Cargo toolchain
    check_rustup_cargo
}

install_greeter_packages() {
    log_info "Checking / installing greetd and noctalia-greeter packages..."
    pkg_install gui-libs/greetd gui-apps/noctalia-greeter

    # Ensure noctalia-greeter-session wrapper script exists
    if ! command -v noctalia-greeter-session >/dev/null 2>&1 && [[ ! -x /usr/local/bin/noctalia-greeter-session && ! -x /usr/bin/noctalia-greeter-session ]]; then
        if command -v noctalia-greeter >/dev/null 2>&1; then
            log_info "Creating noctalia-greeter-session wrapper..."
            sudo tee /usr/local/bin/noctalia-greeter-session >/dev/null <<'EOF'
#!/bin/sh
export GREETER_BIN=/usr/bin/noctalia-greeter
if [ ! -x "$GREETER_BIN" ]; then
    GREETER_BIN="$(command -v noctalia-greeter 2>/dev/null || echo "/usr/local/bin/noctalia-greeter")"
fi
if [ -z "$WLR_NO_HARDWARE_CURSORS" ]; then
    if (command -v systemd-detect-virt >/dev/null 2>&1 && [ "$(systemd-detect-virt 2>/dev/null)" != "none" ]) || \
       (lspci 2>/dev/null | grep -qi "nvidia") || (grep -qi "nvidia" /proc/modules 2>/dev/null); then
        export WLR_NO_HARDWARE_CURSORS=1
    fi
fi
exec "$GREETER_BIN" "$@"
EOF
            sudo chmod +x /usr/local/bin/noctalia-greeter-session
            sudo ln -sfn /usr/local/bin/noctalia-greeter-session /usr/bin/noctalia-greeter-session
            log_ok "Created /usr/local/bin/noctalia-greeter-session wrapper."
        fi
    fi
}

uninstall_packages() {
    log_info "Uninstalling MangoWC and Noctalia for Gentoo..."

    local pkgs_to_remove=()
    for pkg in gui-apps/noctalia gui-apps/noctalia-greeter; do
        if pkg_is_installed "${pkg}"; then
            pkgs_to_remove+=("${pkg}")
        fi
    done

    if [[ ${#pkgs_to_remove[@]} -gt 0 ]]; then
        log_info "Depcleaning packages: ${pkgs_to_remove[*]}"
        sudo emerge --depclean "${pkgs_to_remove[@]}" 2>&1 | tee -a "${LOG_FILE}" || true
    fi

    log_info "Removing binaries and session wrappers..."
    sudo rm -f /usr/local/bin/mango /usr/local/bin/mangowc /usr/local/bin/mango-session /usr/local/bin/mmsg
    sudo rm -f /usr/bin/mango /usr/bin/mangowc /usr/bin/mango-session /usr/bin/mmsg
    sudo rm -f /usr/share/wayland-sessions/mango.desktop /usr/local/share/wayland-sessions/mango.desktop

    sudo rm -f /usr/local/bin/xfce-polkit /usr/libexec/xfce-polkit /usr/local/libexec/xfce-polkit

    sudo rm -f /usr/local/bin/noctalia-greeter-session /usr/bin/noctalia-greeter-session

    if command -v flatpak >/dev/null 2>&1 && flatpak info com.dec05eba.gpu_screen_recorder &>/dev/null; then
        log_info "Removing gpu-screen-recorder Flatpak..."
        sudo flatpak uninstall -y com.dec05eba.gpu_screen_recorder 2>&1 | tee -a "${LOG_FILE}" || true
    fi

    log_ok "Gentoo components uninstalled."
}
