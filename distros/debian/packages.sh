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

install_mango() {
    if command -v mango >/dev/null 2>&1 || command -v mangowc >/dev/null 2>&1; then
        log_ok "Mango compositor already installed."
        return 0
    fi

    log_info "Installing Mango compositor for Debian..."
    local wlroots_pkg="libwlroots-0.19-dev"
    if ! pkg_in_repos "${wlroots_pkg}"; then
        wlroots_pkg="libwlroots-dev"
    fi

    local build_deps=(
        "${wlroots_pkg}" meson ninja-build pkg-config libwayland-dev
        wayland-protocols libdrm-dev libegl-dev libgles-dev libpixman-1-dev
        libcjson-dev libpcre2-dev libinput-dev libxkbcommon-dev libxcb-icccm4-dev
    )
    sudo apt-get install -y "${build_deps[@]}" 2>&1 | tee -a "${LOG_FILE}"

    local tmp_dir="/tmp/mango-install-$$"
    mkdir -p "${tmp_dir}"

    # Build and install scenefx 0.4.1 if missing
    if [[ ! -f /usr/local/lib/x86_64-linux-gnu/libscenefx-0.4.so && ! -f /usr/local/lib/libscenefx-0.4.so ]]; then
        log_info "Building scenefx 0.4.1 from source..."
        git clone --depth=1 --branch 0.4.1 https://github.com/wlrfx/scenefx.git "${tmp_dir}/scenefx" 2>&1 | tee -a "${LOG_FILE}"
        meson setup "${tmp_dir}/scenefx/build" "${tmp_dir}/scenefx" --prefix=/usr/local 2>&1 | tee -a "${LOG_FILE}"
        ninja -C "${tmp_dir}/scenefx/build" 2>&1 | tee -a "${LOG_FILE}"
        sudo ninja -C "${tmp_dir}/scenefx/build" install 2>&1 | tee -a "${LOG_FILE}"
    fi

    # Install mango binary and desktop session
    log_info "Fetching and installing mango binaries and desktop session..."
    local deb_path="${tmp_dir}/mangowc.deb"
    if curl -fsSL "https://apt.justaguy.dev/pool/main/mangowc_0.14.4-6_amd64.deb" -o "${deb_path}"; then
        local unpack_dir="${tmp_dir}/unpacked"
        mkdir -p "${unpack_dir}"
        dpkg -x "${deb_path}" "${unpack_dir}"
        sudo cp -a "${unpack_dir}/usr/bin/"* /usr/local/bin/
        sudo cp -a "${unpack_dir}/usr/share/wayland-sessions" /usr/share/ 2>/dev/null || true
        sudo cp -a "${unpack_dir}/usr/share/xdg-desktop-portal" /usr/share/ 2>/dev/null || true
        sudo cp -a "${unpack_dir}/etc/mango" /etc/ 2>/dev/null || true
        sudo ln -sfn /usr/local/bin/mango /usr/local/bin/mangowc
        sudo ln -sfn /usr/local/bin/mango /usr/bin/mango
        sudo ln -sfn /usr/local/bin/mangowc /usr/bin/mangowc
        sudo ln -sfn /usr/local/bin/mango-session /usr/bin/mango-session
        sudo ln -sfn /usr/local/bin/mmsg /usr/bin/mmsg
        sudo ldconfig
        log_ok "Mango compositor installed successfully to /usr/local/bin/mango."
    else
        log_err "Failed to download mangowc package."
    fi

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

    log_info "Installing noctalia-greeter for Debian..."
    local greeter_deps=(
        meson ninja-build pkg-config g++ just dbus
        libwayland-dev wayland-protocols
        libegl-dev libgles-dev libfreetype-dev libfontconfig-dev
        libcairo2-dev libpango1.0-dev libharfbuzz-dev libxkbcommon-dev
        libglib2.0-dev libtomlplusplus-dev nlohmann-json3-dev libstb-dev
        libwebp-dev librsvg2-dev libxml2-dev
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
    log_ok "noctalia-greeter installed successfully."
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

        # Quickshell & Qt6/QML Runtime Dependencies
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
    install_mango
    install_noctalia_shell

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
}

install_greeter_packages() {
    log_info "Checking / installing greetd and noctalia-greeter packages..."
    pkg_install greetd
    install_noctalia_greeter_pkg
}
