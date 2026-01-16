# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Support KOReader on Android devices.

## [2026.01] - 2026-01-02

A couple of stability and a bunch of user experience improvements. Notably, a
new "Lock" menu item for those who prefer to lock by hand. Also, the desktop
support has improved a lot: global lock shortcuts `Ctrl+Alt+L` and
`Alt+Shift+L`, as well as proper keyboard PIN input on the lock screen.

Have a great 2026, folks 🎇💫

### Changed

- The menu entry is moved close to the "Sleep screen" entry for better grouping.

### Added

- [#35](https://github.com/oleasteo/koreader-screenlockpin/issues/35)
  Add "Lock" action to exit menu.
- On long tap outside the panel, set frontlight to min/max possible value.
- [#34](https://github.com/oleasteo/koreader-screenlockpin/issues/34)
  Handle keyboard PIN input.
- [#40](https://github.com/oleasteo/koreader-screenlockpin/issues/40)
  Global keyboard shortcuts to trigger the lock action: `Ctrl+Alt+L` and
  `Alt+Shift+L`.

### Fixed

- [#43](https://github.com/oleasteo/koreader-screenlockpin/issues/43)
  Properly close update manager background widget for KOReader exit and restart.
- [#41](https://github.com/oleasteo/koreader-screenlockpin/issues/41)
  Make sure to show the PIN panel on wakeup in case of lock on wakeup being
  disabled, but lock screen active elsewise (e.g., dispatcher / lock on boot).
- Screen resize handling while lock screen is active.
- [#31](https://github.com/oleasteo/koreader-screenlockpin/issues/31)
  Initial bottom config tab change now properly hides prior tab for smaller next
  tab.
- Horizontal re-layout on status text changes to keep the align right.

## [2025.12-1] - 2025-12-22

This small update adds some status information (time, battery, frontlight) to
the bottom of the panel. It also includes a render fix after device deep sleep.

Merry Christmas 🎄 and a happy new year! 🚀

### Added

- [#8](https://github.com/oleasteo/koreader-screenlockpin/issues/8)
  Device status text with time, battery, and frontlight. 

### Fixed

- [#38](https://github.com/oleasteo/koreader-screenlockpin/issues/38)
  Flash initial lock screen panel draw to avoid a transparent background by
  accident (only black is drawn, not white). 

## [2025.12] - 2025-12-17

If everything works out, this should be the last update that you have to do by
hand. From now on, the built-in updater will check "in the background" according
to configured intervals (by default up to once a week) if any new updates are
available. They'll patch themselves as well (with lots of safety guards) 🤞

In addition, this update includes improvements (esp. for desktop users) and
fixes.

Merry Christmas 🎄

### Changed

- [#33](https://github.com/oleasteo/koreader-screenlockpin/issues/33)
  Tweaked refresh on unlock. If we're going to unlock to the reader UI, we use
  a heavier refresh to avoid bad ghosting. Outside the reader UI, we accept some
  ghosting for the performance benefit of a lighter refresh (still, flashing)
  instead.
- [#37](https://github.com/oleasteo/koreader-screenlockpin/issues/37)
  Don't purge plugin settings on plugin disable. This is more in line with other
  plugins.

### Added

- [#15](https://github.com/oleasteo/koreader-screenlockpin/issues/15)
  Check for updates menu item with automatic plugin update procedure.
- [#28](https://github.com/oleasteo/koreader-screenlockpin/issues/28)
  "Background job" to check for updates automatically (configurable intervals).
  Actually, there is no background job but distinct triggers (e.g., device
  unlock, WiFi connection established) that cause us to check for updates, if
  the interval is elapsed.

### Fixes

- [#32](https://github.com/oleasteo/koreader-screenlockpin/issues/32)
  Hide screenshot related options on desktop devices.
- [#30](https://github.com/oleasteo/koreader-screenlockpin/issues/30)
  Fill backdrop on desktop devices.
- [#29](https://github.com/oleasteo/koreader-screenlockpin/issues/29)
  Hide lock on wakeup on devices that cannot suspend.
- [#36](https://github.com/oleasteo/koreader-screenlockpin/issues/36)
  Notes icon doesn't distort anymore.
- Properly expose `PluginShare.screen_lock_pin`.

## [2025.11-1] - 2025-11-16

The major addition in this release is the (basic) frontlight control. Just tap
anywhere but the lock screen to increase (top half) or decrease (bottom half)
the screen brightness. An essential enhancement if you find yourself trying to
unlock the device in the night after you've locked during in the day 😅

In addition, I completed a couple of minor issues and introduced a new public
API. May it spawn some interesting extension plugins…

Enjoy! 🚀

### Changed

- [#19](https://github.com/oleasteo/koreader-screenlockpin/issues/19)
  Screenshots are blocked on the lock screen (configurable).

### Added

- [#11](https://github.com/oleasteo/koreader-screenlockpin/issues/11)
  Taps on the off-panel area increase (top) or decrease (bottom) the frontlight
  brightness. Contributor: [HadyBazzi](https://github.com/HadyBazzi)
- [#12](https://github.com/oleasteo/koreader-screenlockpin/issues/12)
  A notification is shown after unlock, if PIN attempts failed too many times
  (throttled at least twice) since locked.
- Menu toggle to disable the lock screen. Whilst not directly useful via UI,
  this option can be useful as a main switch via dispatcher actions (see below).
- Provide dispatcher actions to unlock or en/disable the lock screen.
- Provide well-defined public API for 3rd party plugins (see
  [plugin/publicapi.lua](screenlockpin.koplugin/plugin/publicapi.lua) for
  details).

## [2025.11] - 2025-11-04

The lock screen becomes even more customizable. With the new panel position
controls, it can be put to the side for single-handed unlocking. I, myself, put
it on the right edge close to the bottom with a small size.
Feels way easier now ✨

Also, as I'm going to travel soon, I just had to add customizable notes to the
lock screen. A tiny insurance for when the device might get lost 🤞

Have fun!

### Changed

- The lock screen panel size factor is slightly changed, to allow for even
  smaller panels.

### Added

- [#5](https://github.com/oleasteo/koreader-screenlockpin/issues/5)
  The lock screen panel position is configurable.
- [#14](https://github.com/oleasteo/koreader-screenlockpin/issues/14)
  Notes can be written to provide on the lock screen without PIN. E.g.,
  emergency or contact information.

## [2025.10-3] - 2025-10-29

The UI has received a lot of work since the last release. Instead of the plain
white screen, you'll now see a panel on top of your configured wallpaper. Its
size can be configured, more configurations are to follow in the upcoming weeks.

Also, we now allow for 3–12 digit PINs. Choose yourself how serious you want to
take this whole lock screen thing 😅

Stay tuned! 🚀 And enjoy Halloween 👻

### Security

- Use a `full` display refresh on unlock to prevent bleeding information on
  pressed buttons.
- Redact change pin values from logs, just in case they're somehow readable w/o
  device access. Probably not a real security issue, but let's err on the safe
  side.

### Changed

- PIN change uses `Notification` instead of `InfoMessage`. The notification is
  less obtrusive, at the top of the screen.
- Allow 3–12 digits for PINs.

### Added

- [#3](https://github.com/oleasteo/koreader-screenlockpin/issues/3)
  The lock screen draws on top of the builtin wallpaper. The white background is
  gone.
- [#5](https://github.com/oleasteo/koreader-screenlockpin/issues/5)
  The lock screen panel size can be configured.

## [2025.10-2] - 2025-10-24

Yet another release with a big new feature, shortly after the last one 😅

Adding a rate limiter is the last security feature on my todo list. I'm happy to
find it's working just fine, despite the dynamic PIN length allowed. I've hidden
an option to turn it off in the settings, not available via UI; just in case
someone knows what they're doing.

### Changed

- Improved the menu item texts to feel consistent with KOReader menus.

### Added

- [#6](https://github.com/oleasteo/koreader-screenlockpin/issues/6)
  Rate Limit for PIN input. Lock for 10/30/60/60/... seconds after the 4th
  failed attempt of any PIN length. All counters are reset after 5 minutes since
  the last rate limit was triggered.
  If you want/need to disable this feature, change the `screenlockpin_ratelimit`
  setting in your *settings.reader.lua* (*koreader* directory) by hand. It's not
  provided as an option in the UI.

### Fixed

- Reset PIN input state on re-awake after sleep.
- [#7](https://github.com/oleasteo/koreader-screenlockpin/issues/7) Lock Screen
  rotation for unlocked device orientation.

## [2025.10-1] - 2025-10-22

With the new lock-on-boot feature, it achieves something that—to my knowledge—no
other PIN lock screen plugin does.
The new menu position, options, and fixed double-tap sluggishness vastly polish
this plugin up.

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
