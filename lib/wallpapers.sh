#!/usr/bin/env bash
# ==================================================
#  MamgoDOTS - (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
# ==================================================

set -euo pipefail

prompt_wallpapers() {
    local pictures_dir
    pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "${HOME}/Pictures")"
    local target_dir="${pictures_dir}/wallpapers"

    echo ""
    log_info "Wallpaper Bank download option:"

    while true; do
        echo -e "${NOTE} A number of these wallpapers are AI generated or enhanced. Select (N/n) if this is an issue for you."
        echo -ne "${CAT} Would you like to download additional wallpapers? ${WARN} This is ~1GB in size (y/n): "
        read -r answer
        answer="$(echo "${answer}" | tr '[:upper:]' '[:lower:]')"

        case "${answer}" in
            y|yes)
                log_info "Downloading additional wallpapers from Wallpaper-Bank..."
                local tmp_repo_dir
                tmp_repo_dir="/tmp/Wallpaper-Bank-$$"
                rm -rf "${tmp_repo_dir}"

                if git clone --depth 1 "https://github.com/LinuxBeginnings/Wallpaper-Bank.git" "${tmp_repo_dir}" 2>&1 | tee -a "${LOG_FILE}"; then
                    mkdir -p "${target_dir}"
                    if [[ -d "${tmp_repo_dir}/wallpapers" ]]; then
                        cp -rn "${tmp_repo_dir}/wallpapers/"* "${target_dir}/" 2>/dev/null || cp -r "${tmp_repo_dir}/wallpapers/"* "${target_dir}/"
                    else
                        cp -rn "${tmp_repo_dir}/"* "${target_dir}/" 2>/dev/null || cp -r "${tmp_repo_dir}/"* "${target_dir}/"
                    fi
                    log_ok "Wallpapers installed successfully to ${target_dir}."
                    rm -rf "${tmp_repo_dir}"
                    break
                else
                    log_err "Failed to download wallpapers from repository."
                    rm -rf "${tmp_repo_dir}"
                    break
                fi
                ;;
            n|no|"")
                log_info "Skipping additional wallpaper download."
                break
                ;;
            *)
                echo -e "${WARN} Please enter 'y' or 'n'."
                ;;
        esac
    done
}
