# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

[//]: # (## [Unreleased])

### Added

- Rate Limit for PIN input. Lock for 10/30/60/60/... seconds after the 4th
  failed attempt of any PIN length. All counters are reset after 5 minutes since
  the last rate limit was triggered. #6
  If you want/need to disable this feature, change the `screenlockpin_ratelimit`
  setting in your *settings.reader.lua* (*koreader* directory) by hand. It's not
  provided as an option in the UI.

### Fixed

- Reset PIN input state on re-awake after sleep.
- [#7](https://github.com/oleasteo/koreader-screenlockpin/issues/7) Lock Screen
  rotation for unlocked device orientation.

## [2025.10-1] - 2025-10-22

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
