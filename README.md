<div align="center">

# ✦ Luma ALG RGB

**Native Linux ACPI Lighting Driver & CLI for Acer Aspire Lite AL15G-52**

[![Hardware Model](https://img.shields.io/badge/Model-Acer%20Aspire%20Lite%20AL15G--52-0078D7?style=flat-square&logo=acer&logoColor=white)](https://github.com/chiragkoyande/luma-alg_rgb)
[![Linux Kernel](https://img.shields.io/badge/Driver-DKMS%20Kernel%20Module-orange?style=flat-square&logo=linux&logoColor=white)](https://github.com/chiragkoyande/luma-alg_rgb)
[![Interface](https://img.shields.io/badge/ACPI-CLV0001%20%2F%20_DSM%200x67-blueviolet?style=flat-square)](https://github.com/chiragkoyande/luma-alg_rgb)
[![License](https://img.shields.io/badge/License-GPL--2.0-blue?style=flat-square)](LICENSE)

</div>

---

## 💻 Supported Hardware

| Model | Compatibility | Interface |
|:---|:---:|:---|
| **Acer Aspire Lite AL15G-52** | **100% Native** | ACPI `CLV0001:00` (`\_SB.DCHU`) |
| **Acer Aspire Lite (CLV0001 Series)** | Compatible | ACPI `CLV0001:00` (`\_SB.DCHU`) |

Verify your hardware:
```bash
cat /sys/class/dmi/id/product_name    # Expected: Aspire Lite AL15G-52
ls -d /sys/bus/acpi/devices/CLV0001:00
```

---

## 🏛️ Architecture

```
┌───────────────────────────────────────────────────────────┐
│                      USER INTERFACES                      │
│    Unix CLI (alg-rgb)  |  Omarchy Shell Plugin            │
└─────────────────────────┬─────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────┐
│                    LINUX KERNEL DRIVER                    │
│    /dev/alg_rgb  |  DKMS alg_rgb.ko  |  GRB byte order   │
└─────────────────────────┬─────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────┐
│                    ACPI FIRMWARE LAYER                    │
│    CLV0001:00  |  _DSM 0x67  |  UUID 93f224e4            │
└─────────────────────────┬─────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────┐
│                  EMBEDDED CONTROLLER                      │
│  [0xF0] Main  |  [0xF1] Mid  |  [0xF2] Right             │
│  [0xF3] Light Bar  |  [0xF6] Logo                        │
└───────────────────────────────────────────────────────────┘
```

---

## 🚀 Installation

### Prerequisites

```bash
# Fedora / RHEL
sudo dnf install kernel-devel-$(uname -r) dkms gcc make

# Ubuntu / Debian
sudo apt install linux-headers-$(uname -r) dkms build-essential

# Arch Linux
sudo pacman -S linux-headers dkms base-devel
```

### Quick Install

```bash
git clone https://github.com/chiragkoyande/luma-alg_rgb.git
cd luma-alg_rgb
sudo bash ./install.sh
```

The installer:
1. Builds and installs `/usr/local/bin/alg-rgb`.
2. Registers and builds the `alg_rgb` DKMS kernel module.
3. Installs `/etc/udev/rules.d/70-alg-rgb.rules` (uaccess ACL for the seat user).
4. Configures systemd restore and sleep/resume hooks.

### Add User Permissions

```bash
sudo usermod -aG alg-rgb "$USER"
newgrp alg-rgb
```

---

## ⌨️ CLI Usage

```bash
# Named or hex colors
alg-rgb red
alg-rgb cyan 4
alg-rgb '#a855f7' 3

# Specific zones
alg-rgb color blue 4 --zone main
alg-rgb color magenta 4 --zone bar
alg-rgb color '#22d3ee' 4 --zone logo

# Brightness (0 to 4)
alg-rgb brightness 3
alg-rgb off        # Turn off backlight (brightness 0)
alg-rgb on         # Restore previous brightness

# Motion effects
alg-rgb effect wave     # Left-to-right traveling wave
alg-rgb effect cycle    # Smooth rainbow spectrum loop
alg-rgb effect breath   # Soft breathing fade
alg-rgb effect tempo    # Synchronized beat pulse
alg-rgb effect dance    # Alternate zone pattern
alg-rgb effect random   # Per-zone random shuffling
alg-rgb effect flash    # High-contrast strobe
alg-rgb effect static   # Stop motion, solid color

# Diagnostics
alg-rgb status
alg-rgb status --json
alg-rgb probe
alg-rgb list
```

### Hardware Zones

| Zone | Opcode | Description |
|:---|:---:|:---|
| `main` / `left` | `0xF0` | Primary typing keys |
| `mid` | `0xF1` | Center keypad area |
| `right` | `0xF2` | Number pad & navigation |
| `bar` | `0xF3` | Front ambient light bar |
| `logo` | `0xF6` | Lid logo LED |
| `all` | Multiple | All zones simultaneously |

---

## 🔬 Protocol & Hardware Safety

### ACPI `_DSM` Function 0x67
- **UUID**: `93f224e4-fbdc-4bbf-add6-db71bdc0afad`
- **Function**: `0x67`
- **Payload**: 4-byte buffer `[Green, Red, Blue, Zone/Command]`

> [!NOTE]
> The firmware requires **GRB** byte ordering. The kernel driver converts standard RGB automatically.

### Hardware Safety
- Functions `0x68`, `0x69`, `0x6A` are strictly quarantined — these caused an irreversible embedded controller lockup on AL15G-53 during reverse engineering.
- `alg-rgb probe` is strictly read-only: it never writes speculative ACPI calls.

---

## 🛠️ Troubleshooting

### `/dev/alg_rgb` does not exist
```bash
sudo dkms status
sudo modprobe alg_rgb
dmesg | grep alg_rgb
```

### Permission Denied on `/dev/alg_rgb`
```bash
sudo usermod -aG alg-rgb "$USER"
newgrp alg-rgb
```

---

## 📄 License & Credits

- **License**: GNU General Public License v2.0 ([GPL-2.0](LICENSE))
- **Author**: Chirag Koyande ([@chiragkoyande](https://github.com/chiragkoyande))
- **Based on research by**: Kaushik ([`24kaushik/alg-cli`](https://github.com/24kaushik/alg-cli)) for initial ACPI CLV0001 discovery.
- **Hardware Disclaimer**: Acer, Aspire, and Acer Control Center are trademarks of Acer Inc. This is an independent open-source reverse-engineered project for Linux interoperability.
