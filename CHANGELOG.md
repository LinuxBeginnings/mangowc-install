# CHANGELOG.MD

## MangoWC-Dots -- Current version v0.1.1

- A simple installer to install mangowc compositor on different distros
- Using the noctalia shell by default
- Distros:
  - Gentoo Linux
  - Fedora 44+
  - Arch
  - Debian
  - Ubuntu 26.04+

## Sept 2026

- Initial commit 9/9/2026

## Fixed / Added:

- Gentoo Linux Distribution Support (`distros/gentoo/`, `lib/detect.sh`, `README.md`)
  - Added Gentoo Linux detection in `lib/detect.sh` and VM `qemu-guest-agent` setup
  - Created `distros/gentoo/setup.sh` to configure repositories and overlays:
    - Automatically checks for and enables the `guru` overlay via `eselect repository` or direct repos.conf definition
    - Detects if global testing keywords (`~amd64` / `~arch`) are enabled; if not, automatically configures `/etc/portage/package.accept_keywords/mangowc` for required GURU and bleeding-edge packages
    - Configures `/etc/portage/package.use/mangowc` to enable `media-video/ffmpeg vulkan` for hardware-accelerated screen recording
  - Created `distros/gentoo/packages.sh`:
    - Fast package presence checking (`pkg_is_installed`) using `qlist`, `equery`, and `/var/db/pkg`
    - Implemented `pkg_install` attempting binary packages first (`emerge --getbinpkg=y --binpkg-respect-use=y`) and falling back seamlessly to compiling from source
    - Compiles Mango compositor v0.17.0 from source (`https://github.com/mangowm/mango.git`) against Gentoo's `wlroots-0.20` and `scenefx-0.5`
    - Compiles `xfce-polkit` authentication agent from source with symlinks in `/usr/libexec` and `/usr/bin`
    - Portage-first installation of `gpu-screen-recorder` with automated Flatpak fallback
    - Installs and verifies `greetd` and `noctalia-greeter` with automated `noctalia-greeter-session` wrapper generation
    - Clean uninstallation routine (`uninstall_packages`) supporting `emerge --depclean` and binary cleanup
  - Created `distros/gentoo/Gentoo-Packages-Needed.md`:
    - Comprehensive guide detailing all Gentoo package categories and names
    - Manual Portage installation instructions, testing keyword settings, and source build instructions for Mango v0.17.0

- Pre-Installation Presence Verification (`install.sh`)
  - Added verification checks before attempting package installation to inspect if `mango`, `mangowc`, `noctalia`, or `quickshell` are already present on the system
  - Added presence verification check before calling `install_greeter_packages` to skip package re-installation if `greetd` and `noctalia-greeter` already exist

- Version Bump to 0.1.1 (`install.sh`, `lib/common.sh`, `configs/mangowc/autostart.sh`, `configs/mangowc/env.conf`, `CHANGELOG.md`)
  - Synchronized `MANGO_DOTS_VERSION="0.1.1"` across all scripts, libraries, autostart, and environment files

- `WLR_NO_HARDWARE_CURSORS` was allways set
  - Now just for VMs and NVIDIA
- Added rule to float and center the settings panel for Noctalia
- In VMs `qemu-guest-agent` is installed
- Wayland VM Hardware Cursor & Upside-Down Pointer Fix (`configs/mangowc/env.conf`, `configs/mangowc/autostart.sh`, `lib/detect.sh`, `lib/greeter.sh`, `distros/*/packages.sh`)
  - Fixed inverted cursor on QEMU / KVM VirtIO GPU by enforcing `WLR_NO_HARDWARE_CURSORS=1` across compositor environment (`env.conf`), user session autostart, and desktop session scripts
  - Sanitized `/etc/environment` formatting in `lib/detect.sh` to remove invalid `export` statements that prevented `pam_env` and `systemd-environment-d-generator` from loading variables
  - Configured systemd service drop-in override (`/etc/systemd/system/greetd.service.d/override.conf`) in `lib/greeter.sh` so `greetd` and `noctalia-greeter` inherit `WLR_NO_HARDWARE_CURSORS=1`
  - Added `pam_env.so` and `pam_gnome_keyring.so` to `/etc/pam.d/greetd` and `/etc/pam.d/greetd-greeter` to load system environment variables and auto-unlock the user keyring on login
  - Updated `distros/debian/packages.sh` and `distros/ubuntu/packages.sh` to mirror `mango.desktop` to `/usr/local/share/wayland-sessions/` pointing to `mango-session` to ensure session environment wrappers are not bypassed

- Noctalia Shell Virtual Machine D-Bus Timeout & Keybinding Fix (`lib/detect.sh`, `configs/mangowc/bind.conf`)
  - Added automated detection in `lib/detect.sh` to mask `bluetooth.service` when running inside virtual machines without physical Bluetooth hardware (`/sys/class/bluetooth`), preventing a 25-second blocking `org.bluez` D-Bus timeout that froze Noctalia Shell startup
  - Corrected keybinding typo in `configs/mangowc/bind.conf` (`bind=SUPER+SHIFT,M,quit` instead of invalid `SUPER+SHFT,rqm,quit`) to resolve configuration syntax check errors (`mango -p`)

- Debian Testing (Forky/Sid) Native Wlroots 0.20 & Noctalia Greeter Support (`distros/debian/packages.sh`, `distros/debian/setup.sh`)
  - Integrated Debian testing's native `libwlroots-0.20-dev` (v0.20.2) and `libscenefx-0.5-dev` (v0.5.0) packages directly into `build_deps` and `greeter_deps`
  - Enables native compilation of MangoWC v0.17.0 and `noctalia-greeter` without manual source builds of wlroots or scenefx
  - Cleaned up ButterRepo source lists automatically on Forky to avoid ABI conflicts with testing's Wayland 1.26 / Qt 6.10 stack

- Universal Uninstallation Option (`install.sh`, `lib/common.sh`, `distros/*/packages.sh`, `README.md`)
  - Added `-u, --uninstall` flag across all supported distributions (Arch, Debian, Fedora, Ubuntu)
  - Reverts login manager setup by running `remove_noctalia_greeter` and restoring previous display manager (SDDM/GDM/LightDM)
  - Automatically uninstalls distro packages (`mangowm`, `noctalia`, `noctalia-greeter`, Flatpak `gpu-screen-recorder`) and source binaries/wrappers
  - Removes deployed dotfiles (`~/.config/mangowc`, `~/.config/mango`, `~/.config/noctalia`) and restores previous user backups (e.g. `kitty-mangowc-*`, `fastfetch-mangowc-*`, `yazi-mangowc-*`)

- Version Synchronization (`install.sh`, `lib/common.sh`, `configs/mangowc/autostart.sh`, `configs/mangowc/env.conf`)
  - Synchronized `MANGO_DOTS_VERSION="0.0.4"` across installer scripts, shared libraries, environment configuration, and session autostart

- Rustup & Cargo Toolchain Setup Check (`lib/common.sh`, `distros/*/packages.sh`)
  - Added `check_rustup_cargo` to verify whether `rustup default stable` has been run when rustup is present, automatically configuring the default stable toolchain to finish Cargo installation across all distributions

- Added `cava` Audio Visualizer Package (`distros/*/packages.sh`, `README.md`)
  - Added `cava` console audio visualizer to core package lists across Arch, Debian, Fedora, and Ubuntu distributions

- Default Monitor Rule for Virtual Displays (`configs/mangowc/monitor.conf`)
  - Added specific monitor rule `monitorrule=name:Virtual-1,width:1920,height:1080,refresh:60,x:0,y:0,scale:1.0,vrr:0` to ensure 1080p60 on QEMU/KVM virtual machine outputs instead of fallback sub-1080p preferred modes

- Noctalia Greeter Detection & Installation Safety Guards (`lib/greeter.sh`, `install.sh`, `distros/debian/packages.sh`, `distros/ubuntu/packages.sh`)
  - Added binary existence verification (`is_noctalia_greeter_installed`) before configuring `greetd` to prevent broken `/etc/greetd/config.toml` setups and graphical login lockouts
  - In `lib/greeter.sh`, aborts greetd setup and preserves existing display managers if `noctalia-greeter-session` is not installed or failed to compile
  - Displays current greeter installation status in `prompt_greeter_action` menu and final `install.sh` installation summary
  - Added explicit warnings and failure return code when greeter compilation is skipped on unsupported platforms (such as Debian 13 Trixie)
  - Fixed missing build dependencies (`libinput-dev`, `libdrm-dev`, `libgbm-dev`, `libseat-dev`, `libdisplay-info-dev`, `libliftoff-dev`, `libpixman-1-dev`) in Ubuntu and Debian greeter package routines
  - Added post-installation package verification check for Noctalia greeter alongside shell, Quickshell, and Mango

- Debian Trixie (13) & Forky/Sid Differential Support (`distros/debian/`, `lib/detect.sh`)
  - Added Debian codename detection (`trixie`, `forky`, `sid`) via `VERSION_CODENAME`, `DEBIAN_CODENAME`, `/etc/debian_version`, and release names in `lib/detect.sh`, exporting `DETECTED_CODENAME`
  - Debian 13 (Trixie):
    - Configured ButterRepo (`https://apt.justaguy.dev`) and GPG signing key (`/usr/share/keyrings/butterrepo.gpg`) to install precompiled `mangowc` (v0.14.4 built against wlroots 0.19 and scenefx 0.4) via APT
    - Enabled `trixie-backports` repository to supply dependencies like `uwsm`
    - Upgraded `wayland-protocols` from `trixie-backports` (v1.47+) to provide `ext-background-effect-v1.xml` required by Noctalia shell v5 (missing in Debian 13's base v1.44) with automated protocol fetch fallback
    - Skipped `noctalia-greeter` compilation with warning due to wlroots 0.20 incompatibility with Trixie's native Wayland stack
  - Debian 14 (Forky) / Sid:
    - Removed ButterRepo if present to prevent ABI conflicts with newer Wayland stacks
    - Compiles `mangowc` v0.17.0 and `noctalia-greeter` from source
  - Added `xfce-polkit` source compilation fallback (`install_xfce_polkit`) when not found in path or libexec, with symlinks in `/usr/libexec/`, `/usr/local/bin/`, and `/usr/bin/`
  - Added `quickshell` desktop shell toolkit package to Debian core packages list
  - Added Debian to the supported distros list in unsupported distro detection warnings

- Noctalia Duplicate Bar Fix
  - Renamed `[bar.main]` to `[bar.default]` in `configs/noctalia/settings.toml` to prevent Noctalia from spawning a second bar alongside its default/state bar on existing installations.

- Volume knob bindings

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
