# ScreenLockPin — Protect your KOReader with a PIN

A fast, sophisticated PIN Lock Screen that protects your
[KOReader](https://github.com/koreader/koreader) content from unauthorized
access.

[![Lock Screen Showcase](https://media.githubusercontent.com/media/oleasteo/koreader-screenlockpin/main/assets/showcase.webp)](https://media.githubusercontent.com/media/oleasteo/koreader-screenlockpin/main/assets/showcase.1024p.webp)

---

## ✨ Features

Just what you'd expect from a PIN lock screen…

- 🔒 **Lock on wakeup** — secures your device after sleep
- 🪝 **Lock on boot** — secures your device on KOReader boot
- 🛡️ **Privacy first** — hides everything but your wallpaper from public eyes
- 🔋 **Device Info** — glimpse the time & battery on the lock screen
- 🚷 **Rate Limit** — forced delays after repeatedly failed attempts

and more…

- 🪄 **Instant unlock** — immediate response, no extra confirmation button
- 🪧 **Contact notes** — people should know how to return a lost device
- 🎯 **Customizable layout** — can be configured for single-handed use
- 🔆 **Frontlight control** — easily turn on the screen light in a dark environment
- 🪃 **Lightweight design** — optimized for performance
- 🗽 **PIN length** — 3 to 12 digits

This plugin is designed for **privacy and casual protection**, not cryptographic
security.

Please leave a ⭐ if you like the plugin.

---

## 📦 Installation

1. Download the
   [latest release](https://github.com/oleasteo/koreader-screenlockpin/releases/latest);
   either archive is fine — whatever you're familiar with.
2. Extract the archive and copy the extracted folder `screenlockpin.koplugin`
   into KOReader’s `plugins` directory.
3. Restart KOReader. The plugin will appear in the *Screen* submenu.

---

## ⚙️ Usage

1. On your KOReader, open the new *Screen* › **Lock screen** submenu.
2. Set your PIN and configure the options to your liking.

Depending on your settings, the Lock Screen will now appear during boot and /
or during wakeup from sleep mode.

If you enable *lock on boot*, make sure to have some way of file access without
unlocking the KOReader, in case you forget the PIN (see FAQ below).

Actions for the dispatcher (e.g., Gesture manager) can be found in the *Device*
group.

---

## 🛠️ Public API

We do expose an interface to use in foreign plugins. For example, a plugin could
use this API to disable the lock screen based on external factors like date or
time.

The interface can be accessed like this:

```lua
local PluginShare = require("pluginshare")

function yourFunction()
   local lockScreen = PluginShare.screen_lock_pin
   if not lockScreen then return end
   -- safely use lockScreen here
   -- e.g., lockScreen:lock()
end
```

See [publicapi.lua](screenlockpin.koplugin/plugin/publicapi.lua) for available
methods. Please create an issue or PR if we're missing something that would be
of use to you.

If you've built a plugin that integrates with the lock screen, kindly open a PR
to list it here for others to find.

<!--

- ➡️ [MyPlugin](https://…) – Brief description.

-->

---

## 🧩 Compatibility

Designed for **KOReader v2025.08** and newer. We received reports of working
properly on numerous devices (Kindle, Kobo, Desktop, Android, PocketBook) and
try to support all which KOReader works on.

Please report any compatibility issues you encounter.

Note that we cannot force KOReader to stay in the foreground (e.g., Android and
PocketBook), nor can we block other system actions like forced reboot (long
press power button). We recommend to enable an OEM firmware lock screen as
well, to prevent any device access outside KOReader.

---

## ❔ FAQ

### I have lost my PIN. How do I unlock?

If you don't have *lock on boot* enabled, a hard reboot should suffice to get
you into the KOReader. Change your PIN from there.

If you do have *lock on boot* enabled, you'll need access to the devices file
system (e.g., USB or SSH). Inside the *koreader* directory, edit the
*settings.reader.lua* file. Find the `screenlockpin_pin` option and change, if
necessary. Make sure the value adheres the 3–12 digits constraint. Save, and
reboot into KOReader.

### How do I change the lock screen background?

The lock screen is based on your configured wallpaper: *Screen* › *Sleep screen*
› *Wallpaper*.

### I disabled the *lock on wakeup*, now the device stays on the wallpaper.

On disable, we restore the *Screen* › *Sleep screen* › *Wallpaper* › **Postpone
screen update after wake-up** setting that was set before the feature was
enabled. You might need to tap the screen, or use your old 'exit sleep screen'
gesture to unlock.

### Any way to prevent home button on my PocketBook?

Unfortunately, no. This plugin cannot prevent hiding the KOReader app on press
of the home button. For a device lock outside the KOReader, you'll have to rely
on the OEM PIN lock.

---

## 🧑‍💻 Contributing

Contributions and suggestions are welcome!
Feel free to open an **issue** or **pull request** to improve functionality,
style, or compatibility.

---

## 📜 License

MIT License —
see [LICENSE](https://github.com/oleasteo/koreader-screenlockpin/blob/main/LICENSE)
for details.
