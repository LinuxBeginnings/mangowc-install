# CHANGELOG.MD

## MangoWC-Dots -- Current version v0.0.3

- A simple installer to install mangowc compositor on different distros
- Using the noctalia shell by default
- Distros:
  - Fedora 44+
  - Arch
  - Debian
  - Ubuntu 26.04+

## Sept 2026

- Initial commit 9/9/2026

## Fixed / Added:

- Default rules: 
  - Google Chrome on Tag 2 
  - Discovery on Tag 3 
  - OBS studio on Tag 9 

- Hot spot 
  - Move mouse to lower left corner to activate overview mode

- Passthrough Mode Submap (`keymode`)
  - Added a passthrough submap (`keymode=passthrough`) in `configs/mangowc/bind.conf` that temporarily disables host-level keyboard and mouse bindings so input passes directly through to guest applications (such as virtual machines, `remote-viewer`, RDP, or VNC).
  - Enable: Press `SUPER + P` to enter passthrough mode.
  - Disable: Press `SUPER + Escape` to return to default host control.

- Default Layout Changed to Dwindle
  - Switched `MANGO_DEFAULT_LAYOUT` from `scroller` to `dwindle` in `configs/mangowc/env.conf`
  - Updated all nine `tagrule` layout entries in `configs/mangowc/tag.conf` to use `dwindle`
  - Updated `install.sh` fallback default layout from `scroller` to `dwindle`

- `install.sh --deps`
  - Added `--deps` flag to add new packages if needed as project progresses
- GPU Screen Recorder (`gpu-screen-recorder`)
  - Added `gpu-screen-recorder` installation across all distros.
  - Arch installs it from the official repositories; Fedora from the Terra repository.
  - Ubuntu and Debian install it via Flatpak (the official recommended method for non-Arch distros), since it is not packaged in their repositories.
  - Added runtime checks that install Flatpak if missing and register the Flathub remote if not already configured, then install `com.dec05eba.gpu_screen_recorder` system-wide.
  - Note: the Flatpak build bundles a patched, statically-linked FFmpeg (equivalent to the source build's `-Dffmpeg_static=true`), which also supports older NVIDIA GPUs.

- Noctalia Update Utility (`--update-noctalia`)
  - Added `--update-noctalia` command line flag to `install.sh`
  - Added `lib/update.sh` to query installed vs. latest GitHub releases/tags for `noctalia` and `noctalia-greeter`
  - Added formatted comparison table displaying Installed Version, Updated Version, and Status
  - Added interactive `Y/n` prompt to perform automated upgrades across supported distros

- Greetd & Display Manager Session Fixes (`lib/greeter.sh`)
  - Removed `--now` flag from `systemctl disable` and `systemctl enable` calls across all distros to avoid abruptly closing active graphical sessions and killing the installer
  - Configured `vt = 7` on Debian and Ubuntu to match `greetd.service` (`Conflicts=getty@tty7.service`) and prevent `getty@tty1.service` from resetting the terminal and killing the session
  - Updated `/etc/greetd/config.toml` session path and desktop session launching
  - Added `sudo` group support alongside `wheel` to `/etc/polkit-1/rules.d/50-noctalia-greeter.rules` for Debian and Ubuntu

- Ubuntu 26.04+ Support (`distros/ubuntu/`)
  - Added full Ubuntu support with minimum version enforcement (`>= 26.04`, exits on `< 26.04`) in `lib/detect.sh`
  - Created `distros/ubuntu/setup.sh` to configure repositories and prevent incompatible Debian Trixie ButterRepo packages (which caused Qt 6.8 vs. 6.10 private ABI and `libdisplay-info2` vs. `libdisplay-info3` conflicts)
  - Created `distros/ubuntu/packages.sh` with safe APT candidate checking (`pkg_in_repos` and `pkg_can_install`)
  - Added automated build/installation for `mango` (mangowc) and `scenefx 0.4.1` against native `libwlroots-0.19`
  - Added automated build/installation for `noctalia` desktop shell (v5.1.0) with complete assets
  - Added automated build/installation for `noctalia-greeter` (v1.5.0) with bundled `wlroots 0.20`
  - Deployed `/usr/bin/` symlinks for `mango`, `mangowc`, `mango-session`, `mmsg`, `noctalia`, `noctalia-greeter`, and `noctalia-greeter-session`
  - Added `uwsm` to core packages to support UWSM-managed Wayland desktop sessions

- Debian Support (`distros/debian/`)
  - Created `distros/debian/setup.sh` and updated `distros/debian/packages.sh`
  - Added automated build and install routines for `mango` (mangowc), `noctalia` shell, and `noctalia-greeter`
  - Added `pkg_in_repos` and `pkg_can_install` dry-run checks to prevent APT solver aborts on missing packages
  - Ensured identical `/usr/bin/` binary symlinks and `uwsm` support

- Mango Configuration & Monitor Settings
  - Compiled `mango` and `mmsg` natively from source against Ubuntu's native `libwayland-server` and `libwlroots-0.19` stack to resolve ABI mismatch segfault in `libwayland-server.so`
  - Fixed PCRE2 regex pattern in `monitor.conf` (`name:.*` instead of invalid quantifier `name:*`)
  - Updated `configs/mangowc/monitor.conf` to use native preferred resolution and refresh rate (`width:0,height:0,refresh:0`) instead of forcing 1080p60 on high-resolution/high-refresh displays
  - Added default Noctalia shell configuration (`configs/noctalia/config.toml`) and integrated into `deploy_dotfiles`
  - Fixed Kitty per-process listen socket (`listen_on unix:/tmp/kitty-{kitty_pid}`) and font family (`FiraCode Nerd Font`)
  - Updated `autostart.sh` with `dbus-update-activation-environment` and removed conflicting manual portal launches
  - Fixed `mango-session` to look in `/usr/local/bin/mango` in addition to `/usr/bin/mango`
  - Synchronized `MANGO_DOTS_VERSION="0.0.2"` across `install.sh` and `lib/common.sh`

- Arch Install
  - Fixed packages to be installed
  - `install.sh` now supports `yay` or `paru`

- Polkit Escalation Issues
  - Check for hyprlandpolkit service and stop it for Mango sessions
  - Added `xfce-polkit` to handle GUI priv escalation requests
  - Added Polkit rules for noctalia-greeter wallpaper sync feature
