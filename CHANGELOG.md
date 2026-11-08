# Changelog

## [1.1.0] — 2026-11-08

### Removed
- **GNOME Shell extension** — removed entirely (`extension/`).
- **Local web dashboard** — removed entirely (`web/`, Flask app, `alg-rgb-web.service`, `alg-rgb-web.sh`, `alg-rgb-dashboard.desktop`).

### Changed
- `install.sh` and `uninstall.sh` updated to only manage the kernel driver and CLI.
- `README.md` updated to reflect the stripped-down core stack.

### Notes
- UI is now provided by the **Omarchy Shell Plugin** (`suman.alg-rgb`), which integrates natively in the Omarchy bar.

---

## [1.0.0] — 2026-11-05

### Added
- Initial release: `alg_rgb` DKMS kernel module targeting ACPI `CLV0001:00`.
- `alg-rgb` CLI with zone control, brightness, motion effects, state persistence, and JSON output.
- Software animation daemon with phase-shifted multi-zone effects (wave, cycle, breath, tempo, dance, random, flash).
- udev seat ACL rules, systemd restore service, and sleep/resume hook.
- Local web dashboard (Flask) and GNOME Shell extension (45–50).
