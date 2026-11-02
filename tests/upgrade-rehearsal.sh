#!/usr/bin/env bash
# ==================================================
#  MangoWC - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================
#  Upgrade rehearsal: v0.1.x (.conf) -> current (TOML)
#
#  Seeds a throwaway $HOME with the pre-0.18 .conf layout, runs the real
#  deploy_dotfiles() and reload.sh from this repository, then asserts the
#  result. Everything happens inside a mktemp directory; no sudo, no package
#  installation, no running compositor required.
#
#  Usage: ./tests/upgrade-rehearsal.sh
# ==================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "${TMP_HOME}"' EXIT

CONFIG_HOME="${TMP_HOME}/.config"
MANGO_DIR="${CONFIG_HOME}/mangowc"

FAILURES=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*" >&2; FAILURES=$((FAILURES + 1)); }

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'missing required command: %s\n' "$1" >&2
        exit 2
    fi
}

# --------------------------------------------------
# Seed a v0.1.x style configuration
# --------------------------------------------------
seed_legacy_config() {
    mkdir -p "${MANGO_DIR}" "${CONFIG_HOME}/kitty"

    printf 'blur=1\n' > "${MANGO_DIR}/config.conf"
    printf 'bind=SUPER,Return,spawn,kitty\n' > "${MANGO_DIR}/bind.conf"
    printf 'env=MANGO_DEFAULT_LAYOUT,scroller\n' > "${MANGO_DIR}/env.conf"
    printf 'monitorrule=name:.*,width:0\n' > "${MANGO_DIR}/monitor.conf"
    printf 'tagrule=id:1,layout_name:scroller\n' > "${MANGO_DIR}/tag.conf"
    printf 'windowrule=title:old-floating\n' > "${MANGO_DIR}/rule.conf"
    printf 'root_color=0xffffffff\n' > "${MANGO_DIR}/noctalia.conf"
    printf 'user-edit\n' > "${CONFIG_HOME}/kitty/kitty.conf"
}

# --------------------------------------------------
# Run the real deploy_dotfiles(), extracted from install.sh so the test
# never drifts from the shipped code. Only the logging helpers are stubbed.
# --------------------------------------------------
run_deploy() {
    local harness="${TMP_HOME}/deploy-harness.sh"

    {
        cat <<'EOF'
set -euo pipefail
log_info()  { printf '[INFO] %s\n' "$*"; }
log_ok()    { printf '[OK] %s\n' "$*"; }
log_warn()  { printf '[WARN] %s\n' "$*"; }
log_debug() { :; }
EOF
        awk '/^backup_path\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "${REPO_ROOT}/lib/common.sh"
        awk '/^deploy_dotfiles\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "${REPO_ROOT}/install.sh"
        printf '\ndeploy_dotfiles\n'
    } > "${harness}"

    if grep -q 'deploy_dotfiles()' "${harness}" && grep -q 'backup_path()' "${harness}"; then
        ok "extracted backup_path() and deploy_dotfiles() from the repo"
    else
        bad "could not extract functions (did the function layout change?)"
        return 1
    fi

    if HOME="${TMP_HOME}" SCRIPT_DIR="${REPO_ROOT}" bash "${harness}" > "${TMP_HOME}/deploy.log" 2>&1; then
        ok "deploy_dotfiles completed"
    else
        bad "deploy_dotfiles failed"
        sed 's/^/        /' "${TMP_HOME}/deploy.log" >&2
        return 1
    fi
}

# --------------------------------------------------
# Assertions on the deployed tree
# --------------------------------------------------
check_deployed_tree() {
    local conf leftover=0

    for conf in config bind env monitor tag rule noctalia; do
        if [[ -f "${MANGO_DIR}/${conf}.toml" ]]; then
            :
        else
            bad "missing ${conf}.toml"
        fi
        if [[ -e "${MANGO_DIR}/${conf}.conf" ]]; then
            leftover=$((leftover + 1))
        fi
    done

    if [[ "${leftover}" -eq 0 ]]; then
        ok "no stale .conf files remain (mango would prefer config.conf)"
    else
        bad "${leftover} stale .conf file(s) survived deployment"
    fi

    local backup
    backup="$(find "${CONFIG_HOME}" -maxdepth 1 -type d -name 'mangowc-backup-*' -print -quit 2>/dev/null || true)"
    if [[ -n "${backup}" && -f "${backup}/config.conf" ]]; then
        ok "legacy config preserved in $(basename "${backup}")"
    else
        bad "no mangowc-backup-* directory holding the old config.conf"
    fi

    local kitty_backup
    kitty_backup="$(find "${CONFIG_HOME}" -maxdepth 1 -type d -name 'kitty-mangowc-*' -print -quit 2>/dev/null || true)"
    if [[ -n "${kitty_backup}" && -f "${kitty_backup}/kitty.conf" ]]; then
        ok "pre-existing kitty config backed up"
    else
        bad "kitty config was not backed up"
    fi

    if [[ "$(readlink "${CONFIG_HOME}/mango" 2>/dev/null || true)" == "mangowc" ]]; then
        ok "~/.config/mango symlink points at mangowc"
    else
        bad "~/.config/mango symlink missing or wrong target"
    fi
}

# --------------------------------------------------
# reload.sh must propagate MANGO_DEFAULT_LAYOUT into every tag rule
# --------------------------------------------------
check_layout_sync() {
    sed -i 's/^"MANGO_DEFAULT_LAYOUT" = "dwindle"/"MANGO_DEFAULT_LAYOUT" = "tile"/' "${MANGO_DIR}/env.toml"

    # Restricted PATH keeps mmsg (a real compositor socket client) out of reach
    PATH="/usr/bin:/bin" HOME="${TMP_HOME}" bash "${MANGO_DIR}/bin/reload.sh" \
        > "${TMP_HOME}/reload.log" 2>&1 || true

    local tile_count total other_count
    tile_count="$(grep -c 'layout_name = "tile"' "${MANGO_DIR}/tag.toml" || true)"
    total="$(grep -c 'layout_name' "${MANGO_DIR}/tag.toml" || true)"
    other_count=$((total - tile_count))

    if [[ "${tile_count}" -eq 9 && "${other_count}" -eq 0 ]]; then
        ok "reload.sh synced MANGO_DEFAULT_LAYOUT=tile to all 9 tag rules"
    else
        bad "layout sync wrong: ${tile_count} tile rule(s), ${other_count} other(s)"
    fi
}

# --------------------------------------------------
# Optional: validate the deployed config with a real mango binary
# --------------------------------------------------
check_with_mango() {
    if ! command -v mango >/dev/null 2>&1; then
        printf '  skip  mango not installed; config not validated by the compositor\n'
        return 0
    fi

    local out rc
    set +e
    out="$(mango -p -c "${MANGO_DIR}/config.toml" 2>&1)"
    rc=$?
    set -e

    if [[ "${rc}" -eq 0 && -z "${out}" ]]; then
        ok "mango -p accepted the deployed config ($(mango -v 2>&1 | head -n1))"
    else
        bad "mango -p rejected the deployed config"
        printf '%s\n' "${out}" | sed 's/^/        /' >&2
    fi
}

main() {
    require_cmd awk
    require_cmd find
    require_cmd mktemp

    printf 'Upgrade rehearsal (v0.1.x -> current) in %s\n' "${TMP_HOME}"
    printf 'Repository: %s\n\n' "${REPO_ROOT}"

    seed_legacy_config
    ok "seeded legacy .conf configuration"

    if ! run_deploy; then
        printf '\nFAILED: deployment did not complete.\n' >&2
        exit 1
    fi

    check_deployed_tree
    check_layout_sync
    check_with_mango

    if [[ "${FAILURES}" -eq 0 ]]; then
        printf '\nAll upgrade rehearsal checks passed.\n'
        exit 0
    fi

    printf '\n%d check(s) failed.\n' "${FAILURES}" >&2
    exit 1
}

main "$@"
