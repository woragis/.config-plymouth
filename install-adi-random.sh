#!/usr/bin/env bash
# Install adi1090x plymouth themes + enable a random theme each boot.
# Themes: https://github.com/adi1090x/plymouth-themes
set -euo pipefail

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  USER_HOME="${HOME}"
fi

CFG="${USER_HOME}/.config/plymouth"
THEMES_SRC="${CFG}/themes"
POOL_SRC="${CFG}/theme-pool"
INITCPIO_SRC="${CFG}/initcpio"
MKINIT="/etc/mkinitcpio.conf"
GRUB_DEFAULT="/etc/default/grub"

run() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"
  else sudo "$@"
  fi
}

[[ -f "$POOL_SRC" ]] || { echo "Missing $POOL_SRC" >&2; exit 1; }
[[ -d "$THEMES_SRC" ]] || { echo "Missing $THEMES_SRC" >&2; exit 1; }

mapfile -t THEMES < <(grep -vE '^\s*(#|$)' "$POOL_SRC" | tr -d ' \t\r')
[[ ${#THEMES[@]} -gt 0 ]] || { echo "theme-pool is empty" >&2; exit 1; }

echo "==> Installing themes from pool:"
printf '    - %s\n' "${THEMES[@]}"

for theme in "${THEMES[@]}"; do
  src="${THEMES_SRC}/${theme}"
  dst="/usr/share/plymouth/themes/${theme}"
  [[ -f "${src}/${theme}.plymouth" ]] || { echo "Missing ${src}/${theme}.plymouth" >&2; exit 1; }
  run rm -rf "$dst"
  run mkdir -p "$dst"
  # /usr is a normal fs; still avoid -a quirks
  run cp -r --no-preserve=ownership "$src/." "$dst/"
done

echo "==> Installing theme-pool + random-boot initcpio overrides"
run install -Dm644 "$POOL_SRC" /etc/plymouth/theme-pool
run install -Dm644 "${INITCPIO_SRC}/install/plymouth" /etc/initcpio/install/plymouth
run install -Dm755 "${INITCPIO_SRC}/hooks/plymouth" /etc/initcpio/hooks/plymouth

# Seed a valid default (random now); runtime hook re-picks every boot in initramfs
PICK="${THEMES[RANDOM % ${#THEMES[@]}]}"
echo "==> Seeding default theme: ${PICK}"
run plymouth-set-default-theme "$PICK"

echo "==> Ensure plymouth after encrypt in mkinitcpio"
run cp "${MKINIT}" "${MKINIT}.bak.plymouth-adi-$(date +%Y%m%d%H%M)"
if grep -q '^HOOKS=' "${MKINIT}"; then
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
echo "Done. Each boot randomly picks from:"
printf '  %s\n' "${THEMES[@]}"
echo
echo "Edit pool:  ${POOL_SRC}  then re-run this script."
echo "Preview:    sudo plymouthd --mode=boot --pid-file=/run/plymouth.pid; sudo plymouth --show-splash; sleep 8; sudo plymouth --quit"
echo "Back to tn-void:  sudo ${CFG}/install-tn-void.sh"
