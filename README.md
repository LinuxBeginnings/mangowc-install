<div align="center">

# 🥭 ** MangoWC-Dots - (2026) ** 🥭

### Minimal & Extensible Wayland Compositor Setup with Noctalia Shell

<p align="center">
  <img src="https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/assets/latte.png" width="400" />
</p>

[![LinuxBeginnings](https://img.shields.io/badge/LinuxBeginnings-Community-blue?style=for-the-badge)](https://github.com/LinuxBeginnings)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green.svg?style=for-the-badge)](https://www.gnu.org/licenses/gpl-3.0)
<a href="https://discord.gg/RZJgC7KAKm"><img src="https://img.shields.io/discord/1151869464405606400?style=for-the-badge&logo=discord&color=cba6f7&label=Discord" /></a>

<br/>

<div align="center">
  <a href="#-overview"><kbd> <br> Overview <br> </kbd></a>&ensp;&ensp;
  <a href="#-features"><kbd> <br> Features <br> </kbd></a>&ensp;&ensp;
  <a href="#-installation"><kbd> <br> Installation <br> </kbd></a>&ensp;&ensp;
  <a href="#-configuration-colocation"><kbd> <br> Configuration <br> </kbd></a>&ensp;&ensp;
  <a href="#-greeter-integration"><kbd> <br> Greeter <br> </kbd></a>
</div>

<br/>
</div>

---

## 📖 Overview

**MangoWC - (2026)** is an extensible, multi-distribution installer engineered for a minimal, lightning-fast Wayland desktop environment pairing the **Mango** Wayland compositor with **Noctalia Shell**, styled with **Kitty** terminal and **Fastfetch**.

Unlike bloated scripts that install dozens of non-essential applications, this installer focuses strictly on core desktop components, Wayland essentials, and streamlined configuration.

---

## ✨ Features

- **Lean Core Desktop:** Zero bloat. Installs only `mangowc`, `noctalia`, `quickshell`, `kitty`, file management (`thunar`, `yazi`), terminal productivity utilities (`eza`, `htop`, `btop`, `zoxide`), and essential Wayland portals/utilities. No NVIDIA proprietary builds, no OBS, and no heavy unnecessary apps.
- **Quickshell Ecosystem Ready:** Pre-configures the Quickshell COPR repository and all necessary Qt6/QML dependencies (`qt6-qtdeclarative`, `qt6-qtwayland`, `qt6-qt5compat`, `qt6-qtsvg`, `qt6-qtmultimedia`, `qt6-qtimageformats`, `socat`, `jq`) so you can run custom Quickshell bars, overviews, and widgets out of the box.
- **Pure Kitty Integration:** All keybindings and configs are unified around `kitty` — foot and foot-client configs are eliminated.
- **Config Colocation:** Keeps all Mango configurations and related application configurations consolidated under `~/.config/mangowc/` (including `kitty.conf`), maintaining clean compatibility via a `~/.config/mango -> mangowc` symlink.
- **Safe Automatic Backups:** Automatically backs up modified directories prior to installation with timestamps (e.g. `~/.config/fastfetch` ➔ `~/.config/fastfetch-mangowc-<timestamp>`).
- **Noctalia Greeter & greetd:** Optional interactive or command-line installation and rollback management for `noctalia-greeter` on `greetd`.
- **Wallpaper-Bank Download Prompt:** Features the LinuxBeginnings interactive prompt for downloading wallpapers, complete with AI-generated content disclosures and download size warnings.
- **Modular Multi-Distro Engine:** Shared libraries under `lib/` (`common.sh`, `detect.sh`, `greeter.sh`, `wallpapers.sh`) with distro-isolated packages and setups under `distros/<distro>/`.
- **Debugging & Logging:** Detailed logging to `Install-Logs/install-<timestamp>.log` with an optional `--debug` flag for verbose execution.

---

## 🚀 Installation

Clone this repository and run the installer:

```bash
git clone https://github.com/LinuxBeginnings/mangowc.git
cd mangowc
chmod +x install.sh
./install.sh
```

### CLI Options

The installer supports several non-interactive and debugging flags:

| Flag | Description |
| --- | --- |
| `-d`, `--debug` | Enable verbose shell tracing (`set -x`) and detailed debug logs |
| `--install-greeter` | Non-interactively configure `greetd` with `noctalia-greeter` |
| `--remove-greeter` | Restore previous display manager / `greetd` configuration |
| `--skip-greeter` | Skip login manager / greeter configuration |
| `--no-wallpapers` | Bypass wallpaper bank download prompt |
| `-h`, `--help` | Display usage options |

---

## 📁 Directory Architecture

```
mangowc/
├── install.sh                  # Main orchestrator
├── README.md                   # Documentation
├── lib/                        # Multi-distro common libraries
│   ├── common.sh               # Colors, logging, sudo keepalive, backup helpers
│   ├── detect.sh               # /etc/os-release parsing and distro matcher
│   ├── greeter.sh              # greetd + noctalia-greeter installation & rollback
│   └── wallpapers.sh           # Wallpaper-Bank cloning with AI warning
├── distros/                    # Distribution-specific modules
│   ├── fedora/
│   │   ├── packages.sh         # Lean package lists (mangowm, noctalia, kitty)
│   │   └── setup.sh            # DNF parallel downloads & Terra/RPM Fusion repos
│   ├── arch/                   # Modular stub for Arch Linux
│   └── debian/                 # Modular stub for Debian/Ubuntu
└── configs/
    ├── fastfetch/
    │   └── config.jsonc        # Standard hardware & software fetch layout
    ├── greetd/
    │   └── config.toml         # greetd configuration template
    └── mangowc/                # Target: ~/.config/mangowc/
        ├── autostart.sh        # Portal & Noctalia startup
        ├── bind.conf           # Clean Kitty & Noctalia keybindings
        ├── config.conf         # Mango compositor config
        ├── env.conf            # Dynamic Wayland environment
        ├── kitty.conf          # Noctalia-themed Kitty terminal
        ├── monitor.conf        # Display rules
        ├── noctalia.conf       # Theme colors
        ├── rule.conf           # Window rules (floating-kitty, etc.)
        ├── tag.conf            # Workspace tag layout
        └── bin/                # Helper scripts
            ├── reload.sh       # Mango & Noctalia reloader
            ├── screenshot.sh   # Grim + Slurp screenshot tool
            ├── set-icons       # Tela icon switcher
            └── toggle-outer-gaps.sh
```

---

## 🗂 Configuration Colocation

All configuration files reside in `~/.config/mangowc/`:

- Terminal launches: `kitty --config ~/.config/mangowc/kitty.conf`
- Mango symlink: `~/.config/mango` points directly to `~/.config/mangowc`
- To reload your setup on the fly: press `Super + Alt + R` or execute `~/.config/mangowc/bin/reload.sh`.

---

## 🔐 Greeter Integration

When `noctalia-greeter` is selected, `greetd` is configured to launch:
```toml
[default_session]
command = "noctalia-greeter-session -- --session mango"
user = "greeter"
```
Avatars and themes will automatically reflect the user's settings when AccountsService is active. To revert back to your previous display manager configuration, run:
```bash
./install.sh --remove-greeter
```

---

<div align="center">
  <sub>Maintained by the <strong>LinuxBeginnings</strong> project.</sub>
</div>
