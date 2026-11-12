#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Remove the Acer ALG RGB keyboard stack installed by install.sh.
#
# Run with:
#   sudo bash /path/to/suman-algrgb/uninstall.sh
#
# User configuration (~/.config/alg-rgb) is intentionally left in place.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(sed -n 's/^#define ALG_RGB_VERSION_STRING "\([^"]*\)"/\1/p' "$ROOT/include/version.h" | head -n1)"
DKMS_NAME="alg-rgb"
SRC_DIR="/usr/src/${DKMS_NAME}-${VERSION}"

log()  { printf '[alg-rgb] %s\n' "$*"; }
warn() { printf '[alg-rgb] WARNING: %s\n' "$*" >&2; }
die()  { printf '[alg-rgb] ERROR: %s\n' "$*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || die "run this uninstaller with sudo: sudo bash $ROOT/uninstall.sh"
[ -n "$VERSION" ] || die "could not read the version from include/version.h"

TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=""
fi
TARGET_HOME=""
if [ -n "$TARGET_USER" ]; then
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
fi

log "Removing ALG RGB ${VERSION}"

# ---------------------------------------------------------------------------
# Stop system services
# ---------------------------------------------------------------------------

log "Stopping system services"
systemctl disable --now alg-rgb-restore.service >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Unload and remove kernel module
# ---------------------------------------------------------------------------

log "Removing kernel module"
modprobe -r alg_rgb >/dev/null 2>&1 || true

log "Removing DKMS module"
dkms remove -m "$DKMS_NAME" -v "$VERSION" --all >/dev/null 2>&1 || true
rm -rf "$SRC_DIR"

# ---------------------------------------------------------------------------
# Remove installed files
# ---------------------------------------------------------------------------

log "Removing installed files"
rm -f /etc/udev/rules.d/70-alg-rgb.rules
rm -f /etc/udev/rules.d/99-alg-rgb.rules
rm -f /etc/modules-load.d/alg_rgb.conf
rm -f /etc/systemd/system/alg-rgb-restore.service
rm -f /usr/lib/systemd/system-sleep/alg-rgb
rm -f /usr/local/bin/alg-rgb
rm -rf /var/lib/alg-rgb

if [ -n "$TARGET_HOME" ]; then
    if [ -d "$TARGET_HOME/.config/omarchy/plugins/suman.alg-rgb" ]; then
        log "Removing Omarchy shell plugin"
        rm -rf "$TARGET_HOME/.config/omarchy/plugins/suman.alg-rgb"
    fi
    if [ -f "$TARGET_HOME/.config/omarchy/hooks/theme-set.d/alg-rgb" ]; then
        log "Removing Omarchy theme-set hook"
        rm -f "$TARGET_HOME/.config/omarchy/hooks/theme-set.d/alg-rgb"
    fi
fi

systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger --subsystem-match=misc --action=remove >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Group membership
# ---------------------------------------------------------------------------

if [ -n "$TARGET_USER" ] && getent group alg-rgb >/dev/null 2>&1; then
    gpasswd -d "$TARGET_USER" alg-rgb >/dev/null 2>&1 || true
fi

if getent group alg-rgb >/dev/null 2>&1; then
    MEMBERS="$(getent group alg-rgb | cut -d: -f4)"
    if [ -z "$MEMBERS" ]; then
        groupdel alg-rgb >/dev/null 2>&1 || true
    fi
fi

cat <<EOF

================================================================================
ALG RGB ${VERSION} removed
================================================================================

User configuration was kept at ~/.config/alg-rgb.
A reboot or logout is recommended so the kernel module is fully unloaded.
If the keyboard is left in a custom state, the firmware retains it until the
next power cycle or another RGB command.
================================================================================
EOF
