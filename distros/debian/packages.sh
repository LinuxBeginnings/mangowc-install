#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

# Check if a package is installed via dpkg
pkg_is_installed() {
    dpkg -s "$1" &>/dev/null
}

# Check if a package exists and has an installable candidate in apt
pkg_in_repos() {
    local candidate
    candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
    [[ -n "${candidate}" && "${candidate}" != "(none)" ]]
}

# Check if a package can satisfy its dependencies in apt simulation
pkg_can_install() {
    sudo apt-get install -s "$1" &>/dev/null
}

# Install missing packages safely using apt
pkg_install() {
    local to_install=()
    local unavailable=()
    local conflict=()

    for pkg in "$@"; do
        if pkg_is_installed "${pkg}"; then
            log_debug "Package '${pkg}' is already installed."
        elif ! pkg_in_repos "${pkg}"; then
            unavailable+=("${pkg}")
        elif ! pkg_can_install "${pkg}"; then
            conflict+=("${pkg}")
        else
            to_install+=("${pkg}")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 && ${#unavailable[@]} -eq 0 && ${#conflict[@]} -eq 0 ]]; then
        log_ok "All requested packages are already installed."
        return 0
    fi

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing packages: ${to_install[*]}"
        sudo apt-get install -y "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"
    fi

    if [[ ${#unavailable[@]} -gt 0 ]]; then
        log_warn "Packages not found in active repositories (skipping): ${unavailable[*]}"
    fi

    if [[ ${#conflict[@]} -gt 0 ]]; then
        log_warn "Packages have unsatisfied dependencies in APT (skipping): ${conflict[*]}"
    fi
}

install_xfce_polkit() {
    if command -v xfce-polkit >/dev/null 2>&1 || [[ -x /usr/local/libexec/xfce-polkit || -x /usr/libexec/xfce-polkit ]]; then
        log_ok "xfce-polkit authentication agent already installed."
        return 0
    fi

    log_info "Installing xfce-polkit authentication agent from source..."
    local polkit_build_deps=(
        meson ninja-build pkg-config gcc
        libxfce4ui-2-dev libpolkit-agent-1-dev libglib2.0-dev
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
        log_ok "Mango compositor already installed."
        return 0
    fi

    local codename="${DETECTED_CODENAME:-}"
    if [[ -z "${codename}" ]]; then
        codename="$(grep -E '^(VERSION_CODENAME|DEBIAN_CODENAME)=' /etc/os-release | cut -d= -f2 | tr -d '"' | head -n1 || echo "")"
    fi

    # Debian Trixie (13): Install prebuilt mangowc package (v0.14.4 built against wlroots 0.19 & scenefx 0.4)
    if [[ "${codename}" == "trixie" || "${DETECTED_VERSION_ID:-}" == "13" ]]; then
        log_info "Debian Trixie detected: Installing precompiled mangowc (v0.14.4 compatible with Trixie Wayland stack) via APT..."
        pkg_install mangowc
        sudo mkdir -p /usr/local/bin
        sudo ln -sfn /usr/bin/mango /usr/local/bin/mango 2>/dev/null || true
        sudo ln -sfn /usr/bin/mango /usr/local/bin/mangowc 2>/dev/null || true
        sudo ln -sfn /usr/bin/mango /usr/bin/mangowc 2>/dev/null || true
        sudo ln -sfn /usr/bin/mango-session /usr/local/bin/mango-session 2>/dev/null || true
        sudo ldconfig
        log_ok "Mango compositor installed successfully via APT."
        return 0
    fi

    # Debian Forky (14) / Sid (unstable): Compile Mango v0.17 from source
    log_info "Debian Forky/Sid detected: Compiling Mango compositor v0.17.0 from source..."
    local build_deps=(
        meson ninja-build pkg-config git gcc g++
        libwayland-dev wayland-protocols
        libdrm-dev libegl-dev libgles-dev libgbm-dev
        libxkbcommon-dev libpixman-1-dev libcjson-dev libpcre2-dev libinput-dev
        libxcb-icccm4-dev libxcb-xinput-dev libxcb-ewmh-dev libxcb-composite0-dev
        libxcb-res0-dev libxcb-errors-dev
        liblcms2-dev libseat-dev libliftoff-dev libdisplay-info-dev hwdata libudev-dev
        glslang-tools libvulkan-dev
        libpango1.0-dev
    )
    pkg_install "${build_deps[@]}"

    local tmp_dir="/tmp/mango-install-$$"
    mkdir -p "${tmp_dir}"
    export PKG_CONFIG_PATH="/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

    # Build and install wlroots 0.20 if missing (mango >= 0.17 requires it)
    if [[ ! -f /usr/local/lib/x86_64-linux-gnu/libwlroots-0.20.so && ! -f /usr/local/lib/libwlroots-0.20.so ]]; then
        log_info "Building wlroots 0.20.2 from source..."
        git clone --depth=1 --branch 0.20.2 https://gitlab.freedesktop.org/wlroots/wlroots.git "${tmp_dir}/wlroots" 2>&1 | tee -a "${LOG_FILE}"
        cd "${tmp_dir}/wlroots"
        meson subprojects download 2>&1 | tee -a "${LOG_FILE}" || true
        if [[ -f subprojects/wayland-protocols/include/wayland-protocols/meson.build ]]; then
            sed -i "s/'--strict',//g" subprojects/wayland-protocols/include/wayland-protocols/meson.build
        fi
        meson setup build --prefix=/usr/local -Dexamples=false --force-fallback-for=wayland-protocols 2>&1 | tee -a "${LOG_FILE}"
        ninja -C build 2>&1 | tee -a "${LOG_FILE}"
        sudo ninja -C build install 2>&1 | tee -a "${LOG_FILE}"
        sudo ldconfig
        cd - >/dev/null
    fi

    # Build and install scenefx 0.5 if missing
    if [[ ! -f /usr/local/lib/x86_64-linux-gnu/libscenefx-0.5.so && ! -f /usr/local/lib/libscenefx-0.5.so ]]; then
        log_info "Building scenefx 0.5 from source..."
        git clone --depth=1 --branch 0.5 https://github.com/wlrfx/scenefx.git "${tmp_dir}/scenefx" 2>&1 | tee -a "${LOG_FILE}"
        meson setup "${tmp_dir}/scenefx/build" "${tmp_dir}/scenefx" --prefix=/usr/local 2>&1 | tee -a "${LOG_FILE}"
        ninja -C "${tmp_dir}/scenefx/build" 2>&1 | tee -a "${LOG_FILE}"
        sudo ninja -C "${tmp_dir}/scenefx/build" install 2>&1 | tee -a "${LOG_FILE}"
        sudo ldconfig
    fi

    # Build and install mango 0.17.0 from source
    log_info "Building mango 0.17.0 from source..."
    git clone --depth=1 --branch 0.17.0 https://github.com/mangowm/mango.git "${tmp_dir}/mango" 2>&1 | tee -a "${LOG_FILE}"
    cd "${tmp_dir}/mango"
    PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" \
        meson setup build --prefix=/usr/local 2>&1 | tee -a "${LOG_FILE}"
    ninja -C build 2>&1 | tee -a "${LOG_FILE}"
    sudo ninja -C build install 2>&1 | tee -a "${LOG_FILE}"
    cd - >/dev/null

    # Create session wrapper and desktop entries
    sudo mkdir -p /usr/share/wayland-sessions
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

    sudo tee /usr/local/bin/mango-session >/dev/null <<'SESSION_EOF'
#!/bin/sh
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
    sudo ldconfig
    log_ok "Mango compositor installed successfully to /usr/local/bin/mango."

    rm -rf "${tmp_dir}"
}

install_noctalia_shell() {
    if command -v noctalia >/dev/null 2>&1; then
        log_ok "Noctalia desktop shell already installed."
        return 0
    fi

    log_info "Installing Noctalia desktop shell..."
    local shell_deps=(
        meson g++ just pkg-config
        libwayland-dev wayland-protocols
        libegl-dev libgles-dev
        libfreetype-dev libfontconfig-dev
        libcairo2-dev libpango1.0-dev libharfbuzz-dev
        libxkbcommon-dev libglib2.0-dev
        libsecret-1-dev libsodium-dev
        libsdbus-c++-dev libpipewire-0.3-dev libwireplumber-0.5-dev
        libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev
        libwebp-dev libjxl-dev libsndfile1-dev librsvg2-dev
        libqalculate-dev libxml2-dev
        libmd4c-dev libtomlplusplus-dev libical-dev
        nlohmann-json3-dev libstb-dev
        libjemalloc-dev
    )
    sudo apt-get install -y "${shell_deps[@]}" 2>&1 | tee -a "${LOG_FILE}"

    # Ensure wayland-protocols provides ext-background-effect-v1.xml (added in wayland-protocols >= 1.45, required by Noctalia v5)
    local wayland_protos_dir
    wayland_protos_dir="$(pkg-config --variable=pkgdatadir wayland-protocols 2>/dev/null || echo "/usr/share/wayland-protocols")"
    if [[ ! -f "${wayland_protos_dir}/staging/ext-background-effect/ext-background-effect-v1.xml" ]]; then
        local codename="${DETECTED_CODENAME:-}"
        if [[ -z "${codename}" ]]; then
            codename="$(grep -E '^(VERSION_CODENAME|DEBIAN_CODENAME)=' /etc/os-release | cut -d= -f2 | tr -d '"' | head -n1 || echo "")"
        fi
        if [[ "${codename}" == "trixie" || "${DETECTED_VERSION_ID:-}" == "13" ]]; then
            log_info "Updating wayland-protocols from trixie-backports for ext-background-effect protocol..."
            sudo apt-get install -y -t trixie-backports wayland-protocols 2>&1 | tee -a "${LOG_FILE}" || true
        fi
    fi

    # Fallback: fetch protocol XML directly if still missing from system wayland-protocols
    if [[ ! -f "${wayland_protos_dir}/staging/ext-background-effect/ext-background-effect-v1.xml" ]]; then
        log_info "Fetching missing ext-background-effect-v1.xml protocol definition..."
        sudo mkdir -p "${wayland_protos_dir}/staging/ext-background-effect"
        sudo curl -fsSL "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/raw/main/staging/ext-background-effect/ext-background-effect-v1.xml" \
            -o "${wayland_protos_dir}/staging/ext-background-effect/ext-background-effect-v1.xml" 2>&1 | tee -a "${LOG_FILE}" || true
    fi

    local tmp_dir="/tmp/noctalia-shell-$$"
    mkdir -p "${tmp_dir}"

    log_info "Downloading Noctalia v5 source release..."
    if curl -fsSL "https://github.com/noctalia-dev/noctalia/releases/download/v5.1.0/noctalia-latest.tar.gz" -o "${tmp_dir}/noctalia.tar.gz"; then
        tar -xzf "${tmp_dir}/noctalia.tar.gz" -C "${tmp_dir}"
        local src_dir="${tmp_dir}/noctalia-release"
        cd "${src_dir}"
        meson setup build --prefix=/usr/local --buildtype=release 2>&1 | tee -a "${LOG_FILE}"
        ninja -C build 2>&1 | tee -a "${LOG_FILE}"
        sudo ninja -C build install 2>&1 | tee -a "${LOG_FILE}"
        sudo ln -sfn /usr/local/bin/noctalia /usr/bin/noctalia
        sudo ldconfig
        cd - >/dev/null
        log_ok "Noctalia desktop shell installed successfully."
    else
        log_err "Failed to download Noctalia source release."
    fi

    rm -rf "${tmp_dir}"
}

install_noctalia_greeter_pkg() {
    if command -v noctalia-greeter-session >/dev/null 2>&1; then
        log_ok "noctalia-greeter-session already installed."
        return 0
    fi

    local codename="${DETECTED_CODENAME:-}"
    if [[ -z "${codename}" ]]; then
        codename="$(grep -E '^(VERSION_CODENAME|DEBIAN_CODENAME)=' /etc/os-release | cut -d= -f2 | tr -d '"' | head -n1 || echo "")"
    fi

    if [[ "${codename}" == "trixie" || "${DETECTED_VERSION_ID:-}" == "13" ]]; then
        log_warn "noctalia-greeter is NOT supported on Debian 13 (Trixie) due to wlroots 0.20 ABI incompatibility with Trixie's native Wayland stack."
        log_warn "Skipping noctalia-greeter installation. greetd configuration will not be applied."
        return 1
    fi

    log_info "Installing noctalia-greeter for Debian Forky/Sid..."
    local greeter_deps=(
        meson ninja-build pkg-config git gcc g++ just dbus
        libwayland-dev wayland-protocols
        libegl-dev libgles-dev libfreetype-dev libfontconfig-dev
        libcairo2-dev libpango1.0-dev libharfbuzz-dev libxkbcommon-dev
        libglib2.0-dev libtomlplusplus-dev nlohmann-json3-dev libstb-dev
        libwebp-dev librsvg2-dev libxml2-dev
        libinput-dev libdrm-dev libgbm-dev libseat-dev
        libdisplay-info-dev libliftoff-dev libpixman-1-dev hwdata libudev-dev
    )
    sudo apt-get install -y "${greeter_deps[@]}" 2>&1 | tee -a "${LOG_FILE}"

    local tmp_dir="/tmp/noctalia-greeter-$$"
    mkdir -p "${tmp_dir}"

    # Build and install wlroots 0.20 if missing
    if [[ ! -f /usr/local/lib/x86_64-linux-gnu/libwlroots-0.20.so && ! -f /usr/local/lib/libwlroots-0.20.so ]]; then
        log_info "Building wlroots 0.20 dependency for noctalia-greeter..."
        git clone --depth=1 --branch 0.20.2 https://gitlab.freedesktop.org/wlroots/wlroots.git "${tmp_dir}/wlroots" 2>&1 | tee -a "${LOG_FILE}"
        cd "${tmp_dir}/wlroots"
        meson subprojects download 2>&1 | tee -a "${LOG_FILE}" || true
        if [[ -f subprojects/wayland-protocols/include/wayland-protocols/meson.build ]]; then
            sed -i "s/'--strict',//g" subprojects/wayland-protocols/include/wayland-protocols/meson.build
        fi
        meson setup build --prefix=/usr/local -Dexamples=false --force-fallback-for=wayland-protocols 2>&1 | tee -a "${LOG_FILE}"
        ninja -C build 2>&1 | tee -a "${LOG_FILE}"
        sudo ninja -C build install 2>&1 | tee -a "${LOG_FILE}"
        sudo ldconfig
        cd - >/dev/null
    fi

    # Build and install noctalia-greeter
    log_info "Building noctalia-greeter from source..."
    git clone --depth=1 https://github.com/noctalia-dev/noctalia-greeter.git "${tmp_dir}/noctalia-greeter" 2>&1 | tee -a "${LOG_FILE}"
    cd "${tmp_dir}/noctalia-greeter"
    PKG_CONFIG_PATH="/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
        meson setup build --prefix=/usr/local --buildtype=release 2>&1 | tee -a "${LOG_FILE}"
    ninja -C build 2>&1 | tee -a "${LOG_FILE}"
    sudo ninja -C build install 2>&1 | tee -a "${LOG_FILE}"
    sudo cp -a scripts/noctalia-greeter-session /usr/local/bin/
    sudo chmod +x /usr/local/bin/noctalia-greeter-session
    sudo ln -sfn /usr/local/bin/noctalia-greeter-session /usr/bin/noctalia-greeter-session
    sudo ln -sfn /usr/local/bin/noctalia-greeter /usr/bin/noctalia-greeter
    sudo ldconfig
    cd - >/dev/null

    rm -rf "${tmp_dir}"

    if [[ ! -x /usr/local/bin/noctalia-greeter-session && ! -x /usr/bin/noctalia-greeter-session ]]; then
        log_err "noctalia-greeter installation failed: 'noctalia-greeter-session' binary was not created."
        return 1
    fi

    log_ok "noctalia-greeter installed successfully."
}

install_gpu_screen_recorder() {
    log_info "Setting up gpu-screen-recorder (Flatpak)..."

    # Ensure Flatpak is installed
    if command -v flatpak >/dev/null 2>&1; then
        log_ok "Flatpak already installed."
    else
        log_info "Installing Flatpak..."
        pkg_install flatpak
    fi

    # Ensure the Flathub remote is configured
    if flatpak remotes --system 2>/dev/null | grep -q '^flathub'; then
        log_ok "Flathub remote already configured."
    else
        log_info "Adding the Flathub remote..."
        sudo flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 | tee -a "${LOG_FILE}"
    fi

    # Note: the Flatpak bundles a patched, statically-linked FFmpeg (equivalent to
    # the source build's -Dffmpeg_static=true), so it also works on older NVIDIA GPUs.
    if flatpak info com.dec05eba.gpu_screen_recorder &>/dev/null; then
        log_ok "gpu-screen-recorder Flatpak already installed."
        return 0
    fi

    # Install system-wide so AMD/Intel monitor capture works
    log_info "Installing gpu-screen-recorder Flatpak application..."
    sudo flatpak install -y --system flathub com.dec05eba.gpu_screen_recorder 2>&1 | tee -a "${LOG_FILE}"
    log_ok "gpu-screen-recorder installed via Flatpak."
}

install_core_packages() {
    log_info "Installing core packages for Debian..."

    local core_pkgs=(
        # Base tools & Wayland prerequisites
        git
        curl
        wget
        rsync
        xwayland
        wl-clipboard
        wl-mirror
        wlr-randr
        grim
        slurp
        uwsm
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk

        # Terminal & system info
        kitty
        fastfetch
        yazi
        thunar
        eza
        htop
        btop
        zoxide

        # Theming & Appearance
        bibata-cursor-theme
        qt5ct
        qt6ct
        fonts-noto-color-emoji

        # Polkit Authentication Agent
        xfce-polkit

        # Quickshell Desktop Shell Toolkit
        quickshell

        # Qt6/QML Runtime Dependencies
        qml6-module-qtquick-templates
        qml6-module-qt5compat-graphicaleffects
        qt6-wayland
        qml6-module-qtquick-layouts
        qml6-module-qtquick-controls
        qml6-module-qtquick-shapes
        socat
        jq
    )

    pkg_install "${core_pkgs[@]}"
    install_xfce_polkit
    install_mango
    install_noctalia_shell
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
    if pkg_is_installed "mangowc" || pkg_is_installed "mangowm" || command -v mango >/dev/null 2>&1 || command -v mangowc >/dev/null 2>&1; then
        log_ok "Mango compositor verified."
    else
        log_warn "Mango compositor binary ('mango' or 'mangowc') not found on PATH."
        log_warn "Ensure mangowc is compiled or installed for Debian."
    fi

    # Verify Noctalia greeter
    if command -v noctalia-greeter-session >/dev/null 2>&1 || [[ -x /usr/local/bin/noctalia-greeter-session || -x /usr/bin/noctalia-greeter-session ]]; then
        log_ok "Noctalia greeter verified."
    else
        log_info "Noctalia greeter is NOT installed."
    fi
}

install_greeter_packages() {
    log_info "Checking / installing greetd and noctalia-greeter packages..."
    pkg_install greetd
    install_noctalia_greeter_pkg
}
