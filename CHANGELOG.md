# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- Moved the menu item into `Screen` submenu, with submenu for further options.

### Added

- Toggle-Options to lock on boot and / or wakeup; both are disabled by default.
  Lock on Wakeup will be enabled when migrating from an earlier plugin version.
- Restore the previously set lockscreen delay option when disabling lock on
  wakeup or the plugin altogether.
- Cleanup procedure when disabling the plugin (only once per session).

### Fixed

- Disabled double tap on our widget and dialog. This solves the perceived
  *sluggish* input when locking from an open book if double tap is enabled on
  the device.

### Removed

- The Change PIN dialog is no longer movable; it should perform better, though.

## [v2025.10] - 2025-10-15

### Added

- Initial Release
