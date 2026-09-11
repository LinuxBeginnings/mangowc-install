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

- Polkit escalation issues
  - Check for hyprlandpolkit service
    - stop service
  - Added `xfce-polkit` to handle GUI priv escalation requests
    - Added polkit rules for noctalia greeter wallpaper sync feature
