#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Install the Acer ALG RGB keyboard stack:
#   - DKMS kernel module  (alg_rgb.ko → /dev/alg_rgb)
#   - alg-rgb CLI         (/usr/local/bin/alg-rgb)
#   - udev / modules-load / systemd integration
#
# Run from anywhere:
#   sudo bash /path/to/luma-alg_rgb/install.sh
#
# The installer is idempotent and safe to re-run.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(sed -n 's/^#define ALG_RGB_VERSION_STRING "\([^"]*\)"/\1/p' "$ROOT/include/version.h" | head -n1)"
DKMS_NAME="alg-rgb"
KREL="$(uname -r)"
SRC_DIR="/usr/src/${DKMS_NAME}-${VERSION}"

log()  { printf '[alg-rgb] %s\n' "$*"; }
warn() { printf '[alg-rgb] WARNING: %s\n' "$*" >&2; }
die()  { printf '[alg-rgb] ERROR: %s\n' "$*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || die "run this installer with sudo: sudo bash $ROOT/install.sh"
[ -n "$VERSION" ] || die "could not read the version from include/version.h"
[ -f "$ROOT/kernel/alg_rgb.c" ] || die "kernel source not found under $ROOT"

TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=""
fi
TARGET_HOME=""
if [ -n "$TARGET_USER" ]; then
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
fi

log "Installing ALG RGB ${VERSION} for kernel ${KREL}"

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

if [ ! -e "/lib/modules/${KREL}/build" ]; then
    if command -v dnf >/dev/null 2>&1; then
        log "Installing kernel headers for ${KREL}"
        dnf install -y "kernel-devel-${KREL}" || die "could not install kernel-devel-${KREL}"
    elif command -v pacman >/dev/null 2>&1; then
        die "kernel headers for ${KREL} are missing; run: sudo pacman -S linux-headers"
    else
        die "kernel headers for ${KREL} are missing (install kernel-devel or linux-headers)"
    fi
fi

if ! command -v dkms >/dev/null 2>&1; then
    if command -v dnf >/dev/null 2>&1; then
        log "Installing DKMS"
        dnf install -y dkms || die "could not install dkms"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -S --noconfirm dkms || die "could not install dkms"
    else
        die "dkms is required but is not installed"
    fi
fi

command -v make >/dev/null 2>&1 || die "make is required"
command -v gcc  >/dev/null 2>&1 || die "gcc is required"

# ---------------------------------------------------------------------------
# Build and install the CLI
# ---------------------------------------------------------------------------

log "Building the CLI"
make -C "$ROOT/cli" clean all
install -Dm755 "$ROOT/cli/alg-rgb" /usr/local/bin/alg-rgb

# ---------------------------------------------------------------------------
# Install and build the DKMS module
# ---------------------------------------------------------------------------

log "Installing DKMS source to ${SRC_DIR}"
if [ -d /sys/module/alg_rgb ]; then
    log "Unloading the running alg_rgb module"
    if ! modprobe -r alg_rgb; then
        die "could not unload alg_rgb; close any program using /dev/alg_rgb and re-run"
    fi
fi
dkms remove -m "$DKMS_NAME" -v "$VERSION" --all >/dev/null 2>&1 || true
make -C "$ROOT/kernel" clean >/dev/null 2>&1 || true
rm -rf "$SRC_DIR"
install -d "$SRC_DIR"
cp -a "$ROOT/kernel" "$ROOT/include" "$ROOT/dkms.conf" "$ROOT/LICENSE" "$ROOT/README.md" "$SRC_DIR/"
[ -d "$ROOT/docs" ] && cp -a "$ROOT/docs" "$SRC_DIR/"

log "Registering and building the DKMS module"
dkms add    -m "$DKMS_NAME" -v "$VERSION"
dkms build  -m "$DKMS_NAME" -v "$VERSION"
dkms install --force -m "$DKMS_NAME" -v "$VERSION"

# ---------------------------------------------------------------------------
# Users, permissions and persistence directories
# ---------------------------------------------------------------------------

log "Creating the alg-rgb group and state directory"
groupadd -f alg-rgb
if [ -n "$TARGET_USER" ]; then
    usermod -aG alg-rgb "$TARGET_USER"
    log "Added ${TARGET_USER} to the alg-rgb group"
fi
install -d -m 2775 -g alg-rgb /var/lib/alg-rgb
chgrp alg-rgb /var/lib/alg-rgb
chmod 2775   /var/lib/alg-rgb
if [ -f /var/lib/alg-rgb/state ]; then
    chgrp alg-rgb /var/lib/alg-rgb/state
    chmod 0664    /var/lib/alg-rgb/state
fi

# ---------------------------------------------------------------------------
# udev, module autoload and systemd units
# ---------------------------------------------------------------------------

log "Installing udev, module autoload and systemd integration"
rm -f /etc/udev/rules.d/99-alg-rgb.rules
install -Dm644 "$ROOT/udev/70-alg-rgb.rules"          /etc/udev/rules.d/70-alg-rgb.rules
install -Dm644 "$ROOT/modules-load/alg_rgb.conf"       /etc/modules-load.d/alg_rgb.conf
install -Dm644 "$ROOT/systemd/alg-rgb-restore.service" /etc/systemd/system/alg-rgb-restore.service
install -Dm755 "$ROOT/systemd/alg-rgb-sleep"           /usr/lib/systemd/system-sleep/alg-rgb

systemctl daemon-reload
systemctl enable alg-rgb-restore.service >/dev/null 2>&1 || warn "could not enable alg-rgb-restore.service"

udevadm control --reload-rules
udevadm trigger --subsystem-match=misc --action=add >/dev/null 2>&1 || true

log "Loading the kernel module"
if modprobe alg_rgb; then
    log "alg_rgb loaded"
else
    warn "modprobe alg_rgb failed; run 'sudo dmesg | tail -40' after checking Secure Boot and DKMS status"
fi

for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -e /dev/alg_rgb ] && break
    sleep 0.3
done
if [ -e /dev/alg_rgb ]; then
    chgrp alg-rgb /dev/alg_rgb 2>/dev/null || true
    chmod 0660    /dev/alg_rgb 2>/dev/null || true
    log "Device ready: /dev/alg_rgb"
else
    warn "/dev/alg_rgb was not created; check 'sudo dmesg | tail -40'"
fi

# Apply saved state if the device is live.
if [ -e /dev/alg_rgb ]; then
    systemctl start alg-rgb-restore.service >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

cat <<EOF

================================================================================
ALG RGB ${VERSION} installed
================================================================================

CLI:    /usr/local/bin/alg-rgb
Device: /dev/alg_rgb $( [ -e /dev/alg_rgb ] && echo '(present)' || echo '(missing — check dmesg)' )
Module: $(dkms status -m "$DKMS_NAME" -v "$VERSION" 2>/dev/null | head -n1 || echo 'check dkms status')

Quick start:
  alg-rgb status
  alg-rgb red 3
  alg-rgb effect wave
  alg-rgb off
  alg-rgb probe

EOF

if [ -n "$TARGET_USER" ]; then
    if id -nG "$TARGET_USER" | grep -qw alg-rgb; then
        cat <<EOF
${TARGET_USER} is a member of the alg-rgb group. The current graphical session
already has a logind seat ACL for /dev/alg_rgb. For permanent group access in
new terminals, log out and back in (or run: newgrp alg-rgb).

EOF
    fi
fi

cat <<EOF
Per-key RGB is not enabled: HID 048D:8910 is not enumerated. This stack
controls the verified CLV0001 zone-RGB path only.

If the keyboard does not respond:
  sudo dmesg | tail -40
  sudo dkms status
  alg-rgb probe
================================================================================
EOF
