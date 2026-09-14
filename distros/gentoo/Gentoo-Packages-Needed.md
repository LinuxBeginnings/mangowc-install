# Gentoo Packages Needed for MangoWC + Noctalia

> **IMPORTANT WARNING**: This installer was built and tested against the maintainer's personal Gentoo system configuration with testing keywords globally enabled (`~amd64`). Because Gentoo setups differ widely based on chosen system profile (desktop, systemd, openrc), USE flags, package masks, and keywords, **you will likely have to resolve package dependency conflicts before or during installation**.

---

## 1. Expected Repositories & Overlays

This project requires two Portage repositories:

1. **`::gentoo`** (Official Gentoo Repository) - Provides base tools, XWayland, Wayland protocols, Qt6 runtime packages, Kitty, Fastfetch, etc.
2. **`::guru`** (Gentoo User Repository) - Required for `gui-apps/noctalia`, `gui-apps/quickshell`, `gui-apps/noctalia-greeter`, `gui-libs/scenefx:0.5`, `app-misc/yazi`, `gui-apps/wl-mirror`, `gui-apps/wlr-randr`, `media-video/gpu-screen-recorder`, and `x11-themes/bibata-xcursors`.

Enable the GURU repository using `eselect-repository`:

```bash
sudo eselect repository enable guru
sudo emaint sync -r guru
```

*(If `eselect-repository` is not installed, run `sudo emerge app-eselect/eselect-repository` first.)*

---

## 2. Minimum Component Versions & Prerequisites

| Component | Minimum Version | Notes |
| --- | --- | --- |
| `gui-libs/wlroots` | `>= 0.20.2` (slot `:0.20`) | Required by Mango v0.17.0 and Noctalia Greeter |
| `gui-libs/scenefx` | `>= 0.5.0` (slot `:0.5`) | Required by Mango v0.17.0 (from GURU overlay) |
| `gui-wm/mangowc` | `v0.17.0` | Compiled from source by installer (GURU package is v0.16.x) |
| `gui-apps/noctalia` | `>= 5.0.0` | Desktop shell v5 (from GURU overlay) |
| `gui-apps/quickshell` | Git master | Shell toolkit (from GURU overlay) |
| `dev-libs/wayland-protocols` | `>= 1.45` | Required for `ext-background-effect` protocol |
| `media-video/ffmpeg` | `USE="vulkan"` | Required for `gpu-screen-recorder` hardware capture |
| `dev-build/meson` | `>= 0.60.0` | Required for building Mango and Noctalia |
| `ACCEPT_KEYWORDS` | `~amd64` / `~arch` | Required for all packages residing in GURU |

---

## 2. Portage Configuration (Keywords & USE flags)

### Accept Testing Keywords (`~amd64`)

If you are running a stable Gentoo profile (the default for most users without `ACCEPT_KEYWORDS="~amd64"` in `/etc/portage/make.conf`), you must accept testing keywords for packages residing in GURU or requiring newer revisions.

Add the following to `/etc/portage/package.accept_keywords/mangowc` (or `/etc/portage/package.accept_keywords`):

```text
# MangoWM dependencies and scenefx
gui-libs/scenefx ~amd64
gui-libs/wlroots:0.20 ~amd64
gui-wm/mangowm ~amd64

# Noctalia desktop shell & greeter
gui-apps/noctalia ~amd64
gui-apps/noctalia-greeter ~amd64

# Quickshell and Qt dependencies
gui-apps/quickshell ~amd64

# Wayland display and terminal utilities
gui-apps/wl-mirror ~amd64
gui-apps/wlr-randr ~amd64
app-misc/yazi ~amd64
x11-themes/bibata-xcursors ~amd64
media-video/gpu-screen-recorder ~amd64
```

### USE Flag Requirements

`media-video/gpu-screen-recorder` requires `media-video/ffmpeg` to be compiled with the `vulkan` USE flag.

Add the following to `/etc/portage/package.use/mangowc` (or `/etc/portage/package.use`):

```text
media-video/ffmpeg vulkan
```

---

## 3. Complete Gentoo Package List

### A. Wayland Compositor & Core Desktop Components
| Package | Description | Source / Repo |
| --- | --- | --- |
| `gui-wm/mangowm` | Mango Wayland Compositor (Portage GURU package v0.16.x) | `::guru` |
| `gui-apps/noctalia` | Noctalia Desktop Shell v5 | `::guru` |
| `gui-apps/quickshell` | Quickshell Desktop Shell Toolkit | `::guru` |
| `gui-apps/uwsm` | Universal Wayland Session Manager | `::gentoo` |

> **Note on Mango Compositor Version**: The Portage GURU ebuild for `gui-wm/mangowm` is currently v0.16.x. The installer compiles **Mango v0.17.0** from source directly against `gui-libs/wlroots:0.20` and `gui-libs/scenefx:0.5`. See Section 5 below for manual build instructions.

### B. Wayland Display, Portals & Capture Utilities
| Package | Description | Source / Repo |
| --- | --- | --- |
| `x11-base/xwayland` | XWayland support for X11 applications | `::gentoo` |
| `gui-apps/wl-clipboard` | Command-line Wayland clipboard utilities (`wl-copy`, `wl-paste`) | `::gentoo` |
| `gui-apps/wl-mirror` | Simple Wayland display/window mirroring tool | `::guru` |
| `gui-apps/wlr-randr` | Display output management (resolution, refresh, orientation) | `::guru` |
| `gui-apps/grim` | Wayland screenshot grabber | `::gentoo` |
| `gui-apps/slurp` | Interactive screen region selection tool | `::gentoo` |
| `gui-libs/xdg-desktop-portal-wlr` | wlroots backend for XDG desktop portal (screencasting) | `::gentoo` |
| `sys-apps/xdg-desktop-portal-gtk` | GTK backend for XDG desktop portal (file pickers, settings) | `::gentoo` |
| `media-video/gpu-screen-recorder` | High performance Wayland screen recorder (or Flatpak) | `::guru` |

### C. Terminal & Productivity Utilities
| Package | Description | Source / Repo |
| --- | --- | --- |
| `x11-terms/kitty` | Primary GPU-accelerated terminal emulator | `::gentoo` |
| `app-misc/fastfetch` | Fast, lightweight system information display tool | `::gentoo` |
| `app-misc/yazi` | Fast asynchronous terminal file manager | `::guru` |
| `xfce-base/thunar` | Lightweight graphical file manager | `::gentoo` |
| `sys-apps/eza` | Modern, maintained replacement for `ls` | `::gentoo` |
| `sys-process/htop` | Interactive process viewer | `::gentoo` |
| `sys-process/btop` | Modern visual resource monitor | `::gentoo` |
| `app-shells/zoxide` | Smarter `cd` command with frecent directory navigation | `::gentoo` |
| `media-sound/cava` | Console audio visualizer | `::gentoo` |
| `net-misc/socat` | Multipurpose relay tool for Quickshell IPC communication | `::gentoo` |
| `app-misc/jq` | Lightweight command-line JSON processor | `::gentoo` |
| `dev-vcs/git` | Version control system | `::gentoo` |
| `net-misc/curl` | HTTP client | `::gentoo` |
| `net-misc/wget` | File retriever | `::gentoo` |
| `net-misc/rsync` | Remote file synchronization utility | `::gentoo` |

### D. Theming & Appearance
| Package | Description | Source / Repo |
| --- | --- | --- |
| `x11-themes/bibata-xcursors` | Bibata Modern Ice cursor theme | `::guru` |
| `gui-apps/qt6ct` | Qt6 Configuration Tool for style, fonts, and icons | `::gentoo` |
| `media-fonts/noto-emoji` | Google Noto color emoji font | `::gentoo` |

### E. Qt6 Runtime Dependencies for Quickshell
| Package | Description | Source / Repo |
| --- | --- | --- |
| `dev-qt/qtdeclarative:6` | Qt6 QML and Quick declarative runtime | `::gentoo` |
| `dev-qt/qtwayland:6` | Qt6 Wayland platform plugin | `::gentoo` |
| `dev-qt/qt5compat:6` | Qt6 GraphicalEffects and compatibility modules | `::gentoo` |
| `dev-qt/qtsvg:6` | Qt6 SVG rendering support | `::gentoo` |
| `dev-qt/qtmultimedia:6` | Qt6 multimedia playback engine | `::gentoo` |
| `dev-qt/qtimageformats:6` | Qt6 additional image format plugins | `::gentoo` |

### F. Polkit Authentication Agent
| Package | Description | Source / Repo |
| --- | --- | --- |
| `xfce-polkit` | Lightweight Polkit authentication agent (built from source) | GitHub |

*Build dependencies for `xfce-polkit`:*
- `xfce-base/libxfce4ui`
- `sys-auth/polkit`
- `dev-libs/glib`
- `dev-build/meson`
- `dev-build/ninja`
- `virtual/pkgconfig`

### G. Login Greeter (`greetd` + `noctalia-greeter`)
| Package | Description | Source / Repo |
| --- | --- | --- |
| `gui-libs/greetd` | Minimal and flexible login daemon | `::gentoo` |
| `gui-apps/noctalia-greeter` | Aesthetic greeter matching Noctalia Shell | `::guru` |

### H. Virtual Machine Guest Utilities (VM only)
| Package | Description | Source / Repo |
| --- | --- | --- |
| `app-emulation/qemu-guest-agent` | QEMU Guest Agent service for KVM/Proxmox VMs | `::gentoo` |

---

## 4. Manual Installation via `emerge`

Attempt binary packages first (`--getbinpkg=y`), falling back to source compilation:

```bash
# Core desktop and Wayland essentials
sudo emerge --ask --getbinpkg=y --binpkg-respect-use=y \
    gui-apps/noctalia \
    gui-apps/quickshell \
    gui-apps/uwsm \
    x11-base/xwayland \
    gui-apps/wl-clipboard \
    gui-apps/wl-mirror \
    gui-apps/wlr-randr \
    gui-apps/grim \
    gui-apps/slurp \
    gui-libs/xdg-desktop-portal-wlr \
    sys-apps/xdg-desktop-portal-gtk \
    x11-terms/kitty \
    app-misc/fastfetch \
    app-misc/yazi \
    xfce-base/thunar \
    sys-apps/eza \
    sys-process/htop \
    sys-process/btop \
    app-shells/zoxide \
    media-sound/cava \
    x11-themes/bibata-xcursors \
    gui-apps/qt6ct \
    media-fonts/noto-emoji \
    dev-qt/qtdeclarative:6 \
    dev-qt/qtwayland:6 \
    dev-qt/qt5compat:6 \
    dev-qt/qtsvg:6 \
    dev-qt/qtmultimedia:6 \
    dev-qt/qtimageformats:6 \
    net-misc/socat \
    app-misc/jq \
    dev-vcs/git \
    net-misc/curl \
    net-misc/wget \
    net-misc/rsync
```

---

## 5. Compiling Mango Compositor v0.17.0 from Source

Because Gentoo's GURU repository is currently at v0.16.x, Mango v0.17.0 should be compiled from source:

### 1. Install Build Dependencies
```bash
sudo emerge --ask --getbinpkg=y --binpkg-respect-use=y \
    dev-build/meson \
    dev-build/ninja \
    virtual/pkgconfig \
    dev-libs/wayland \
    dev-libs/wayland-protocols \
    x11-libs/libxkbcommon \
    x11-libs/pixman \
    dev-libs/cJSON \
    dev-libs/libpcre2 \
    dev-libs/libinput \
    dev-libs/glib \
    x11-libs/cairo \
    x11-libs/pango \
    x11-base/xwayland \
    x11-libs/libxcb \
    x11-libs/xcb-util-wm \
    gui-libs/wlroots:0.20 \
    gui-libs/scenefx:0.5
```

### 2. Clone and Compile
```bash
git clone --depth=1 --branch 0.17.0 https://github.com/mangowm/mango.git /tmp/mango-0.17.0
cd /tmp/mango-0.17.0
meson setup build --prefix=/usr/local
ninja -C build
sudo ninja -C build install
sudo ln -sfn /usr/local/bin/mango /usr/bin/mango
sudo ln -sfn /usr/local/bin/mango /usr/local/bin/mangowc
sudo ln -sfn /usr/local/bin/mango /usr/bin/mangowc
sudo ln -sfn /usr/local/bin/mmsg /usr/bin/mmsg
```

### 3. Create Session Wrapper (`/usr/local/bin/mango-session`)
```bash
sudo tee /usr/local/bin/mango-session >/dev/null <<'EOF'
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
EOF
sudo chmod +x /usr/local/bin/mango-session
sudo ln -sfn /usr/local/bin/mango-session /usr/bin/mango-session
```

### 4. Create Desktop Entry (`/usr/share/wayland-sessions/mango.desktop`)
```bash
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/mango.desktop >/dev/null <<'EOF'
[Desktop Entry]
Encoding=UTF-8
Name=Mango
DesktopNames=mango;wlroots
Comment=mango WM
Exec=mango-session
Icon=mango
Type=Application
EOF
```

---

## 6. Compiling `xfce-polkit` from Source

```bash
git clone --depth=1 https://github.com/ncopa/xfce-polkit.git /tmp/xfce-polkit
cd /tmp/xfce-polkit
meson setup build --prefix=/usr/local --libexecdir=libexec
ninja -C build
sudo ninja -C build install
sudo mkdir -p /usr/libexec
sudo ln -sfn /usr/local/libexec/xfce-polkit /usr/libexec/xfce-polkit
sudo ln -sfn /usr/local/libexec/xfce-polkit /usr/bin/xfce-polkit
```
