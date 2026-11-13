# suman-algrgb

Native Linux ACPI lighting driver, CLI, and Omarchy shell plugin for the **Acer Aspire Lite AL15G-52** (and compatible Acer laptops with the `CLV0001` ACPI interface).

---

## Supported Hardware

| Model | Compatibility | ACPI Device | Interface |
|---|:---:|---|---|
| **Acer Aspire Lite AL15G-52** | Native | `CLV0001:00` | `\_SB.DCHU` (`_DSM 0x67`) |
| **Acer Aspire Lite (CLV0001 Series)** | Compatible | `CLV0001:00` | `\_SB.DCHU` (`_DSM 0x67`) |

Verify your hardware:
```bash
cat /sys/class/dmi/id/product_name    # Expected: Aspire Lite AL15G-52
ls -d /sys/bus/acpi/devices/CLV0001:00
```

---

## Architecture

```
┌───────────────────────────────────────────────────────────┐
│                      USER INTERFACES                      │
│    Unix CLI (alg-rgb)    ·    Omarchy Shell Plugin        │
└─────────────────────────┬─────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────┐
│                    LINUX KERNEL DRIVER                    │
│    /dev/alg_rgb   ·   DKMS alg_rgb.ko   ·  GRB Conversion │
└─────────────────────────┬─────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────┐
│                    ACPI FIRMWARE LAYER                    │
│    CLV0001:00     ·    _DSM 0x67        ·  UUID 93f224e4  │
└─────────────────────────┬─────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────┐
│                  EMBEDDED CONTROLLER                      │
│    [0xF0] Main typing zone   ·   [0xF3] Light Bar         │
└───────────────────────────────────────────────────────────┘
```

---

## Installation

### Prerequisites

```bash
# Arch Linux
sudo pacman -S linux-headers dkms base-devel

# Fedora / RHEL
sudo dnf install kernel-devel-$(uname -r) dkms gcc make

# Ubuntu / Debian
sudo apt install linux-headers-$(uname -r) dkms build-essential
```

### Quick Install

```bash
git clone git@github.com:sumanezhumalai/omarhcy-algrgb.git
cd omarhcy-algrgb
sudo bash ./install.sh
```

The installer:
1. Builds and installs `/usr/local/bin/alg-rgb`.
2. Registers and builds the `alg_rgb` DKMS kernel module.
3. Installs udev rules for unprivileged seat access (`/dev/alg_rgb`) with `uaccess`.
4. Configures systemd state restore and sleep/resume hooks.
5. Automatically installs the Omarchy shell plugin (`suman.alg-rgb`) and theme-set hook if Omarchy is present.

### User Permissions

```bash
sudo usermod -aG alg-rgb "$USER"
newgrp alg-rgb
```

---

## Omarchy Shell Plugin

A native status bar widget and control panel (`suman.alg-rgb`) integrates seamlessly into the Omarchy bar (`~/.config/omarchy/plugins/suman.alg-rgb`):

- **Bar Widget**:
  - Displays a pure white Font Awesome keyboard icon (`` / `\uf11c`) matching native Omarchy bar icons.
  - Automatically dims when the backlight is powered off or in standby.
  - **Left-Click**: Toggles the control panel popout.
  - **Right-Click**: Toggles keyboard backlight power instantly.
- **Control Panel**:
  - Live color preview swatch and power switch.
  - 4-level discrete brightness slider.
  - **Dynamic Theme Matching**: Automatically synchronizes keyboard backlight with the active Omarchy theme's accent color in real time. Features a native `󰏘` palette icon.
  - **Curated Warm Presets**: One-click static selection of eye-easy aesthetic tones:
    - **Flesh**: `#ff7f3f`
    - **Warm Orange**: `#ff7f00`
    - **Amber Sand**: `#e0af68`
    - **Buttercream**: `#ded885`
- **Instant Night Light Synchronization**:
  - Automatically monitors `hyprsunset` via Quickshell's in-memory `Commons.IpcRegistry`.
  - When night light activates, chromatic adaptation is calculated and dispatched within **~30ms** (reduced from legacy ~2100ms process polling), using **0.00% CPU**.

---

## CLI Usage

```bash
# Preset and hex colors
alg-rgb red
alg-rgb cyan 4
alg-rgb '#98d7c2' 2

# Brightness control (0 to 4)
alg-rgb brightness 3
alg-rgb off        # Backlight off
alg-rgb on         # Restore previous brightness

# Motion effects
alg-rgb effect wave     # Traveling wave
alg-rgb effect cycle    # Rainbow spectrum loop
alg-rgb effect breath   # Breathing fade
alg-rgb effect tempo    # Beat pulse
alg-rgb effect dance    # Alternate zone pattern
alg-rgb effect random   # Random per-zone pattern
alg-rgb effect static   # Solid static color

# Status & diagnostics
alg-rgb status
alg-rgb status --json
alg-rgb probe
```

---

## Architecture & Technical Deep Dive

### 1. Embedded Firmware Effects vs. Userspace Animation Daemon
The codebase supports two distinct effect mechanisms:
- **Hardware-Native Firmware Effects**:
  The keyboard's embedded controller natively implements 7 animation patterns (`random`, `flash`, `tempo`, `dance`, `wave`, `cycle`, `breath`). These are triggered by sending a single 4-byte ACPI packet through the kernel driver (`alg_push_effect_locked`). The hardware controller chip autonomously executes the animation with zero CPU usage.
- **Userspace Animation Daemon**:
  `cli/alg-rgb.c` contains an optional mathematical software animation engine (with sinusoidal HSV transforms and phase offsets). When invoked from the CLI, it can stream raw frames to `/dev/alg_rgb` (via the kernel's low-overhead `frame` command).
- **Idle State During Normal Operation**:
  During standard static color usage, theme switching, night light adaptation, and all Omarchy panel interactions, the software animation daemon remains completely **dormant / idle (0.00% CPU and 0 MB RAM overhead)**.

### 2. Night Light Chromatic Adaptation & Hyprctl Shim
To prevent visual clash between a warm night-light display and a cold keyboard backlight, the driver applies Bradford-based chromatic adaptation matching `hyprsunset`:

$$\Delta T = 6000 - T_{\text{sunset}}$$
$$G_{\text{scale}} = 1.0 - \left(0.2799 \times \frac{\Delta T}{2750}\right)$$
$$B_{\text{scale}} = 1.0 - \left(0.5172 \times \frac{\Delta T}{2750}\right)$$

* At **3250K**, green is scaled to ~72% and blue to ~48%, producing a color balance that perfectly matches the display.
* For custom color temperatures without modifying `/usr/share/omarchy/`, a lightweight transparent `hyprctl` shim in `~/.local/bin/hyprctl` maps standard requests (e.g., 4000K) to 3250K system-wide while maintaining instant loop termination for `omarchy-toggle-nightlight`.

---

## Hardware Safety & Protocol

### ACPI `_DSM` Function 0x67
- **UUID**: `93f224e4-fbdc-4bbf-add6-db71bdc0afad`
- **Function**: `0x67`
- **Payload**: 4-byte buffer `[Green, Red, Blue, Zone/Command]` (GRB byte order converted automatically by the driver).

> [!CAUTION]
> Functions `0x68`, `0x69`, `0x6A` are strictly quarantined — these cause embedded controller lockups on related hardware during reverse engineering. `alg-rgb probe` is strictly read-only.

---

## Troubleshooting

### `/dev/alg_rgb` Missing
```bash
sudo dkms status
sudo modprobe alg_rgb
dmesg | grep alg_rgb
```

### Permission Denied
```bash
sudo usermod -aG alg-rgb "$USER"
newgrp alg-rgb
```

---

## License & Credits

- **License**: GNU General Public License v2.0 ([GPL-2.0](LICENSE))
- **Author / Maintainer**: Suman Ezhumalai
- **Based on research by**: Kaushik ([`24kaushik/alg-cli`](https://github.com/24kaushik/alg-cli)) and Chirag Koyande for initial ACPI CLV0001 discovery.
