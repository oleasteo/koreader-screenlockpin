# ScreenLockPin — Protect your KOReader with a PIN

[![MIT License](https://img.shields.io/badge/License-MIT-orange.svg)](https://opensource.org/licenses/MIT)
[![Release Version](https://img.shields.io/badge/Release-2025.10--2-blue.svg)](https://github.com/oleasteo/koreader-screenlockpin/releases/tag/v2025.10-2)
[![Compatibility](https://img.shields.io/badge/Comptibility-KOReader%20v2025.08-yellow.svg)](https://github.com/koreader/koreader/tree/v2025.08)

**ScreenLockPin**: A fast, sophisticated PIN Lock Screen that protects your
[KOReader](https://github.com/koreader/koreader) content from unauthorized
access.

![Lock Screen Preview](lockscreen.png)

---

## ✨ Features

Just what you'd expect from a PIN lock screen, and more… 😅

- 🗽 **Custom PIN length** — supports 4–8 digits
- ◻️ **Privacy first** — hides everything but your wallpaper from public eyes
- 🚀 **Lock on boot** — secures your device on KOReader boot (configurable)
- 🔒 **Lock on wakeup** — secures your device after sleep (configurable)
- ⚡ **Instant unlock** — immediate response, no extra confirmation button
- 🚥 **Rate Limiting** — short delays after repeated failed attempts
- 🪶 **Lightweight design** — optimized for performance

Please leave a ⭐ if you like the plugin.

---

## 💡 Not a Feature

- This plugin is designed for **privacy and casual protection**, not
  cryptographic security.

---

## 📦 Installation
``
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

---

## 🧩 Compatibility

Designed for **KOReader v2025.08** and newer. Please report any compatibility
issues you encounter.

Tested devices:
- ✅ Kindle Oasis (10th generation)

If you tested this plugin on another device type, please add it to the list
above.

---

## ❔ FAQ

### I have lost my PIN. How do I unlock?

If you don't have *lock on boot* enabled, a hard reboot should suffice to get
you into the KOReader. Change your PIN from there.

If you do have *lock on boot* enabled, you'll need access to the devices file
system (e.g., USB or SSH). Inside the *koreader* directory, edit the
*settings.reader.lua* file. Find the `screenlockpin_pin` option and change, if
necessary. Make sure the value adheres the 4–8 digits constraint. Save, and
reboot into KOReader.

### How do I change the lock screen background?

The lock screen is based on your configured wallpaper: *Screen* › *Sleep screen*
› *Wallpaper*.

### I enabled the lock before changing the PIN. How do I unlock?

The default PIN is `0000`

### I disabled the *lock on wakeup*, now the device stays on the wallpaper.

On disable, we restore the *Screen* › *Sleep screen* › *Wallpaper* › **Postpone
screen update after wake-up** setting that was set before the feature was
enabled. You might need to tap the screen, or use your old 'exit sleep screen'
gesture to unlock.

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
