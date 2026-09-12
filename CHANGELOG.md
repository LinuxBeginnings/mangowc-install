# CHANGELOG.MD

## MangoWC-Dots -- Current version v0.0.2

- A simple installer to install mangowc compositor on differnt distros
- Using the noctalia shell by default
- Distros:
  - Fedora 44+
    - Only one tested thus far
  - Arch
    - Not tested
  - Debian/Ubuntu
    - Mot tested
    - Also likely to have version issues
      - Likely only Debian Forky+
      - Ubuntu 26.04.1+

## Sept 2026

- Initial commit 9/9/2026

## Fixed:

- Greetd / Display Manager Handling
  - Removed `--now` flag when disabling competing display managers and enabling `greetd.service` across all distros
  - Prevents killing active graphical sessions and abruptly terminating `install.sh` during greeter setup
- Debian Install
  - Added `distros/debian/setup.sh` and updated `distros/debian/packages.sh`
  - Added automated build/installation for `mango` (mangowc) and `noctalia-greeter` on Debian
  - Added `pkg_in_repos` and `pkg_can_install` safety checks to prevent package installation aborts
- Ubuntu Install
  - Added support for Ubuntu 26.04+
  - Enforced minimum required version 26.04 (exits with error on < 26.04)
  - Added automated build/installation for `mango` (mangowc) and `noctalia-greeter` on Ubuntu 26.04
  - Updated noctalia-greeter Polkit rule to permit `sudo` group for Ubuntu/Debian
- Arch Install
  - Fixed packages to be installed
  - `install.sh` now supports `yay` or `paru`
- Polkit escalation issues
  - Check for hyprlandpolkit service
    - stop service
  - Added `xfce-polkit` to handle GUI priv escalation requests
    - Added polkit rules for noctalia greeter wallpaper sync feature
