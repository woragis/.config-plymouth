#!/usr/bin/env bash
# Rebuild assets (optional) + install TN Void two-step theme + refresh initramfs
set -euo pipefail

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  USER_HOME="${HOME}"
fi

THEME_SRC="${USER_HOME}/.config/plymouth/tn-void"
THEME_DST="/usr/share/plymouth/themes/tn-void"
MKINIT="/etc/mkinitcpio.conf"
GRUB_DEFAULT="/etc/default/grub"
BUILD="${USER_HOME}/.config/plymouth/build-tn-void-assets.py"

run() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"
  else sudo "$@"
  fi
}

if [[ "${1:-}" == "--rebuild-assets" ]]; then
  python3 "${BUILD}"
fi

[[ -f "${THEME_SRC}/tn-void.plymouth" ]] || { echo "Missing ${THEME_SRC}/tn-void.plymouth" >&2; exit 1; }
[[ -f "${THEME_SRC}/animation-0001.png" ]] || {
  echo "Missing animation frames — running asset build…"
  python3 "${BUILD}"
}

# Ensure plymouth file exists in src after asset rebuild (build wipes dir!)
if [[ ! -f "${THEME_SRC}/tn-void.plymouth" ]]; then
  echo "ERROR: build wiped tn-void.plymouth — restore from git or recreate" >&2
  exit 1
fi

echo "==> Installing plymouth (if needed)"
run pacman -S --needed --noconfirm plymouth

echo "==> Installing theme → ${THEME_DST}"
run rm -rf "${THEME_DST}"
run mkdir -p "${THEME_DST}"
while IFS= read -r -d '' f; do
  rel="${f#"${THEME_SRC}/"}"
  dest="${THEME_DST}/${rel}"
  run mkdir -p "$(dirname "${dest}")"
  run install -m 644 "${f}" "${dest}"
done < <(find "${THEME_SRC}" -type f -print0)

echo "==> Default theme = tn-void (two-step)"
run plymouth-set-default-theme tn-void
# Verify module
grep -E 'ModuleName|ProgressBarForeground' "${THEME_DST}/tn-void.plymouth"

echo "==> Ensure plymouth AFTER encrypt in mkinitcpio"
run cp "${MKINIT}" "${MKINIT}.bak.plymouth-$(date +%Y%m%d%H%M)"
if grep -q '^HOOKS=' "${MKINIT}"; then
  # normalize: remove plymouth then insert after encrypt
  run sed -i -E 's/[[:space:]]*plymouth[[:space:]]*/ /g' "${MKINIT}"
  run sed -i 's/encrypt /encrypt plymouth /' "${MKINIT}"
fi
grep '^HOOKS=' "${MKINIT}"

echo "==> Ensure splash on cmdline"
if ! grep -q 'splash' "${GRUB_DEFAULT}"; then
  run sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash"/' "${GRUB_DEFAULT}"
fi

echo "==> Rebuild initramfs + grub"
run mkinitcpio -P
run grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "Done. You should see a spinning gear + cyan progress on boot (after LUKS)."
echo "Preview from TTY:  sudo plymouthd --mode=boot --pid-file=/run/plymouth.pid; sudo plymouth --show-splash; sleep 6; sudo plymouth --quit"
