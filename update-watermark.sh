#!/usr/bin/env bash
# Push updated watermark (orion) into installed Plymouth theme + refresh initramfs
set -euo pipefail

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  USER_HOME="${HOME}"
fi

SRC="${USER_HOME}/.config/plymouth/tn-void/watermark.png"
DST="/usr/share/plymouth/themes/tn-void/watermark.png"

run() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"
  else sudo "$@"
  fi
}

[[ -f "${SRC}" ]] || { echo "Missing ${SRC}" >&2; exit 1; }
run install -m 644 "${SRC}" "${DST}"
run plymouth-set-default-theme tn-void
run mkinitcpio -P
echo "Watermark updated to orion + initramfs rebuilt."
